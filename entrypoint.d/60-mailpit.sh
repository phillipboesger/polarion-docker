#!/bin/bash
# Optional embedded Mailpit mail catcher.
#
# Enabled at runtime with MAILPIT_EMBEDDED=true. When on, Mailpit runs inside the
# Polarion container so a single container is a self-contained mail-debugging setup
# (no sidecar required):
#   - SMTP   on 0.0.0.0:25  (Polarion is pointed at 127.0.0.1:25 by 04-configure-properties.sh)
#   - web UI on 0.0.0.0:8025
# Publish -p 8025:8025 (and optionally -p 25:25) to reach it from the host.
#
# This script is sourced by polarion_starter.sh, so it must start Mailpit in the
# background and return immediately. The Compose setup keeps using the dedicated
# mailpit sidecar instead and leaves MAILPIT_EMBEDDED unset.

if [[ "${MAILPIT_EMBEDDED:-}" != "true" ]]; then
    echo "Embedded Mailpit disabled (set MAILPIT_EMBEDDED=true to enable the in-container catcher)."
elif [[ -n "${SMTP_HOST:-}" && "${SMTP_HOST}" != "127.0.0.1" && "${SMTP_HOST}" != "localhost" ]]; then
    # An explicit external SMTP host (e.g. the Compose sidecar) takes precedence;
    # starting a local catcher that nothing sends to would just waste a process.
    echo "Embedded Mailpit skipped: SMTP_HOST=${SMTP_HOST} is set, mail is routed there instead."
elif ! command -v mailpit >/dev/null 2>&1; then
    echo "WARNING: MAILPIT_EMBEDDED=true but the mailpit binary is not installed; skipping embedded catcher."
else
    echo "Launching embedded Mailpit catcher (SMTP :25, web UI :8025)..."
    MP_SMTP_BIND_ADDR="${MP_SMTP_BIND_ADDR:-0.0.0.0:25}" \
        mailpit >/tmp/mailpit.log 2>&1 &
    echo "Embedded Mailpit launched (PID $!). Logs: /tmp/mailpit.log"
fi
