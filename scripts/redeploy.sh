#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./polarion-runtime-lib.sh
source "${SCRIPT_DIR}/polarion-runtime-lib.sh"

# --- PARAMETERS ---
# $1: File or Directory path (Source context from VS Code)
# $2: Container Name (default: polarion)
# $3: Extension Name/Target Folder (default: custom)
# $4: Runtime (default: docker)
# $5: Search depth below input path when no pom.xml is found upward (default: 1)
INPUT_PATH="$1"
CONTAINER_NAME="${2:-polarion}"
EXTENSION_NAME="${3:-custom}"
POLARION_RUNTIME="${4:-${POLARION_RUNTIME:-docker}}"
SEARCH_DEPTH="${5:-${POLARION_REDEPLOY_SEARCH_DEPTH:-1}}"
POLARION_REDEPLOY_PREFLIGHT="${POLARION_REDEPLOY_PREFLIGHT:-true}"
POLARION_REDEPLOY_PREFLIGHT_ONLY="${POLARION_REDEPLOY_PREFLIGHT_ONLY:-false}"

# Start timer
START_TIME=$(date +%s)

# Check: Was input provided?
if [ -z "$INPUT_PATH" ]; then
    echo "❌ Error: No path provided. Please open a file in the editor."
    exit 1
fi

echo "DEBUG: Input Path received: $INPUT_PATH"

if ! [[ "$SEARCH_DEPTH" =~ ^[0-9]+$ ]]; then
    echo "❌ Invalid search depth: $SEARCH_DEPTH"
    exit 1
fi

is_truthy() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        1|true|yes|on)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

trim_whitespace() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s\n' "$value"
}

resolve_input_dir() {
    local input_path="$1"

    if [ -d "$input_path" ]; then
        printf '%s\n' "$input_path"
        return 0
    fi

    if [ -f "$input_path" ]; then
        dirname "$input_path"
        return 0
    fi

    return 1
}

find_project_root_upward() {
    local current_dir="$1"

    for _ in {1..10}; do
        if [ -f "$current_dir/pom.xml" ]; then
            printf '%s\n' "$current_dir"
            return 0
        fi

        if [ "$current_dir" = "/" ]; then
            break
        fi

        current_dir="$(dirname "$current_dir")"
    done

    return 1
}

is_plugin_project_dir() {
    local project_dir="$1"
    local base_name

    base_name="$(basename "$project_dir")"
    [[ "$base_name" == biz.avasis.polarion.* ]]
}

discover_project_roots_below() {
    local search_root="$1"
    local search_depth="$2"
    local max_file_depth=$((search_depth + 1))

    find "$search_root" \
        -mindepth 2 \
        -maxdepth "$max_file_depth" \
        -name pom.xml \
        -not -path '*/target/*' \
        -print | while IFS= read -r pom_path; do
            local project_dir
            project_dir="$(dirname "$pom_path")"
            if is_plugin_project_dir "$project_dir"; then
                printf '%s\n' "$project_dir"
            fi
        done | sort -u
}

derive_bundle_name() {
    local jar_basename="$1"
    local bundle_name="${jar_basename%%_*}"

    if [ "$bundle_name" = "$jar_basename" ]; then
        bundle_name="$(echo "$jar_basename" | sed -E 's/-[0-9].*//')"
    fi

    printf '%s\n' "$bundle_name"
}

read_manifest_header() {
    local jar_file="$1"
    local header_name="$2"

    unzip -p "$jar_file" META-INF/MANIFEST.MF 2>/dev/null | awk -v header_name="$header_name" '
        BEGIN {
            collecting = 0
            emitted = 0
            value = ""
        }
        {
            gsub(/\r/, "", $0)
        }
        index($0, header_name ":") == 1 {
            collecting = 1
            value = substr($0, length(header_name) + 2)
            next
        }
        collecting && substr($0, 1, 1) == " " {
            value = value substr($0, 2)
            next
        }
        collecting {
            print value
            emitted = 1
            exit
        }
        END {
            if (collecting && !emitted) {
                print value
            }
        }
    '
}

bundle_name_from_manifest() {
    local jar_file="$1"
    local bundle_header

    bundle_header="$(read_manifest_header "$jar_file" "Bundle-SymbolicName")"
    if [ -z "$bundle_header" ]; then
        return 1
    fi

    trim_whitespace "${bundle_header%%;*}"
}

