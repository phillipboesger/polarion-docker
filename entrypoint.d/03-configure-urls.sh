#!/bin/bash
# Fix repository URLs in polarion.properties for container environment
# Replace localhost with 127.0.0.1 for proper container networking
sed -i 's|base.url=http://localhost|base.url=http://127.0.0.1|g' /opt/polarion/etc/polarion.properties
sed -i 's|repo=http://localhost/repo|repo=http://127.0.0.1/repo|g' /opt/polarion/etc/polarion.properties
sed -i 's|controlHostname=localhost|controlHostname=127.0.0.1|g' /opt/polarion/etc/polarion.properties

# Fix repository URLs in existing configuration files to use 127.0.0.1 instead of localhost
find /opt/polarion -name "*.properties" -exec sed -i 's/localhost/127.0.0.1/g' {} \;
