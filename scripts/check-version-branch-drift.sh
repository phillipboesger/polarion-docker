#!/bin/bash
# Reports main changes that never reached the Polarion version branches (vNNNN).
#
# Content-based on purpose: version-branch syncs are squash-merged (the repo allows no merge
# commits), so git ancestry can't tell which main commits a branch already has. Instead every
# file that differs between main and a version branch counts as drift, unless the branch lists
# it in .github/version-branch-overrides (whole file, or only lines matching an ERE).
#
# Drift age = date of the oldest main commit to that file that the branch doesn't have yet.
# Drift older than the grace period fails the run; younger drift is only a warning, so a fresh
# main merge doesn't turn the check red before anyone had the chance to sync.
#
# Usage: check-version-branch-drift.sh [grace_days]
#   Run inside a clone whose remote-tracking refs are fetched (actions/checkout fetch-depth: 0).
#   Env: DRIFT_REMOTE (default origin), DRIFT_GRACE_DAYS (default 14).

set -uo pipefail

REMOTE="${DRIFT_REMOTE:-origin}"
GRACE_DAYS="${1:-${DRIFT_GRACE_DAYS:-14}}"
BASE="${REMOTE}/main"
OVERRIDES_FILE=".github/version-branch-overrides"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

if ! [[ "$GRACE_DAYS" =~ ^[0-9]+$ ]]; then
    echo "ERROR: grace days must be a non-negative integer, got '${GRACE_DAYS}'" >&2
    exit 2
fi
if ! git rev-parse --verify --quiet "$BASE" >/dev/null; then
    echo "ERROR: ${BASE} not found; fetch the remote first" >&2
    exit 2
fi

now="$(date +%s)"
stale_count=0
fresh_count=0

# Prints REF:FILE, minus the lines matching RE when RE is non-empty. Fails if FILE is absent.
file_content() {
    local ref="$1" file="$2" re="$3" content
    content="$(git show "${ref}:${file}" 2>/dev/null)" || return 1
    if [ -n "$re" ]; then
        grep -Ev -- "$re" <<<"$content" || true
    else
        printf '%s\n' "$content"
    fi
}

# Override rule for FILE from the branch's overrides text: prints "ENTRY <regex>" or nothing.
override_rule() {
    awk -v f="$2" '
        /^[[:space:]]*(#|$)/ { next }
        $1 == f { sub(/^[^[:space:]]+[[:space:]]*/, ""); print "ENTRY " $0; exit }
    ' <<<"$1"
}

# Epoch of the oldest main commit to FILE that BRANCH doesn't have: walk main's history of the
# file newest-first until a version matches the branch's; the commit just before it is the first
# one never synced. No match at all (file only exists on the branch, or the branch's version
# never existed on main) -> 0, i.e. maximally stale.
drift_since() {
    local branch="$1" file="$2" re="$3" branch_content commit oldest_unsynced=""
    branch_content="$(file_content "$branch" "$file" "$re")" || branch_content=$'\x01absent'
    while read -r commit; do
        if [ "$(file_content "$commit" "$file" "$re" || printf '\x01absent')" = "$branch_content" ]; then
            printf '%s\n' "${oldest_unsynced:-0}"
            return
        fi
        oldest_unsynced="$(git log -1 --format=%ct "$commit")"
    done < <(git log --topo-order --format=%H "$BASE" -- "$file")
    # Before its first commit the file didn't exist on main: a branch without it matches that.
    if [ "$branch_content" = $'\x01absent' ] && [ -n "$oldest_unsynced" ]; then
        printf '%s\n' "$oldest_unsynced"
    else
        printf '0\n'
    fi
}

{
    echo "## Version branch drift vs \`main\`"
    echo ""
    echo "Grace period: ${GRACE_DAYS} days. Allowed differences come from each branch's \`${OVERRIDES_FILE}\`."
    echo ""
} >>"$SUMMARY"

mapfile -t branches < <(git for-each-ref --format='%(refname:short)' "refs/remotes/${REMOTE}/v[0-9][0-9][0-9][0-9]")
if [ "${#branches[@]}" -eq 0 ]; then
    echo "No version branches found under ${REMOTE}/vNNNN."
    echo "No version branches found." >>"$SUMMARY"
    exit 0
fi

for branch in "${branches[@]}"; do
    name="${branch#"${REMOTE}"/}"
    overrides="$(git show "${branch}:${OVERRIDES_FILE}" 2>/dev/null || true)"
    rows=()
    while read -r file; do
        [ -n "$file" ] || continue
        rule="$(override_rule "$overrides" "$file")"
        re=""
        if [ -n "$rule" ]; then
            re="${rule#ENTRY}"
            re="${re# }"
            # Whole-file override, or the remaining lines are identical after filtering.
            [ -z "$re" ] && continue
            a="$(file_content "$BASE" "$file" "$re")" && b="$(file_content "$branch" "$file" "$re")" \
                && [ "$a" = "$b" ] && continue
        fi
        since="$(drift_since "$branch" "$file" "$re")"
        if ! git cat-file -e "${BASE}:${file}" 2>/dev/null && [ -z "$(git log -1 --format=%H "$BASE" -- "$file")" ]; then
            stale_count=$((stale_count + 1))
            echo "::error file=${file}::${file} exists only on ${name}; list it in ${OVERRIDES_FILE} or remove it"
            rows+=("| \`${file}\` | - | ❌ only on this branch, not in overrides |")
            continue
        fi
        if [ "$since" -eq 0 ]; then
            age="?"
            stale=1
        else
            age=$(( (now - since) / 86400 ))
            stale=$(( age > GRACE_DAYS ))
        fi
        if [ "$stale" -eq 1 ]; then
            stale_count=$((stale_count + 1))
            echo "::error file=${file}::${name} is missing main's changes to ${file} (unsynced for ${age} days)"
            rows+=("| \`${file}\` | ${age} | ❌ stale |")
        else
            fresh_count=$((fresh_count + 1))
            echo "::warning file=${file}::${name} is missing main's changes to ${file} (unsynced for ${age} days)"
            rows+=("| \`${file}\` | ${age} | ⚠️ within grace |")
        fi
    # quotepath=off: otherwise non-ASCII paths come back quoted and `git show ref:path` misses them.
    done < <(git -c core.quotepath=off diff --name-only "$BASE" "$branch" -- . ":(exclude)${OVERRIDES_FILE}")

    if [ "${#rows[@]}" -eq 0 ]; then
        echo "${name}: in sync with main"
        echo "- \`${name}\`: ✅ in sync" >>"$SUMMARY"
    else
        echo "${name}: ${#rows[@]} file(s) differ from main"
        {
            echo ""
            echo "### \`${name}\`"
            echo ""
            echo "| File | Days unsynced | Status |"
            echo "| :--- | ---: | :--- |"
            printf '%s\n' "${rows[@]}"
            echo ""
        } >>"$SUMMARY"
    fi
done

if [ "$stale_count" -gt 0 ]; then
    {
        echo ""
        echo "**${stale_count} difference(s) older than ${GRACE_DAYS} days.** Sync: \`git merge origin/main\` into a \`sync/vNNNN-…\` branch, keep only what the branch's \`${OVERRIDES_FILE}\` allows, open a PR into \`vNNNN\`. A deliberate, permanent difference goes into that overrides file instead."
    } >>"$SUMMARY"
    echo "FAIL: ${stale_count} stale difference(s) between main and the version branches (grace ${GRACE_DAYS} days)."
    exit 1
fi
echo "OK: no drift older than ${GRACE_DAYS} days (${fresh_count} within grace)."
