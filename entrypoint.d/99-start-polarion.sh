#!/bin/bash

echo "Checking Subversion endpoint readiness..."
SVN_READY=false
for i in $(seq 1 30); do
	HTTP_CODE_LOCALHOST=$(wget -S --spider -T 5 -t 1 http://localhost/repo 2>&1 | awk '/HTTP\// {code=$2} END {print code}')
	HTTP_CODE_IPV4=$(wget -S --spider -T 5 -t 1 http://127.0.0.1/repo 2>&1 | awk '/HTTP\// {code=$2} END {print code}')

	if [ "$HTTP_CODE_LOCALHOST" = "200" ] || [ "$HTTP_CODE_LOCALHOST" = "401" ] || [ "$HTTP_CODE_LOCALHOST" = "403" ] || [ "$HTTP_CODE_LOCALHOST" = "405" ]; then
		echo "SVN endpoint is reachable via localhost with HTTP status $HTTP_CODE_LOCALHOST"
		SVN_READY=true
		break
	fi

	if [ "$HTTP_CODE_IPV4" = "200" ] || [ "$HTTP_CODE_IPV4" = "401" ] || [ "$HTTP_CODE_IPV4" = "403" ] || [ "$HTTP_CODE_IPV4" = "405" ]; then
		echo "SVN endpoint is reachable via 127.0.0.1 with HTTP status $HTTP_CODE_IPV4"
		SVN_READY=true
		break
	fi
	sleep 1
done

if [ "$SVN_READY" != "true" ]; then
	echo "WARNING: SVN endpoint /repo did not become reachable before Polarion start."
	wget -S --spider -T 5 -t 1 http://localhost/repo 2>&1 || true
	wget -S --spider -T 5 -t 1 http://127.0.0.1/repo 2>&1 || true
fi

# Start Polarion service
service polarion start
