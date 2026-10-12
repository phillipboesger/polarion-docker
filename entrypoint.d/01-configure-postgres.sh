#!/bin/bash
# Configure PostgreSQL to listen on all addresses
PG_CONF="/opt/polarion/data/postgres-data/postgresql.conf"
if [ -f "$PG_CONF" ]; then
    echo "Configuring PostgreSQL to listen on all addresses..."
    # Ensure listen_addresses is set to '*'. Guarded so a restart with the same setting
    # doesn't grow the file forever: without this check, every start would comment out the
    # line appended by the previous start and append a fresh one on top of it.
    if ! grep -qxF "listen_addresses = '*'" "$PG_CONF"; then
        # First, comment out any existing listen_addresses to avoid conflicts
        sed -i "s/^listen_addresses/#listen_addresses/g" "$PG_CONF"
        # Append the correct configuration
        echo "listen_addresses = '*'" >> "$PG_CONF"
    fi

    # initdb bakes timezone/log_timezone into the config at whatever zone was active during
    # "docker build" (always Etc/UTC), so they're re-applied here from the zone
    # entrypoint.d/00-configure-timezone.sh just resolved — otherwise Postgres timestamps
    # would stay UTC while the rest of the container follows the detected/overridden zone.
    # Anchored on "=" so this doesn't also match timezone_abbreviations; skipped entirely
    # when already correct so a restart with the same zone doesn't grow the file forever.
    pg_timezone="$(cat /etc/timezone 2>/dev/null || echo Etc/UTC)"
    if ! grep -qxF "timezone = '${pg_timezone}'" "$PG_CONF"; then
        sed -i "s/^timezone[[:space:]]*=/#&/; s/^log_timezone[[:space:]]*=/#&/" "$PG_CONF"
        {
            echo "timezone = '${pg_timezone}'"
            echo "log_timezone = '${pg_timezone}'"
        } >> "$PG_CONF"
    fi
else
    echo "WARNING: $PG_CONF not found! Database might not be initialized correctly."
fi

# Configure pg_hba.conf to allow external connections (access to all databases including history)
PG_HBA="/opt/polarion/data/postgres-data/pg_hba.conf"
if [ -f "$PG_HBA" ]; then
    echo "Configuring pg_hba.conf for external access..."
    if ! grep -q "host all all 0.0.0.0/0 md5" "$PG_HBA"; then
        echo "host all all 0.0.0.0/0 md5" >> "$PG_HBA"
    fi
else
    echo "WARNING: $PG_HBA not found!"
fi
