#!/bin/bash
# Enable Apache ProxyPass for WebSockets (fix suggested by community)
echo "Configuring Apache WebSocket Proxy..."
sed -i -e '/^ProxyPass \/polarion/i ProxyPassMatch ^/(polarion/ws)$ ws://127.0.0.1:8889/$1' /etc/apache2/conf-enabled/polarion.conf

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
