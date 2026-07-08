#!/bin/bash
# Built-in Mailpit mail catcher.
#
# Runs by default so a single Polarion container is a self-contained mail-debugging
# setup — outgoing notification mail is captured instead of sent:
#   - SMTP   on 0.0.0.0:25  (Polarion is pointed at 127.0.0.1:25 by 04-configure-properties.sh)
#   - web UI on 0.0.0.0:8025
# Publish -p 8025:8025 to read captured mail from the host (add -p 25:25 only if you
# also want to send to the catcher from outside the container).
#
# Disable with MAILPIT_EMBEDDED=false. If you point Polarion at a real mail server via
# SMTP_HOST, the catcher steps aside automatically.
#
# This script is sourced by polarion_starter.sh, so it must start Mailpit in the
# background and return immediately.

if [[ "${MAILPIT_EMBEDDED:-}" == "false" ]]; then
    echo "Built-in Mailpit disabled (MAILPIT_EMBEDDED=false)."
elif [[ -n "${SMTP_HOST:-}" && "${SMTP_HOST}" != "127.0.0.1" && "${SMTP_HOST}" != "localhost" ]]; then
    # An explicit external SMTP host takes precedence; starting a local catcher that
    # nothing sends to would just waste a process.
    echo "Built-in Mailpit skipped: SMTP_HOST=${SMTP_HOST} is set, mail is routed there instead."
elif ! command -v mailpit >/dev/null 2>&1; then
    echo "WARNING: the mailpit binary is not installed; skipping the built-in catcher."
else
    echo "Launching built-in Mailpit catcher (SMTP :25, web UI :8025)..."
    MP_SMTP_BIND_ADDR="${MP_SMTP_BIND_ADDR:-0.0.0.0:25}" \
        mailpit >/tmp/mailpit.log 2>&1 &
    echo "Built-in Mailpit launched (PID $!). Logs: /tmp/mailpit.log"
fi
