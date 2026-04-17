#!/bin/bash

echo "Checking Apache service status before Polarion start..."
if ! service apache2 status >/dev/null 2>&1; then
	echo "Apache is not running, attempting restart..."
	service apache2 restart || true
fi

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
for i in $(seq 1 30); do
	if REPO_HOST="$(choose_repo_host)"; then
		echo "SVN endpoint is reachable via ${REPO_HOST} (HTTP $(get_http_code "$REPO_HOST"))"
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
	echo "WARNING: SVN endpoint /repo did not become reachable before Polarion start."
	container_ip="$(hostname -i | awk '{print $1}')"
	wget -S --spider -T 5 -t 1 http://localhost/repo 2>&1 || true
	wget -S --spider -T 5 -t 1 http://127.0.0.1/repo 2>&1 || true
	if [ -n "$container_ip" ]; then
		wget -S --spider -T 5 -t 1 "http://${container_ip}/repo" 2>&1 || true
	fi
	ss -ltnp 2>/dev/null | grep ':80' || true
fi

# Start Polarion service
service polarion start
