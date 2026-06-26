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
    "com.siemens.polarion.platform.locationIndex.enabled=true"
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

# The built-in Mailpit catcher (entrypoint.d/60-mailpit.sh) runs by default, so unless
# it is disabled (MAILPIT_EMBEDDED=false) or Polarion is pointed at a real mail server
# (SMTP_HOST), wire notifications to the in-container catcher at 127.0.0.1:25. An explicit
# external SMTP_HOST always takes precedence.
if [[ "${MAILPIT_EMBEDDED:-}" != "false" && -z "${SMTP_HOST:-}" ]]; then
    SMTP_HOST="127.0.0.1"
    SMTP_PORT="${SMTP_PORT:-25}"
fi

# Configure outgoing SMTP for mail notifications. Routes Polarion's notification mail to
# the resolved SMTP host — the built-in catcher by default, or a real server via SMTP_HOST.
# Skipped only when the catcher is disabled (MAILPIT_EMBEDDED=false) and no SMTP_HOST is set.
if [[ -n "${SMTP_HOST:-}" ]]; then
    echo "Configuring SMTP notifications via $SMTP_HOST:${SMTP_PORT:-25}"
    PARAMS+=(
        "com.polarion.platform.persistence.notifications.disabled=false"
        "announcer.smtp.host=$SMTP_HOST"
        "announcer.smtp.port=${SMTP_PORT:-25}"
        "announcer.smtp.auth=false"
    )
fi

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
