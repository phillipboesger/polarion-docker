#!/bin/bash

echo "Preparing Apache before Polarion start..."
service apache2 restart || true

get_http_code() {
	local host="$1"
	wget -S --spider -T 5 -t 1 "http://${host}/repo" 2>&1 | awk '/HTTP\// {code=$2} END {print code}'
}

is_repo_reachable() {
	local host="$1"
	local code

	code="$(get_http_code "$host")"
	[ "$code" = "200" ] || [ "$code" = "401" ] || [ "$code" = "403" ] || [ "$code" = "405" ]
}

choose_repo_host() {
	local container_ip
	container_ip="$(hostname -i | awk '{print $1}')"

	for host in localhost 127.0.0.1 "$container_ip"; do
		if [ -n "$host" ] && is_repo_reachable "$host"; then
			echo "$host"
			return 0
		fi
	done

	return 1
}

echo "Checking Subversion endpoint readiness..."
SVN_READY=false
REPO_HOST=""
for i in $(seq 1 60); do
	if [ $((i % 10)) -eq 0 ]; then
		service apache2 restart || true
	fi

	if REPO_HOST="$(choose_repo_host 2>/dev/null)"; then
		echo "SVN endpoint is reachable via ${REPO_HOST}"
		SVN_READY=true
		break
	fi
	sleep 1
done

if [ "$SVN_READY" = "true" ] && [ -n "$REPO_HOST" ]; then
	echo "Applying repository host ${REPO_HOST} to polarion.properties"
	sed -i "s|^base.url=.*|base.url=http://${REPO_HOST}|" /opt/polarion/etc/polarion.properties
	sed -i "s|^repo=.*|repo=http://${REPO_HOST}/repo|" /opt/polarion/etc/polarion.properties
	sed -i "s|^controlHostname=.*|controlHostname=${REPO_HOST}|" /opt/polarion/etc/polarion.properties
else
	echo "ERROR: SVN endpoint /repo did not become reachable before Polarion start."
	exit 1
fi

# Start Polarion service
service polarion start

SVN_APACHE_CONF="/etc/apache2/conf-available/polarionSVN.conf"

if [ -f "$SVN_APACHE_CONF" ]; then
	echo "Normalizing SVN Apache config after Polarion start..."

	# Polarion may regenerate this file during service start. Enforce file-based
	# auth and repo access policy after startup so admin/admin and SVN access keep working.
	awk '
		BEGIN {
			skip_repo = 0
			skip_repo_local = 0
			skip_ldap = 0
			skip_dbd = 0
		}
		/^<Location \/repo>$/ {
			skip_repo = 1
			next
		}
		skip_repo {
			if (/^<\/Location>$/) {
				skip_repo = 0
			}
			next
		}
		/^<Location \/repo-local>$/ {
			skip_repo_local = 1
			next
		}
		skip_repo_local {
			if (/^<\/Location>$/) {
				skip_repo_local = 0
			}
			next
		}
		/^<IfModule mod_authnz_ldap\.c>$/ {
			skip_ldap = 1
			next
		}
		skip_ldap {
			if (/^<\/IfModule>$/) {
				skip_ldap = 0
			}
			next
		}
		/^<IfModule mod_dbd\.c>$/ {
			skip_dbd = 1
			next
		}
		skip_dbd {
			if (/^<\/IfModule>$/) {
				skip_dbd = 0
			}
			next
		}
		/^[[:space:]]*(DBDriver|DBDParams|AuthnProviderAlias|AuthDBDUserPWQuery|AuthBasicProvider[[:space:]]+dbd)/ {
			next
		}
		{ print }
		END {
			print ""
			print "<Location /repo>"
			print ""
			print "# Enable Web DAV HTTP access methods"
			print "DAV svn"
			print "# Repository location"
			print "SVNPath \"/srv/polarion/svn/repo\""
			print "# Write requests from WebDAV clients result in automatic commits"
			print "SVNAutoversioning on"
			print ""
			print "# Our access control policy"
			print "AuthzSVNAccessFile \"/srv/polarion/svn/access\""
			print "SVNPathAuthz short_circuit"
			print ""
			print "# No anonymous access, always require authenticated users"
			print "Require valid-user"
			print ""
			print "# How to authenticate a user. (NOTE: Polarion does not currently support HTTP Digest access authentication.)"
			print "AuthType Basic"
			print "AuthName \"Subversion repository\""
			print "AuthUserFile \"/srv/polarion/svn/passwd\""
			print ""
			print "</Location>"
			print ""
			print "<Location /repo-local>"
			print ""
			print "# Enable Web DAV HTTP access methods"
			print "DAV svn"
			print "# Repository location"
			print "SVNPath \"/srv/polarion/svn/repo\""
			print "# Write requests from WebDAV clients result in automatic commits"
			print "SVNAutoversioning on"
			print ""
			print "# Our access control policy"
			print "AuthzSVNAccessFile \"/srv/polarion/svn/access\""
			print "SVNPathAuthz short_circuit"
			print ""
			print "# No anonymous access, always require authenticated users"
			print "Require valid-user"
			print ""
			print "# How to authenticate a user. (NOTE: Polarion does not currently support HTTP Digest access authentication.)"
			print "AuthType Basic"
			print "AuthName \"Subversion repository\""
			print "AuthUserFile \"/srv/polarion/svn/passwd\""
			print ""
			print "</Location>"
		}
	' "$SVN_APACHE_CONF" >"${SVN_APACHE_CONF}.tmp" && mv "${SVN_APACHE_CONF}.tmp" "$SVN_APACHE_CONF"

	sed -i '/^[[:space:]]*DBD[A-Za-z].*$/d' "$SVN_APACHE_CONF"
	sed -i '/^[[:space:]]*AuthnProviderAlias[[:space:]]\+dbd.*$/d' "$SVN_APACHE_CONF"
	sed -i '/^[[:space:]]*AuthDBD.*$/d' "$SVN_APACHE_CONF"
	sed -i '/^[[:space:]]*AuthBasicProvider[[:space:]]\+dbd.*$/d' "$SVN_APACHE_CONF"

	SVN_PASSWD_FILE="/srv/polarion/svn/passwd"
	if [ -f "$SVN_PASSWD_FILE" ]; then
		htpasswd -bm "$SVN_PASSWD_FILE" admin admin >/dev/null
	else
		htpasswd -cbm "$SVN_PASSWD_FILE" admin admin >/dev/null
	fi
	chown polarion:www-data "$SVN_PASSWD_FILE" || true
	chmod 0664 "$SVN_PASSWD_FILE" || true

	a2dismod -f ldap authnz_ldap dbd authn_dbd >/dev/null 2>&1 || true
	service apache2 restart || true
fi
