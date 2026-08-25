#!/bin/bash
# Applies the TZ environment variable (passed via "-e TZ=Region/City" at "docker run" /
# "container run" time, e.g. by scripts/polarionctl.sh detecting the host's local timezone)
# to the container's system clock. Runs first (00-) so every later step, service, and log
# timestamp reflects local time instead of the image's default UTC ("Zulu") clock.

TARGET_TZ="${TZ:-Etc/UTC}"
ZONEINFO_PATH="/usr/share/zoneinfo/${TARGET_TZ}"

if [ -f "$ZONEINFO_PATH" ]; then
    ln -snf "$ZONEINFO_PATH" /etc/localtime
    echo "$TARGET_TZ" > /etc/timezone
    echo "Configured container timezone: $TARGET_TZ (current time: $(date))"
else
    echo "WARNING: Unknown TZ value '$TARGET_TZ' (no $ZONEINFO_PATH found). Falling back to Etc/UTC." >&2
    export TZ=Etc/UTC
fi
