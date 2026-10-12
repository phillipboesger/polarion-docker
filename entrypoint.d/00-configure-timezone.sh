#!/bin/bash
# Container clock timezone.
#
# Apache and PostgreSQL are started later via "service", which sanitizes the environment and
# drops TZ; some JDKs additionally read /etc/timezone's text content before /etc/localtime.
# So neither can be fixed by just setting the TZ env var or bind-mounting raw bytes onto
# /etc/localtime — this script always materializes an image-local zoneinfo file onto
# /etc/localtime plus its name into /etc/timezone, on every start:
#   - TZ set to a known zone (e.g. -e TZ=Europe/Berlin): use that zone directly. Always wins.
#   - TZ unset (the default) and /etc/host-localtime present (a read-only bind mount added by
#     docker-compose.yml / scripts/polarionctl.sh, or by hand with
#     -v /etc/localtime:/etc/host-localtime:ro): resolve it to a zone name by finding a
#     byte-identical file in THIS image's own /usr/share/zoneinfo, rather than trusting the
#     host's raw bytes as-is. A container's tzdata build can differ from the host's, so a raw
#     copy can byte-match nothing in the image; the JVM's fallback lookup (comparing
#     /etc/localtime against its own zoneinfo db) would then silently disagree with glibc,
#     which just reads the file's content and doesn't care whether it's "known". Resolving to
#     a name first, then applying that name via the SAME code path as an explicit override,
#     keeps every consumer consistent.
#   - Neither TZ nor a resolvable host mount: Etc/UTC, applied explicitly every time (not
#     just left over from the image default), so a stale zone from an earlier run of the same
#     container can't survive a restart with different settings.
# Runs first (00-) so every later step, service, and log timestamp reflects it.

zone_is_valid() {
    # Rejects anything that isn't an actual TZif zone file: /usr/share/zoneinfo also contains
    # plain-text metadata (zone.tab, leapseconds, tzdata.zi, ...) that a bare -f check would
    # accept, and a path-traversal-shaped value ("../../etc/hostname"). An accepted-but-wrong
    # name gets written into postgresql.conf by entrypoint.d/01-configure-postgres.sh, where a
    # value Postgres can't parse as a GUC aborts the server (and this script is sourced, so
    # that would abort the whole container) — so this has to be a real zone, not just a file.
    case "$1" in '' | /* | *..*) return 1 ;; esac
    [ -f "/usr/share/zoneinfo/$1" ] && [ "$(head -c 4 "/usr/share/zoneinfo/$1" 2>/dev/null)" = "TZif" ]
}

resolve_zone_name() {
    # Prints the name of a zoneinfo file in this image that is byte-identical to $1, or
    # nothing if none matches. /right and /posix are alternate representations of the same
    # zones (leap-second-aware / strict-POSIX) and are skipped to avoid noise.
    local target="$1"
    find /usr/share/zoneinfo -type f ! -path '*/posix/*' ! -path '*/right/*' 2>/dev/null \
        | while IFS= read -r candidate; do
            if cmp -s "$candidate" "$target"; then
                printf '%s\n' "${candidate#/usr/share/zoneinfo/}"
                break
            fi
        done
}

apply_zone() {
    # Materializes zone name $1 (already validated) as the container's timezone for every
    # consumer, independent of how a process is started or what it reads. /etc/timezone is
    # only written on a successful copy, so a failed one can't leave it claiming a zone that
    # /etc/localtime doesn't actually have — the caller must not report success either. This
    # doesn't fully rescue someone who bind-mounted straight onto /etc/localtime instead of
    # /etc/host-localtime (an unsupported, warned-about setup): /etc/localtime then shows
    # whatever the host mounted there, while consumers of the now-untouched /etc/timezone
    # (see entrypoint.d/01-configure-postgres.sh) fall back to Etc/UTC — the warning below
    # tells the caller how to fix that properly instead.
    if ! cp --remove-destination "/usr/share/zoneinfo/$1" /etc/localtime 2>/dev/null; then
        echo "WARNING: /etc/localtime is not writable (bind-mounted read-only? mount the host copy at /etc/host-localtime instead); leaving the container clock as-is." >&2
        return 1
    fi
    printf '%s\n' "$1" > /etc/timezone
}

if [ -n "${TZ:-}" ] && zone_is_valid "$TZ"; then
    if apply_zone "$TZ"; then
        echo "Timezone overridden via TZ=$TZ (current time: $(date))"
    fi
else
    if [ -n "${TZ:-}" ]; then
        echo "WARNING: TZ='$TZ' is not a valid timezone (no matching zoneinfo file); falling back to the detected timezone." >&2
        # Sourced by polarion_starter.sh: dropping the rejected value here keeps every
        # directly-started child (mailpit, exec shells) reading /etc/localtime like
        # everything started via "service" does, instead of inheriting a bad zone.
        unset TZ
    fi

    detected_zone=""
    if [ -f /etc/host-localtime ]; then
        detected_zone="$(resolve_zone_name /etc/host-localtime)"
        if [ -z "$detected_zone" ]; then
            echo "WARNING: the host's timezone data has no byte-identical match in this image's tzdata; falling back to Etc/UTC to keep the system clock and Polarion consistent." >&2
        fi
    fi
    if apply_zone "${detected_zone:-Etc/UTC}"; then
        echo "Using detected container timezone (current time: $(date))"
    fi
fi
