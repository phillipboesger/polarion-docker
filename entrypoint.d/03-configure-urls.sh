#!/bin/bash
# Keep loopback host as localhost to support IPv6-only listeners (e.g. ::1).
# Forcing 127.0.0.1 can break internal HTTP calls to /repo when Apache listens on localhost/IPv6.
PROPS_FILE="/opt/polarion/etc/polarion.properties"
if [ ! -f "$PROPS_FILE" ]; then
    echo "WARNING: $PROPS_FILE not found; skipping localhost URL rewrite." >&2
    return 1
fi
sed -i 's|base.url=http://127.0.0.1|base.url=http://localhost|g' "$PROPS_FILE"
sed -i 's|repo=http://127.0.0.1/repo|repo=http://localhost/repo|g' "$PROPS_FILE"
sed -i 's|controlHostname=127.0.0.1|controlHostname=localhost|g' "$PROPS_FILE"
