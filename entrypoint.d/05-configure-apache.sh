#!/bin/bash
# Enable Apache ProxyPass for WebSockets (fix suggested by community)
echo "Configuring Apache WebSocket Proxy..."
sed -i -e '/^ProxyPass \/polarion/i ProxyPassMatch ^/(polarion/ws)$ ws://127.0.0.1:8889/$1' /etc/apache2/conf-enabled/polarion.conf

enable_apache_module_if_available() {
    local module="$1"

    if [ -f "/etc/apache2/mods-available/${module}.load" ] || [ -f "/etc/apache2/mods-available/${module}.conf" ]; then
        a2enmod "$module" >/dev/null 2>&1 || true
    fi
}

validate_apache_config() {
    echo "Validating Apache configuration..."
    if ! apache2ctl -t >/dev/null 2>&1; then
        echo "❌ Apache configuration is invalid."
        return 1
    fi
    echo "✅ Apache configuration is valid."
}

SVN_APACHE_CONF="/etc/apache2/conf-available/polarionSVN.conf"
SVN_ALIAS_LOCATION="/repo-local"
SVN_ALIAS_RELOAD_REQUIRED=0

normalize_svn_apache_config() {
    local src="$1"
    local tmp

    tmp="$(mktemp)"
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
            print "AuthzSVNAccessFile \"^/.polarion/access\""
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
            print "AuthzSVNAccessFile \"^/.polarion/access\""
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
    ' "$src" >"$tmp"

    mv "$tmp" "$src"
}

strip_dbd_directives() {
    local src="$1"

    # Remove any remaining DBD-related directives that make Apache startup depend
    # on DB schema objects being present during container bootstrap.
    sed -i '/^[[:space:]]*DBD[A-Za-z].*$/d' "$src"
    sed -i '/^[[:space:]]*AuthnProviderAlias[[:space:]]\+dbd.*$/d' "$src"
    sed -i '/^[[:space:]]*AuthDBD.*$/d' "$src"
    sed -i '/^[[:space:]]*AuthBasicProvider[[:space:]]\+dbd.*$/d' "$src"
}

if [ -f "$SVN_APACHE_CONF" ]; then
    echo "Normalizing $SVN_APACHE_CONF..."
    normalize_svn_apache_config "$SVN_APACHE_CONF"
    strip_dbd_directives "$SVN_APACHE_CONF"
    SVN_ALIAS_RELOAD_REQUIRED=1
fi

# Ensure Apache has a ServerName to avoid startup warning and start Apache
if ! grep -q "^ServerName" /etc/apache2/apache2.conf; then
    echo "ServerName localhost" >> /etc/apache2/apache2.conf
fi

echo "Enabling required Apache modules..."
enable_apache_module_if_available proxy
enable_apache_module_if_available proxy_http
enable_apache_module_if_available proxy_ajp
enable_apache_module_if_available proxy_wstunnel
enable_apache_module_if_available dav
enable_apache_module_if_available dav_svn
enable_apache_module_if_available authz_svn
a2dismod -f ldap authnz_ldap dbd authn_dbd >/dev/null 2>&1 || true

if ! validate_apache_config; then
    echo "❌ Aborting Apache start due to invalid configuration."
else
    service apache2 start
    echo "✅ Apache started successfully."
fi

# Configure redirect from / to /polarion/
if [ ! -f /etc/apache2/conf-available/polarion-redirect.conf ]; then
    cat >/etc/apache2/conf-available/polarion-redirect.conf << 'EOF'
RedirectMatch ^/$ /polarion/
EOF
    a2enconf polarion-redirect
    validate_apache_config
    service apache2 reload
fi

if [ "$SVN_ALIAS_RELOAD_REQUIRED" -eq 1 ]; then
    validate_apache_config
    service apache2 reload
fi
