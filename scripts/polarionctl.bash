#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./polarion-runtime-lib.sh
source "${SCRIPT_DIR}/polarion-runtime-lib.sh"

usage() {
	cat <<'EOF'
Usage: sh scripts/polarionctl.sh <action>

Actions:
  system-start   Start Apple container system services if runtime=container
  builder-start  Start Apple container builder if runtime=container
  build-image    Build the Polarion image for the selected runtime
  start          Start Polarion for the selected runtime
  stop           Stop and remove Polarion for the selected runtime
  logs           Stream Polarion application logs
  errors         Stream Polarion application errors only
EOF
}

action="${1:-help}"

if [ -z "${REQUESTED_POLARION_RUNTIME}" ]; then
	case "${action}" in
		system-start|builder-start|build-image|start)
			if polarion_host_is_apple_silicon && polarion_command_available container; then
				POLARION_RUNTIME="container"
			fi
			;;
	esac
fi

case "${action}" in
	help|-h|--help)
		usage
		;;
	system-start)
		if polarion_is_apple_container_runtime; then
			polarion_ensure_container_system
		else
			echo "Docker runtime does not require a system start step."
		fi
		;;
	builder-start)
		if polarion_is_apple_container_runtime; then
			polarion_ensure_builder
		else
			echo "Docker runtime does not use the Apple container builder."
		fi
		;;
	build-image)
		if polarion_is_apple_container_runtime; then
			polarion_ensure_builder
			cd "${REPO_ROOT}"
			container build --platform "${POLARION_PLATFORM}" --tag "${POLARION_IMAGE}" --file "${POLARION_DOCKERFILE}" "${REPO_ROOT}"
		else
			polarion_require_command docker
			cd "${REPO_ROOT}"
			DOCKER_BUILDKIT=1 docker build --platform "${POLARION_PLATFORM}" --tag "${POLARION_IMAGE}" --file "${POLARION_DOCKERFILE}" "${REPO_ROOT}"
		fi
		;;
	start)
		polarion_ensure_volume "${POLARION_DATA_VOLUME}"
		polarion_ensure_volume "${POLARION_EXTENSIONS_VOLUME}"
		polarion_remove_container

		if polarion_is_apple_container_runtime; then
			polarion_ensure_container_system
			run_args=(
				run -d
				--name "${POLARION_CONTAINER_NAME}"
				--platform "${POLARION_PLATFORM}"
				--cpus "${POLARION_CONTAINER_CPUS}"
				--memory "${POLARION_CONTAINER_MEMORY}"
				-p "${POLARION_BIND_HOST}:${POLARION_HTTP_PORT}:80"
				-p "${POLARION_BIND_HOST}:${POLARION_DB_PORT}:5433"
				-p "${POLARION_BIND_HOST}:${POLARION_JDWP_PORT}:5005"
				-e "JAVA_OPTS=${POLARION_JAVA_OPTS}"
				-e "JDWP_ENABLED=${POLARION_JDWP_ENABLED}"
				-v "${POLARION_DATA_VOLUME}:/opt/polarion/data/svn"
				-v "${POLARION_EXTENSIONS_VOLUME}:/opt/polarion/polarion/extensions"
			)
			if polarion_platform_needs_rosetta; then
				run_args+=(--rosetta)
			fi
			run_args+=("${POLARION_IMAGE}")
			container "${run_args[@]}"
		else
			polarion_require_command docker
			docker run -d \
				--name "${POLARION_CONTAINER_NAME}" \
				--platform "${POLARION_PLATFORM}" \
				--restart unless-stopped \
				-p "${POLARION_HTTP_PORT}:80" \
				-p "${POLARION_DB_PORT}:5433" \
				-p "${POLARION_JDWP_PORT}:5005" \
				-e "JAVA_OPTS=${POLARION_JAVA_OPTS}" \
				-e "JDWP_ENABLED=${POLARION_JDWP_ENABLED}" \
				-v "${POLARION_DATA_VOLUME}:/opt/polarion/data/svn" \
				-v "${POLARION_EXTENSIONS_VOLUME}:/opt/polarion/polarion/extensions" \
				"${POLARION_IMAGE}"
		fi
		polarion_wait_for_http_access
		;;
	stop)
		if polarion_is_apple_container_runtime; then
			container stop "${POLARION_CONTAINER_NAME}" >/dev/null 2>&1 || true
			container delete --force "${POLARION_CONTAINER_NAME}" >/dev/null 2>&1 || true
		else
			docker rm -f "${POLARION_CONTAINER_NAME}" >/dev/null 2>&1 || true
		fi
		;;
	logs)
		polarion_runtime_exec "${POLARION_CONTAINER_NAME}" 'tail -f $(ls -t /opt/polarion/data/logs/main/*.log | head -n 1)'
		;;
	errors)
		polarion_runtime_exec "${POLARION_CONTAINER_NAME}" 'tail -f $(ls -t /opt/polarion/data/logs/main/*.log | head -n 1) | grep --line-buffered -E "ERROR|Exception|Caused by"'
		;;
	*)
		usage
		exit 1
		;;
esac
