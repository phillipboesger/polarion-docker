#!/bin/bash

LICENSE_DIR="/opt/polarion/polarion/license"

mkdir -p "$LICENSE_DIR"
chown -R polarion:www-data "$LICENSE_DIR"
find "$LICENSE_DIR" -type d -exec chmod 2775 {} +

echo "Normalized Polarion license directory permissions."
