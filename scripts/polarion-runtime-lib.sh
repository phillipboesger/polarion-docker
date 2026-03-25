#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REQUESTED_POLARION_RUNTIME="${POLARION_RUNTIME-}"
POLARION_RUNTIME="${POLARION_RUNTIME:-}"
POLARION_CONTAINER_NAME="${POLARION_CONTAINER_NAME:-polarion}"
POLARION_EXTENSION_NAME="${POLARION_EXTENSION_NAME:-custom}"
POLARION_IMAGE="${POLARION_IMAGE:-polarion:local}"
POLARION_HTTP_PORT="${POLARION_HTTP_PORT:-8080}"
POLARION_DB_PORT="${POLARION_DB_PORT:-5433}"
POLARION_JDWP_PORT="${POLARION_JDWP_PORT:-5005}"
POLARION_BIND_HOST="${POLARION_BIND_HOST:-127.0.0.1}"
POLARION_JAVA_OPTS="${POLARION_JAVA_OPTS:--Xmx8g -Xms8g}"
POLARION_JDWP_ENABLED="${POLARION_JDWP_ENABLED:-true}"
POLARION_PLATFORM="${POLARION_PLATFORM:-linux/amd64}"
POLARION_CONTAINER_CPUS="${POLARION_CONTAINER_CPUS:-8}"
POLARION_CONTAINER_MEMORY="${POLARION_CONTAINER_MEMORY:-16g}"
POLARION_BUILDER_CPUS="${POLARION_BUILDER_CPUS:-8}"
POLARION_BUILDER_MEMORY="${POLARION_BUILDER_MEMORY:-16g}"
POLARION_DATA_VOLUME="${POLARION_DATA_VOLUME:-polarion_repo}"
POLARION_EXTENSIONS_VOLUME="${POLARION_EXTENSIONS_VOLUME:-polarion_extensions}"
POLARION_DOCKERFILE="${POLARION_DOCKERFILE:-${REPO_ROOT}/Dockerfile}"
POLARION_START_TIMEOUT="${POLARION_START_TIMEOUT:-900}"
POLARION_START_POLL_INTERVAL="${POLARION_START_POLL_INTERVAL:-5}"

polarion_usage_error() {
	echo "Error: $*" >&2
	exit 1
}

polarion_require_command() {
	command -v "$1" >/dev/null 2>&1 || polarion_usage_error "Required command not found: $1"
}

polarion_command_available() {
	command -v "$1" >/dev/null 2>&1
}

polarion_host_is_apple_silicon() {
	[[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]]
}

polarion_runtime_has_named_container() {
	local runtime="$1"

	case "${runtime}" in
		container)
			polarion_command_available container || return 1
			container inspect "${POLARION_CONTAINER_NAME}" >/dev/null 2>&1
			;;
		docker)
			polarion_command_available docker || return 1
			docker inspect "${POLARION_CONTAINER_NAME}" >/dev/null 2>&1
			;;
		*)
			return 1
			;;
	esac
}

polarion_probe_host() {
	case "${POLARION_BIND_HOST}" in
		""|0.0.0.0|::)
			printf '127.0.0.1\n'
			;;
		*)
			printf '%s\n' "${POLARION_BIND_HOST}"
			;;
	esac
}

polarion_base_url() {
	printf 'http://%s:%s/polarion/' "$(polarion_probe_host)" "${POLARION_HTTP_PORT}"
}

polarion_read_http_status_line() {
	local host="$1"
	local port="$2"
	local path="$3"
	local status_line=""

	exec 3<>"/dev/tcp/${host}/${port}" || return 1
	printf 'GET %s HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' "${path}" >&3
	IFS=$'\r' read -r status_line <&3 || true
	exec 3<&-
	exec 3>&-

	[ -n "${status_line}" ] || return 1
	printf '%s\n' "${status_line}"
}

polarion_http_status_accessible() {
	local status_line="$1"
	local status_code=""

	[ -n "${status_line}" ] || return 1
	status_code="${status_line#HTTP/* }"
	status_code="${status_code%% *}"

	case "${status_code}" in
		2??|3??|401|403)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

