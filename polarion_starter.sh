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

# Update Polarion properties with correct container-specific settings
cat >> /opt/polarion/etc/polarion.properties << 'PROPS_EOF'

# Container-specific configuration fixes
com.polarion.svn.url=http://127.0.0.1/repo
PROPS_EOF

# Fix repository URLs in existing configuration files to use 127.0.0.1 instead of localhost
find /opt/polarion -name "*.properties" -exec sed -i 's/localhost/127.0.0.1/g' {} \;

# Enable required Apache modules for Polarion functionality
a2enmod proxy
a2enmod proxy_ajp
a2enmod ssl
a2enmod rewrite
a2enmod dav_svn

# Create Polarion virtual host configuration with SVN support
cat > /etc/apache2/sites-available/polarion.conf << 'EOF'
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/html
    
    ProxyPreserveHost On
    ProxyRequests Off
    
    # SVN repository is handled by mod_dav_svn, not proxied
    # This must come BEFORE any other proxy rules
    ProxyPass /repo !
    
    # Proxy to Polarion via AJP
    ProxyPass /polarion ajp://127.0.0.1:8889/polarion
    ProxyPassReverse /polarion ajp://127.0.0.1:8889/polarion
    
    # Proxy root to Polarion (but exclude /repo)
    ProxyPass / ajp://127.0.0.1:8889/polarion/
    ProxyPassReverse / ajp://127.0.0.1:8889/polarion/
    
    ErrorLog ${APACHE_LOG_DIR}/polarion_error.log
    CustomLog ${APACHE_LOG_DIR}/polarion_access.log combined
</VirtualHost>

# Configure HTTPS virtual host with SSL support
<VirtualHost *:443>
    ServerName localhost
    DocumentRoot /var/www/html
    
    # Enable SSL
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
    SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
    
    # Proxy configuration
    ProxyPreserveHost On
    ProxyRequests Off
    
    # SVN repository is handled by mod_dav_svn, not proxied
    # This must come BEFORE any other proxy rules
    ProxyPass /repo !
    
    # Proxy to Polarion via AJP protocol
    ProxyPass /polarion ajp://127.0.0.1:8889/polarion
    ProxyPassReverse /polarion ajp://127.0.0.1:8889/polarion
    
    # Proxy root to Polarion (but exclude /repo)
    ProxyPass / ajp://127.0.0.1:8889/polarion/
    ProxyPassReverse / ajp://127.0.0.1:8889/polarion/
    
    # Logging configuration
    ErrorLog ${APACHE_LOG_DIR}/polarion_ssl_error.log
    CustomLog ${APACHE_LOG_DIR}/polarion_ssl_access.log combined
</VirtualHost>
EOF

# Enable the Polarion site and disable default Apache site
a2ensite polarion
a2dissite 000-default

# Fix Apache ports.conf to avoid duplicate Listen directives
sed -i '/^Listen 80$/d; /^Listen 443$/d' /etc/apache2/ports.conf
sed -i '4i Listen 80' /etc/apache2/ports.conf

# Start Apache web server
service apache2 start

# Configure Polarion properties file
FILE="/opt/polarion/etc/polarion.properties"

# Define additional Polarion parameters
OTHER_PARAMS=(
    "com.siemens.polarion.rest.enabled=true"
    "com.siemens.polarion.rest.swaggerUi.enabled=true"
    "com.siemens.polarion.rest.cors.allowedOrigins=*"
    "com.siemens.polarion.license.salt.enabled=false"
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

# Configure JDWP debugging by modifying config.sh before service start
CONFIG_FILE="/opt/polarion/etc/config.sh"
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