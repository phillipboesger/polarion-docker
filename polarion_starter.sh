#!/bin/bash

# Polarion Container Startup Script
# This script configures and starts all necessary services for Polarion
# It delegates modular tasks to scripts found in /opt/polarion/entrypoint.d/

ENTRYPOINT_DIR="/opt/polarion/entrypoint.d"

if [ -d "$ENTRYPOINT_DIR" ]; then
    echo "Processing entrypoint scripts in $ENTRYPOINT_DIR..."
    
    # Iterate through scripts in alphanumeric order
    for script in "$ENTRYPOINT_DIR"/*.sh; do
        if [ -f "$script" ]; then
            echo "--- Executing $script ---"
            # Source everything to share environment variables and PIDs
            . "$script"
        fi
    done
else
    echo "WARNING: $ENTRYPOINT_DIR not found. Skipping modular config."
fi

# Keep the container running
echo "Polarion startup sequence complete. Container is ready."
# Loop/Wait to keep container alive
tail -f /dev/null
