#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./polarion-runtime-lib.sh
source "${SCRIPT_DIR}/polarion-runtime-lib.sh"

usage() {
	cat <<'EOF'
Usage: bash scripts/polarionctl.sh <action>

Actions:
  system-start   Start Apple container system services if runtime=container
  builder-start  Start Apple container builder if runtime=container
  builder-stop   Stop Apple container builder if runtime=container
  list-zips      List Polarion installer ZIPs available in data/
  build-image    Build the Polarion image for the selected runtime
                 (POLARION_ZIP=<file> picks the archive; tag derived per version)
  list-images    List locally available Polarion images for the active runtime
  start          Start Polarion for the selected runtime (POLARION_IMAGE picks one)
  stop           Stop and remove Polarion for the selected runtime
  logs           Stream Polarion application logs
  errors         Stream Polarion application errors only
EOF
}

action="${1:-help}"

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
	builder-stop)
		if polarion_is_apple_container_runtime; then
			polarion_stop_builder
		else
			echo "Docker runtime does not use the Apple container builder."
		fi
		;;
	list-zips)
		polarion_list_zips
		;;
	build-image)
		# Resolve which Polarion ZIP to build from data/.
		build_zip="${POLARION_ZIP:-}"
		available_zips=()
		while IFS= read -r zip_entry; do
			[ -n "${zip_entry}" ] && available_zips+=("${zip_entry}")
		done < <(polarion_list_zips)

		if [ "${#available_zips[@]}" -eq 0 ]; then
			polarion_usage_error "No Polarion installer ZIP (polarion*.zip) found in ${POLARION_DATA_DIR}; add one (e.g. PolarionALM_2512.zip) before building."
		fi

		if [ -z "${build_zip}" ]; then
			if [ "${#available_zips[@]}" -eq 1 ]; then
				build_zip="${available_zips[0]}"
			else
				polarion_usage_error "Multiple Polarion ZIPs found in ${POLARION_DATA_DIR}; set POLARION_ZIP=<filename> to choose one of: ${available_zips[*]}"
			fi
		else
			build_zip="$(basename "${build_zip}")"
			if [ ! -f "${POLARION_DATA_DIR}/${build_zip}" ]; then
				polarion_usage_error "Selected POLARION_ZIP '${build_zip}' not found in ${POLARION_DATA_DIR}."
			fi
		fi

		# Derive a version-specific tag (e.g. polarion:2512) and additionally tag the
		# build as polarion:local so that alias always points at the most recent build.
		# Both tags are applied atomically at build time, so consumers that default to
		# polarion:local (start, Compose) keep working regardless of runtime.
		build_image_tag="$(polarion_derive_image_tag_from_zip "${build_zip}")"
		build_tags=(--tag "${build_image_tag}")
		if [ "${build_image_tag}" != "polarion:local" ]; then
			build_tags+=(--tag "polarion:local")
			echo "Building ${build_image_tag} (alias polarion:local) from ${build_zip}"
		else
			echo "Building ${build_image_tag} from ${build_zip}"
		fi

		if polarion_is_apple_container_runtime; then
			polarion_ensure_builder
			trap 'polarion_stop_builder' EXIT
			cd "${REPO_ROOT}"
			container build --platform "${POLARION_PLATFORM}" --build-arg "POLARION_ZIP=${build_zip}" "${build_tags[@]}" --file "${POLARION_DOCKERFILE}" "${REPO_ROOT}"
		else
			polarion_require_command docker
			cd "${REPO_ROOT}"
			DOCKER_BUILDKIT=1 docker build --platform "${POLARION_PLATFORM}" --build-arg "POLARION_ZIP=${build_zip}" "${build_tags[@]}" --file "${POLARION_DOCKERFILE}" "${REPO_ROOT}"
		fi
		;;
	list-images)
		polarion_list_images
		;;
	start)
		echo "Starting Polarion from image ${POLARION_IMAGE} (runtime: ${POLARION_RUNTIME})"
		polarion_ensure_volume "${POLARION_DATA_VOLUME}"
		polarion_ensure_volume "${POLARION_EXTENSIONS_VOLUME}"
		polarion_remove_container

		# Optional mail overrides. The built-in Mailpit catcher runs by default; forward
		# SMTP_HOST/SMTP_PORT to route mail to a real server instead, or MAILPIT_EMBEDDED=false
		# to disable the catcher. Only forwarded when explicitly set, so default starts are unchanged.
		extra_env_args=()
		if [ -n "${SMTP_HOST:-}" ]; then extra_env_args+=(-e "SMTP_HOST=${SMTP_HOST}"); fi
		if [ -n "${SMTP_PORT:-}" ]; then extra_env_args+=(-e "SMTP_PORT=${SMTP_PORT}"); fi
		if [ -n "${MAILPIT_EMBEDDED:-}" ]; then extra_env_args+=(-e "MAILPIT_EMBEDDED=${MAILPIT_EMBEDDED}"); fi

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
				-p "${POLARION_BIND_HOST}:${POLARION_MAILPIT_PORT}:8025"
				-e "JAVA_OPTS=${POLARION_JAVA_OPTS}"
				-e "JDWP_ENABLED=${POLARION_JDWP_ENABLED}"
				-v "${POLARION_DATA_VOLUME}:/opt/polarion/data/svn"
				-v "${POLARION_EXTENSIONS_VOLUME}:/opt/polarion/polarion/extensions"
			)
			if polarion_platform_needs_rosetta; then
				run_args+=(--rosetta)
			fi
			# shellcheck disable=SC2206  # intentional split; bash-3.2/set -u empty-array-safe idiom
			run_args+=( ${extra_env_args[@]+"${extra_env_args[@]}"} )
			run_args+=("${POLARION_IMAGE}")
			container "${run_args[@]}"
		else
			polarion_require_command docker
			docker_run_args=(
				run -d
				--name "${POLARION_CONTAINER_NAME}"
				--platform "${POLARION_PLATFORM}"
				--restart unless-stopped
				--cpus "${POLARION_CONTAINER_CPUS}"
				--memory "${POLARION_CONTAINER_MEMORY}"
				-p "${POLARION_HTTP_PORT}:80"
				-p "${POLARION_DB_PORT}:5433"
				-p "${POLARION_JDWP_PORT}:5005"
				-p "${POLARION_MAILPIT_PORT}:8025"
				-e "JAVA_OPTS=${POLARION_JAVA_OPTS}"
				-e "JDWP_ENABLED=${POLARION_JDWP_ENABLED}"
				-v "${POLARION_DATA_VOLUME}:/opt/polarion/data/svn"
				-v "${POLARION_EXTENSIONS_VOLUME}:/opt/polarion/polarion/extensions"
			)
			# shellcheck disable=SC2206  # intentional split; bash-3.2/set -u empty-array-safe idiom
			docker_run_args+=( ${extra_env_args[@]+"${extra_env_args[@]}"} )
			docker_run_args+=("${POLARION_IMAGE}")
			docker "${docker_run_args[@]}"
		fi
		polarion_sync_repo_license
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