polarion_wait_for_http_access() {
	local host
	local url
	local deadline
	local last_status=""

	host="$(polarion_probe_host)"
	url="$(polarion_base_url)"
	deadline=$((SECONDS + POLARION_START_TIMEOUT))

	echo "Waiting for Polarion HTTP endpoint at ${url} ..."

	while (( SECONDS < deadline )); do
		last_status="$(polarion_read_http_status_line "${host}" "${POLARION_HTTP_PORT}" "/polarion/" 2>/dev/null || true)"
		if polarion_http_status_accessible "${last_status}"; then
			echo "Polarion is reachable at ${url} (${last_status})"
			return 0
		fi
		sleep "${POLARION_START_POLL_INTERVAL}"
	done

	if [ -n "${last_status}" ]; then
		echo "Polarion did not become reachable within ${POLARION_START_TIMEOUT}s. Last HTTP response: ${last_status}" >&2
	else
		echo "Polarion did not become reachable within ${POLARION_START_TIMEOUT}s. No HTTP response received from ${url}" >&2
	fi
	echo "Inspect logs with: POLARION_RUNTIME=${POLARION_RUNTIME} bash scripts/polarionctl.sh logs" >&2
	return 1
}

polarion_select_runtime() {
	if [ -n "${REQUESTED_POLARION_RUNTIME}" ]; then
		case "${REQUESTED_POLARION_RUNTIME}" in
			docker|container)
				POLARION_RUNTIME="${REQUESTED_POLARION_RUNTIME}"
				return 0
				;;
			*)
				polarion_usage_error "Unsupported POLARION_RUNTIME '${REQUESTED_POLARION_RUNTIME}'. Use 'docker' or 'container'."
				;;
		esac
	fi

	if polarion_runtime_has_named_container container; then
		POLARION_RUNTIME="container"
		return 0
	fi

	if polarion_runtime_has_named_container docker; then
		POLARION_RUNTIME="docker"
		return 0
	fi

	if polarion_command_available docker; then
		POLARION_RUNTIME="docker"
	elif polarion_command_available container; then
		POLARION_RUNTIME="container"
	else
		POLARION_RUNTIME="docker"
	fi
}

polarion_require_selected_runtime_command() {
	if polarion_is_apple_container_runtime; then
		polarion_require_command container
	else
		polarion_require_command docker
	fi
}

polarion_is_apple_container_runtime() {
	[[ "${POLARION_RUNTIME}" == "container" ]]
}

polarion_platform_needs_rosetta() {
	[[ "${POLARION_PLATFORM}" == *"amd64"* ]]
}

polarion_runtime_exec() {
	local container_name="$1"
	local command_string="$2"

	polarion_require_selected_runtime_command

	if polarion_is_apple_container_runtime; then
		container exec --interactive "${container_name}" sh -c "${command_string}"
	else
		docker exec -i "${container_name}" sh -c "${command_string}"
	fi
}

polarion_runtime_copy_file() {
	local container_name="$1"
	local source_path="$2"
	local target_path="$3"

	polarion_require_selected_runtime_command

	if polarion_is_apple_container_runtime; then
		container exec --interactive "${container_name}" sh -c "cat > \"${target_path}\"" < "${source_path}"
	else
		docker cp "${source_path}" "${container_name}:${target_path}"
	fi
}

polarion_ensure_volume() {
	local volume_name="$1"

	polarion_require_selected_runtime_command

	if polarion_is_apple_container_runtime; then
		if ! container volume inspect "${volume_name}" >/dev/null 2>&1; then
			container volume create "${volume_name}" >/dev/null
		fi
	else
		if ! docker volume inspect "${volume_name}" >/dev/null 2>&1; then
			docker volume create "${volume_name}" >/dev/null
		fi
	fi
}

polarion_remove_container() {
	polarion_require_selected_runtime_command

	if polarion_is_apple_container_runtime; then
		container delete --force "${POLARION_CONTAINER_NAME}" >/dev/null 2>&1 || true
	else
		docker rm -f "${POLARION_CONTAINER_NAME}" >/dev/null 2>&1 || true
	fi
}

polarion_ensure_container_system() {
	if polarion_is_apple_container_runtime; then
		polarion_require_command container
		container system status >/dev/null 2>&1 || container system start
	fi
}

polarion_ensure_builder() {
	if ! polarion_is_apple_container_runtime; then
		return 0
	fi

	polarion_ensure_container_system
	if polarion_platform_needs_rosetta; then
		container system property set build.rosetta true >/dev/null
	fi

	if ! container builder status >/dev/null 2>&1; then
		container builder start --cpus "${POLARION_BUILDER_CPUS}" --memory "${POLARION_BUILDER_MEMORY}"
	fi
}

polarion_select_runtime
