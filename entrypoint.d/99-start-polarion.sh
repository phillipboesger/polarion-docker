#!/bin/bash

echo "Checking Subversion endpoint readiness..."
SVN_READY=false
for i in $(seq 1 30); do
	HTTP_CODE=$(wget -S --spider -T 5 -t 1 http://127.0.0.1/repo 2>&1 | awk '/HTTP\// {code=$2} END {print code}')
	if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ] || [ "$HTTP_CODE" = "405" ]; then
		echo "SVN endpoint is reachable with HTTP status $HTTP_CODE"
		SVN_READY=true
		break
	fi
	sleep 1
done

if [ "$SVN_READY" != "true" ]; then
	echo "WARNING: SVN endpoint /repo did not become reachable before Polarion start."
	wget -S --spider -T 5 -t 1 http://127.0.0.1/repo 2>&1 || true
fi

# Start Polarion service
service polarion start
