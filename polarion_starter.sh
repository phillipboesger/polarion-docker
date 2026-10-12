#!/bin/bash

# Polarion Container Startup Script
# This script configures and starts all necessary services for Polarion
# It delegates modular tasks to scripts found in /opt/polarion/entrypoint.d/

ENTRYPOINT_DIR="/opt/polarion/entrypoint.d"
# Same values entrypoint.d/02-start-postgres.sh uses; kept here too (not sourced from it)
# so shutdown() can still stop Postgres even if 02-start-postgres.sh never ran this boot.
PG_BIN="/usr/lib/postgresql/current/bin"
PGDATA="/opt/polarion/data/postgres-data"

shutdown() {
    echo "Received stop signal, shutting down services..."
    service polarion stop || true
    service apache2 stop || true
    if [ -d "$PGDATA" ]; then
        sudo -u postgres "${PG_BIN}/pg_ctl" -D "$PGDATA" -m fast stop || true
    fi
    # Mailpit (entrypoint.d/60-mailpit.sh) is intentionally left running here: it's
    # stateless/in-memory, so it needs no ordered shutdown and dies with the container.
    echo "Shutdown complete."
    exit 0
}
trap shutdown TERM INT

if [ -d "$ENTRYPOINT_DIR" ]; then
    echo "Processing entrypoint scripts in $ENTRYPOINT_DIR..."

    failed=""
    # Iterate through scripts in alphanumeric order
    for script in "$ENTRYPOINT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            echo "--- Executing $script ---"
            # Source everything to share environment variables and PIDs
            if . "$script"; then
                echo "--- OK: $script ---"
            else
                rc=$?
                echo "!!! FAILED ($rc): $script" >&2
                failed="${failed} $(basename "$script")"
            fi
        fi
    done
    if [ -n "$failed" ]; then
        echo "WARNING: entrypoint scripts failed:${failed}" >&2
    fi
else
    echo "WARNING: $ENTRYPOINT_DIR not found. Skipping modular config."
fi

# Keep the container running, but stay interruptible (bash's `wait` returns as soon as a
# trapped signal arrives, instead of Docker having to wait out the full stop grace period).
if [ -n "$failed" ]; then
    echo "Polarion startup sequence complete, but $(echo "$failed" | wc -w) step(s) failed (see WARNING above). Container is up regardless."
else
    echo "Polarion startup sequence complete. Container is ready."
fi
tail -f /dev/null &
wait "$!"
