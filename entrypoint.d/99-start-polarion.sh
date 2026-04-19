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

normalize_repo_permissions() {
	local repo_dir

	for repo_dir in /srv/polarion/svn/repo /opt/polarion/data/svn/repo; do
		[ -d "$repo_dir" ] || continue
		echo "Normalizing SVN repository permissions at $repo_dir"
		chgrp -R www-data "$repo_dir" || true
		find "$repo_dir" -type d -exec chmod 2775 {} + || true
		find "$repo_dir" -type f -exec chmod 0664 {} + || true
	done
}

echo "Checking Subversion endpoint readiness..."
SVN_READY=false
for i in $(seq 1 60); do
	if [ $((i % 10)) -eq 0 ]; then
		service apache2 restart || true
	fi

	if choose_repo_host >/dev/null 2>&1; then
		SVN_READY=true
		break
	fi
	sleep 1
done

if [ "$SVN_READY" != "true" ]; then
	echo "ERROR: SVN endpoint /repo did not become reachable before Polarion start."
	exit 1
fi

echo "Applying default-local repository settings to polarion.properties"
sed -i 's|^base.url=.*|base.url=http://localhost|' /opt/polarion/etc/polarion.properties
sed -i 's|^repo=.*|repo=http://localhost/repo-local|' /opt/polarion/etc/polarion.properties
sed -i 's|^controlHostname=.*|controlHostname=localhost|' /opt/polarion/etc/polarion.properties

# Keep local basic-auth account available for repo-local usage.
SVN_PASSWD_FILE="/srv/polarion/svn/passwd"
if [ -f "$SVN_PASSWD_FILE" ]; then
	htpasswd -bm "$SVN_PASSWD_FILE" admin admin >/dev/null
else
	htpasswd -cbm "$SVN_PASSWD_FILE" admin admin >/dev/null
fi
chown polarion:www-data "$SVN_PASSWD_FILE" || true
chmod 0664 "$SVN_PASSWD_FILE" || true

# Ensure Apache (www-data) can write SVN repo lock/index files during commits.
normalize_repo_permissions

# Start Polarion service
service polarion start
