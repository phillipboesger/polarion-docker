#!/bin/bash
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
    "com.polarion.platform.internalPG=polarion:polarion@localhost:5433"
)

# Configure allowed hosts for Tomcat service
if [[ -n "$ALLOWED_HOSTS" ]]; then
    TomcatServiceRequestSafeListedHosts="TomcatService.request.safeListedHosts=$ALLOWED_HOSTS"
elif [[ "$#" -gt 0 ]]; then
    # Note: $@ access in sourced script is from the parent script arguments
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
