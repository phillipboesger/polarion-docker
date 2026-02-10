#!/bin/bash
# Configure PostgreSQL to listen on all addresses
PG_CONF="/opt/polarion/data/postgres-data/postgresql.conf"
if [ -f "$PG_CONF" ]; then
    echo "Configuring PostgreSQL to listen on all addresses..."
    # Ensure listen_addresses is set to '*'
    # First, comment out any existing listen_addresses to avoid conflicts
    sed -i "s/^listen_addresses/#listen_addresses/g" "$PG_CONF"
    # Append the correct configuration
    echo "listen_addresses = '*'" >> "$PG_CONF"
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
