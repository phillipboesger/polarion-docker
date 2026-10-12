#!/bin/bash
# Polarion Copilot (Siemens AI add-on) and runtime configuration seeding.
#
# POLARION_COPILOT_USERS      Comma-separated user IDs that get a Copilot add-on seat in the
#                             license "users" file (e.g. "admin,jdoe"). Unset = file untouched.
# POLARION_COPILOT_LICENSE    "concurrent" (default) or "named": which Copilot seat type to assign.
# POLARION_RUNTIME_PROPERTIES Runtime properties (Administration > Configuration Properties, global
#                             scope), separated by newlines or ";". Each key is written to the
#                             repository's /.polarion/context.properties ONLY if it is not defined
#                             there yet, so values later changed in the UI are never overwritten.
#                             Typical use: copilot.model.<name>.* and copilot.default.model.
#
# Sourced before 07-normalize-license-permissions.sh (fixes ownership of the users file) and
# 99-start-polarion.sh (normalizes repository permissions after the commit below).

COPILOT_USERS_FILE="${COPILOT_USERS_FILE:-/opt/polarion/polarion/license/users}"
POLARION_SVN_REPO="${POLARION_SVN_REPO:-/opt/polarion/data/svn/repo}"
RUNTIME_PROPERTIES_PATH=".polarion/context.properties"

# Assigns Copilot seats: replaces every existing *CopilotUserN line with one line per valid user.
configure_copilot_users() {
    local license_type="${POLARION_COPILOT_LICENSE:-concurrent}"
    local user index=0
    local -a users

    if [[ "$license_type" != "concurrent" && "$license_type" != "named" ]]; then
        echo "WARNING: POLARION_COPILOT_LICENSE must be 'concurrent' or 'named' (got '$license_type'); skipping Copilot seats." >&2
        return 1
    fi
    if [[ ! -f "$COPILOT_USERS_FILE" ]]; then
        echo "WARNING: license users file $COPILOT_USERS_FILE not found; skipping Copilot seats." >&2
        return 1
    fi

    local -a seats=()
    IFS=$',\n' read -r -d '' -a users <<< "$POLARION_COPILOT_USERS" || true
    for user in "${users[@]}"; do
        user="${user//[[:space:]]/}"
        [[ -z "$user" ]] && continue
        # User IDs end up as raw lines in the users file: reject anything that could inject one.
        if [[ ! "$user" =~ ^[A-Za-z0-9._@-]+$ ]]; then
            echo "WARNING: ignoring invalid Copilot user ID '$user'." >&2
            continue
        fi
        index=$((index + 1))
        seats+=("${license_type}CopilotUser${index}=${user}")
    done
    # Validate before touching the file, so a typo never wipes the existing seats.
    if [[ "$index" -eq 0 ]]; then
        echo "WARNING: POLARION_COPILOT_USERS contains no valid user ID; Copilot seats left unchanged." >&2
        return 1
    fi

    # Rewrite via a temp file and `cat >` (keeps the inode, so a bind-mounted file works too);
    # grep re-terminates a last line that lacks its newline before the seats are appended.
    local tmp_file
    tmp_file="$(mktemp)"
    { grep -v -E '^(named|concurrent)CopilotUser[0-9]+=' "$COPILOT_USERS_FILE"; printf '%s\n' "${seats[@]}"; } > "$tmp_file"
    if ! cat "$tmp_file" > "$COPILOT_USERS_FILE"; then
        echo "WARNING: could not write $COPILOT_USERS_FILE." >&2
        rm -f "$tmp_file"
        return 1
    fi
    rm -f "$tmp_file"
    echo "Assigned $index ${license_type} Polarion Copilot seat(s)."
}

# Adds runtime properties that are not yet present in the repository's context.properties.
seed_runtime_properties() {
    local current entry key missing="" count=0
    local -a entries

    if [[ ! -f "$POLARION_SVN_REPO/format" ]]; then
        echo "WARNING: no SVN repository at $POLARION_SVN_REPO; skipping runtime properties." >&2
        return 1
    fi

    current="$(svnlook cat "$POLARION_SVN_REPO" "$RUNTIME_PROPERTIES_PATH" 2>/dev/null || true)"
    IFS=$'\n;' read -r -d '' -a entries <<< "$POLARION_RUNTIME_PROPERTIES" || true
    for entry in "${entries[@]}"; do
        entry="${entry#"${entry%%[![:space:]]*}"}"
        entry="${entry%"${entry##*[![:space:]]}"}"
        [[ -z "$entry" || "$entry" == \#* ]] && continue
        key="${entry%%=*}"
        if [[ "$entry" != *=* || ! "$key" =~ ^[A-Za-z0-9._-]+$ ]]; then
            echo "WARNING: ignoring malformed runtime property '$entry'." >&2
            continue
        fi
        if grep -q -E "^[[:space:]]*${key//./\\.}[[:space:]]*=" <<< "$current"$'\n'"$missing"; then
            continue
        fi
        missing+="${entry}"$'\n'
        count=$((count + 1))
    done

    if [[ "$count" -eq 0 ]]; then
        echo "Runtime properties already present; nothing to seed."
        return 0
    fi

    local content_file
    content_file="$(mktemp)"
    if [[ -n "$current" ]]; then
        printf '%s\n' "${current%$'\n'}" > "$content_file"
    fi
    printf '%s' "$missing" >> "$content_file"
    local -a actions=()
    if ! svnlook tree "$POLARION_SVN_REPO" "${RUNTIME_PROPERTIES_PATH%/*}" >/dev/null 2>&1; then
        actions+=(mkdir "${RUNTIME_PROPERTIES_PATH%/*}")
    fi
    actions+=(put "$content_file" "$RUNTIME_PROPERTIES_PATH")
    if svnmucc --username polarion -m "Seed runtime properties from POLARION_RUNTIME_PROPERTIES" \
        -U "file://$POLARION_SVN_REPO" "${actions[@]}" >/dev/null; then
        echo "Seeded $count runtime propert$([[ $count -eq 1 ]] && echo y || echo ies) into /$RUNTIME_PROPERTIES_PATH."
    else
        echo "WARNING: could not commit /$RUNTIME_PROPERTIES_PATH." >&2
        rm -f "$content_file"
        return 1
    fi
    rm -f "$content_file"
}

copilot_status=0
if [[ -n "${POLARION_COPILOT_USERS:-}" ]]; then
    configure_copilot_users || copilot_status=1
fi
if [[ -n "${POLARION_RUNTIME_PROPERTIES:-}" ]]; then
    seed_runtime_properties || copilot_status=1
fi
return "$copilot_status"
