#!/bin/bash

# Polarion Container Startup Script
# This script configures and starts all necessary services for Polarion

# Start PostgreSQL database
sudo -u postgres /usr/lib/postgresql/16/bin/pg_ctl -D /opt/polarion/data/postgres-data -l /opt/polarion/data/postgres-data/log.out -o "-p 5433" start

# Fix repository URLs in polarion.properties for container environment
# Replace localhost with 127.0.0.1 for proper container networking
sed -i 's|base.url=http://localhost|base.url=http://127.0.0.1|g' /opt/polarion/etc/polarion.properties
sed -i 's|repo=http://localhost/repo|repo=http://127.0.0.1/repo|g' /opt/polarion/etc/polarion.properties
sed -i 's|controlHostname=localhost|controlHostname=127.0.0.1|g' /opt/polarion/etc/polarion.properties

# Fix repository URLs in existing configuration files to use 127.0.0.1 instead of localhost
find /opt/polarion -name "*.properties" -exec sed -i 's/localhost/127.0.0.1/g' {} \;

# Configure Polarion properties file
FILE="/opt/polarion/etc/polarion.properties"

# Define additional Polarion parameters
OTHER_PARAMS=(
    "com.siemens.polarion.rest.enabled=true"
    "com.siemens.polarion.rest.swaggerUi.enabled=true"
    "com.siemens.polarion.rest.cors.allowedOrigins=*"
    "com.siemens.polarion.tomcat.cors.allowedOrigins=*"
    "com.siemens.polarion.tomcat.cors.allowedHeaders=*"
    "com.siemens.polarion.tomcat.cors.allowedMethods=*"
    "com.siemens.polarion.license.salt.enabled=false"
    "com.siemens.polarion.analytics.enabled=false"
)

# Configure allowed hosts for Tomcat service
if [[ -n "$ALLOWED_HOSTS" ]]; then
    TomcatServiceRequestSafeListedHosts="TomcatService.request.safeListedHosts=$ALLOWED_HOSTS"
elif [[ "$#" -gt 0 ]]; then
    TomcatServiceRequestSafeListedHostsValues=$(printf "%s," "$@")
    TomcatServiceRequestSafeListedHosts="TomcatService.request.safeListedHosts=${TomcatServiceRequestSafeListedHostsValues%,}" # Remove trailing comma
else
    # Default allowed hosts if none provided
    echo "No ALLOWED_HOSTS provided, using defaults: localhost,127.0.0.1,0.0.0.0"
    TomcatServiceRequestSafeListedHosts="TomcatService.request.safeListedHosts=localhost,127.0.0.1,0.0.0.0"
fi

# Combine all parameters
PARAMS=(
    "$TomcatServiceRequestSafeListedHosts"
    "${OTHER_PARAMS[@]}"
)

# Remove existing end marker
sed -i '/^# End property file$/d' "$FILE"

# Function to add or update parameter in properties file
add_or_update_param() {
    local param="$1"
    local param_name=$(echo "$param" | cut -d '=' -f 1)
    
    if grep -q "^$param_name=" "$FILE"; then
        sed -i "/^$param_name=/c\\$param" "$FILE"
    else
        echo "$param" >> "$FILE"
    fi
}

# Apply all parameters to the properties file
for param in "${PARAMS[@]}"; do
    add_or_update_param "$param"
done

# Add end marker back
echo "# End property file" >> "$FILE"

echo "Polarion Properties Updated Successfully."

# Ensure Apache has a ServerName to avoid startup warning and start Apache
if ! grep -q "^ServerName" /etc/apache2/apache2.conf; then
    echo "ServerName localhost" >> /etc/apache2/apache2.conf
fi
service apache2 start

# Configure redirect from / to /polarion/
if [ ! -f /etc/apache2/conf-available/polarion-redirect.conf ]; then
    cat >/etc/apache2/conf-available/polarion-redirect.conf << 'EOF'
RedirectMatch ^/$ /polarion/
EOF
    a2enconf polarion-redirect
    service apache2 reload
fi

# Configure JDWP debugging by modifying config.sh before service start
CONFIG_FILE="/opt/polarion/etc/config.sh"

# Configure Memory settings from JAVA_OPTS
if [[ -n "$JAVA_OPTS" ]]; then
    echo "Applying JAVA_OPTS: $JAVA_OPTS"
    # Extract Xms and Xmx if present
    NEW_XMS=$(echo "$JAVA_OPTS" | grep -o '\-Xms[0-9]*[mMgG]')
    NEW_XMX=$(echo "$JAVA_OPTS" | grep -o '\-Xmx[0-9]*[mMgG]')

    if [[ -n "$NEW_XMS" ]]; then
        sed -i "s/-Xms[0-9]*[mMgG]/$NEW_XMS/g" "$CONFIG_FILE"
        echo "Updated Xms to $NEW_XMS"
    fi
    if [[ -n "$NEW_XMX" ]]; then
        sed -i "s/-Xmx[0-9]*[mMgG]/$NEW_XMX/g" "$CONFIG_FILE"
        echo "Updated Xmx to $NEW_XMX"
    fi
fi

if [[ -z "$JDWP_ENABLED" ]] || [[ "$JDWP_ENABLED" == "true" ]]; then
    # Add JDWP parameters to PSVN_JServer_opt by injecting after "-server \
    sed -i '/export PSVN_JServer_opt="-server \\/{
        N
        s/export PSVN_JServer_opt="-server \\/export PSVN_JServer_opt="-server \\\n  -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 \\/
    }' "$CONFIG_FILE"
    echo "JDWP debugging will be enabled on port 5005"
else
    echo "JDWP debugging disabled"
fi

# Start Polarion service
service polarion start

# Keep the container running
wait
tail -f /dev/null