required_bundles_from_manifest() {
    local jar_file="$1"
    local require_bundle_header
    local entry=""
    local bundle_name
    local character
    local in_quotes=0
    local position

    require_bundle_header="$(read_manifest_header "$jar_file" "Require-Bundle")"
    if [ -z "$require_bundle_header" ]; then
        return 0
    fi

    emit_required_bundle() {
        local candidate="$1"

        candidate="$(trim_whitespace "$candidate")"
        if [ -z "$candidate" ]; then
            return 0
        fi

        if [[ ";$candidate;" == *";resolution:=optional;"* ]]; then
            return 0
        fi

        bundle_name="$(trim_whitespace "${candidate%%;*}")"
        if [ -n "$bundle_name" ]; then
            printf '%s\n' "$bundle_name"
        fi
    }

    for ((position = 0; position < ${#require_bundle_header}; position++)); do
        character="${require_bundle_header:position:1}"

        if [ "$character" = '"' ]; then
            if [ "$in_quotes" -eq 0 ]; then
                in_quotes=1
            else
                in_quotes=0
            fi
            entry+="$character"
            continue
        fi

        if [ "$character" = ',' ] && [ "$in_quotes" -eq 0 ]; then
            emit_required_bundle "$entry"
            entry=""
            continue
        fi

        entry+="$character"
    done

    emit_required_bundle "$entry" | cat
}

list_contains_line() {
    local needle="$1"
    local haystack="$2"

    printf '%s\n' "$haystack" | grep -Fx -- "$needle" >/dev/null 2>&1
}

collect_bundle_names_from_bundles_info() {
    polarion_runtime_exec "$CONTAINER_NAME" '
        for bundles_info in \
            /opt/polarion/polarion/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info \
            /opt/polarion/data/workspace/.config/org.eclipse.equinox.simpleconfigurator/bundles.info
        do
            if [ -f "$bundles_info" ]; then
                awk -F, "NF > 0 && \$1 !~ /^#/ { print \$1 }" "$bundles_info"
            fi
        done
    '
}

collect_bundle_names_from_plugin_dir() {
    local plugin_dir="$1"
    local runtime_entries
    local runtime_entry
    local runtime_entry_basename

    runtime_entries="$(polarion_runtime_exec "$CONTAINER_NAME" "find \"$plugin_dir\" -maxdepth 1 -mindepth 1 -print 2>/dev/null")"

    while IFS= read -r runtime_entry; do
        if [ -z "$runtime_entry" ]; then
            continue
        fi

        runtime_entry_basename="$(basename "$runtime_entry")"
        derive_bundle_name "$runtime_entry_basename"
    done <<< "$runtime_entries" | sort -u
}

collect_runtime_bundle_names() {
    local plugin_dest="$1"

    {
        collect_bundle_names_from_bundles_info
        collect_bundle_names_from_plugin_dir "$plugin_dest"
    } | awk 'NF' | sort -u
}

run_preflight_checks() {
    local planned_bundles
    local runtime_bundles
    local available_bundles
    local duplicate_bundles
    local missing_bundle_found=0
    local required_bundle

    echo "🩺 Running redeploy preflight checks..."
    runtime_bundles="$(collect_runtime_bundle_names "$PLUGIN_DEST")" || {
        echo "❌ Preflight failed: unable to inspect bundles from the running ${POLARION_RUNTIME} runtime."
        echo "   Make sure the '${CONTAINER_NAME}' container is running before redeploying."
        exit 1
    }

    planned_bundles="$(printf '%s\n' "${BUNDLE_NAMES[@]}" | awk 'NF' | sort -u)"
    available_bundles="$(printf '%s\n%s\n' "$runtime_bundles" "$planned_bundles" | awk 'NF' | sort -u)"
    duplicate_bundles="$(printf '%s\n' "${BUNDLE_NAMES[@]}" | sort | uniq -d)"

    if [ -n "$duplicate_bundles" ]; then
        echo "⚠️  Preflight warning: multiple projects resolve to the same bundle name:"
        printf '   - %s\n' $duplicate_bundles
    fi

    for index in "${!JAR_FILES[@]}"; do
        while IFS= read -r required_bundle; do
            if [ -z "$required_bundle" ]; then
                continue
            fi

            if ! list_contains_line "$required_bundle" "$available_bundles"; then
                missing_bundle_found=1
                echo "❌ Missing required bundle '${required_bundle}' for '${BUNDLE_NAMES[$index]}'"
                echo "   Project: ${PROJECT_ROOTS[$index]}"
            fi
        done < <(required_bundles_from_manifest "${JAR_FILES[$index]}")
    done

    if [ "$missing_bundle_found" -ne 0 ]; then
        echo "❌ Preflight failed: at least one built plugin declares Require-Bundle dependencies that are not available in the runtime or the current deployment batch."
        echo "   Nothing was copied. Polarion is still running with the previous set of plugins."
        exit 1
    fi

    echo "✅ Preflight passed: all declared Require-Bundle dependencies are available."
}

# --- INTELLIGENT PATH LOGIC ---
START_DIR="$(resolve_input_dir "$INPUT_PATH")" || {
    echo "❌ Error: Path does not exist: $INPUT_PATH"
    exit 1
}

declare -a PROJECT_ROOTS=()
UPWARD_PROJECT_ROOT="$(find_project_root_upward "$START_DIR" || true)"

if [ -n "$UPWARD_PROJECT_ROOT" ]; then
    PROJECT_ROOTS+=("$UPWARD_PROJECT_ROOT")
else
    while IFS= read -r project_root; do
        PROJECT_ROOTS+=("$project_root")
    done < <(discover_project_roots_below "$START_DIR" "$SEARCH_DEPTH")
fi

if [ ${#PROJECT_ROOTS[@]} -eq 0 ]; then
    echo "❌ No pom.xml found upward from '$INPUT_PATH' and no plugin pom.xml found below within depth $SEARCH_DEPTH."
    exit 1
fi

if [ ${#PROJECT_ROOTS[@]} -eq 1 ]; then
    echo "📂 Project Root detected: ${PROJECT_ROOTS[0]}"
else
    echo "📂 Discovered ${#PROJECT_ROOTS[@]} plugin projects within depth $SEARCH_DEPTH:"
    for project_root in "${PROJECT_ROOTS[@]}"; do
        echo "   - $project_root"
    done
fi

# --- CONFIGURATION ---
PLUGIN_DEST="/opt/polarion/polarion/extensions/$EXTENSION_NAME/eclipse/plugins/"
CACHE_PATH="/opt/polarion/data/workspace/.config"
METADATA_PATH="/opt/polarion/data/workspace/.metadata"

declare -a JAR_FILES=()
declare -a JAR_BASENAMES=()
declare -a BUNDLE_NAMES=()

if is_truthy "$POLARION_REDEPLOY_PREFLIGHT_ONLY"; then
    POLARION_REDEPLOY_PREFLIGHT=true
fi

TOTAL_PROJECTS="${#PROJECT_ROOTS[@]}"
PROJECT_INDEX=0
for project_root in "${PROJECT_ROOTS[@]}"; do
    PROJECT_INDEX=$((PROJECT_INDEX + 1))
    echo "🚀 [${PROJECT_INDEX}/${TOTAL_PROJECTS}] Building Extension in ${project_root} (Skipping Tests)..."

    if [ -f "$project_root/mvnw" ]; then
        (
            cd "$project_root"
            ./mvnw clean package -Dmaven.test.skip=true
        )
    else
        (
            cd "$project_root"
            mvn clean package -Dmaven.test.skip=true
        )
    fi

    echo "🔍 Identifying JAR in ${project_root}..."
    jar_file_name="$(find "$project_root/target" -maxdepth 1 -type f -name '*.jar' ! -name '*original-*' ! -name '*sources*' ! -name '*javadoc*' | head -n 1)"

    if [ -z "$jar_file_name" ]; then
        echo "❌ No suitable JAR found in $project_root/target!"
        exit 1
    fi

    jar_basename="$(basename "$jar_file_name")"
    bundle_name="$(bundle_name_from_manifest "$jar_file_name" || true)"
    if [ -z "$bundle_name" ]; then
        bundle_name="$(derive_bundle_name "$jar_basename")"
    fi

    JAR_FILES+=("$jar_file_name")
    JAR_BASENAMES+=("$jar_basename")
    BUNDLE_NAMES+=("$bundle_name")
done

if is_truthy "$POLARION_REDEPLOY_PREFLIGHT"; then
    run_preflight_checks
fi

if is_truthy "$POLARION_REDEPLOY_PREFLIGHT_ONLY"; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    echo "✅ Preflight only mode completed in ${DURATION}s."
    exit 0
fi

echo "📂 Ensuring directory structure inside ${POLARION_RUNTIME}..."
polarion_runtime_exec "$CONTAINER_NAME" "mkdir -p \"$PLUGIN_DEST\""

echo "⏹️ Stopping Polarion Service..."
polarion_runtime_exec "$CONTAINER_NAME" "service polarion stop"

echo "🧹 Clearing Cache while service is stopped..."
polarion_runtime_exec "$CONTAINER_NAME" "rm -rf \"$CACHE_PATH\" \"$METADATA_PATH\""

for index in "${!JAR_FILES[@]}"; do
    echo "🗑️ Cleaning old versions of '${BUNDLE_NAMES[$index]}'..."
    polarion_runtime_exec "$CONTAINER_NAME" "find \"${PLUGIN_DEST}\" -name \"${BUNDLE_NAMES[$index]}[_-]*.jar\" -delete"

    echo "📦 Copying ${JAR_BASENAMES[$index]}..."
    polarion_runtime_copy_file "$CONTAINER_NAME" "${JAR_FILES[$index]}" "$PLUGIN_DEST${JAR_BASENAMES[$index]}"
done

echo "▶️ Starting Polarion Service..."
polarion_runtime_exec "$CONTAINER_NAME" "service polarion start"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✅ Done in ${DURATION}s."
