#!/bin/bash
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
    # 1. Zuerst alle existierenden jdwp-Zeilen entfernen, um Duplikate zu vermeiden
    sed -i '/-agentlib:jdwp/d' "$CONFIG_FILE"

    # 2. Den Agenten sauber neu einfügen
    sed -i '/export PSVN_JServer_opt="-server \\/a \  -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 \\' "$CONFIG_FILE"
    
    echo "JDWP debugging enabled on port 5005 (Duplicates cleaned)"
else
    # Falls JDWP deaktiviert ist, stellen wir sicher, dass es auch aus der Datei verschwindet
    sed -i '/-agentlib:jdwp/d' "$CONFIG_FILE"
    echo "JDWP debugging disabled"
fi
