#!/bin/bash
# Enable Apache ProxyPass for WebSockets (fix suggested by community)
echo "Configuring Apache WebSocket Proxy..."
sed -i -e '/^ProxyPass \/polarion/i ProxyPassMatch ^/(polarion/ws)$ ws://127.0.0.1:8889/$1' /etc/apache2/conf-enabled/polarion.conf

enable_apache_module_if_available() {
    local module="$1"

    if [ -f "/etc/apache2/mods-available/${module}.load" ] || [ -f "/etc/apache2/mods-available/${module}.conf" ]; then
        a2enmod "$module" >/dev/null 2>&1 || true
    fi
}

validate_apache_config() {
    echo "Validating Apache configuration..."
    if ! apache2ctl -t >/dev/null 2>&1; then
        echo "❌ Apache configuration is invalid."
        return 1
    fi
    echo "✅ Apache configuration is valid."
}

# Ensure Apache has a ServerName to avoid startup warning and start Apache
if ! grep -q "^ServerName" /etc/apache2/apache2.conf; then
    echo "ServerName localhost" >> /etc/apache2/apache2.conf
fi

echo "Enabling required Apache modules..."
enable_apache_module_if_available proxy
enable_apache_module_if_available proxy_http
enable_apache_module_if_available proxy_ajp
enable_apache_module_if_available proxy_wstunnel
enable_apache_module_if_available auth_basic
enable_apache_module_if_available authn_file
enable_apache_module_if_available dav
enable_apache_module_if_available dav_svn
enable_apache_module_if_available authz_svn

if ! validate_apache_config; then
    echo "❌ Aborting Apache start due to invalid configuration."
else
    service apache2 start
    echo "✅ Apache started successfully."
fi

# Configure redirect from / to /polarion/
if [ ! -f /etc/apache2/conf-available/polarion-redirect.conf ]; then
    cat >/etc/apache2/conf-available/polarion-redirect.conf << 'EOF'
RedirectMatch ^/$ /polarion/
EOF
    a2enconf polarion-redirect
    validate_apache_config
    service apache2 reload
fi

# Add a dedicated local SVN endpoint used by Polarion internal access.
# Keep /repo untouched (Polarion default configuration).
cat >/etc/apache2/conf-available/polarionSVN-local.conf << 'EOF'
<IfModule mod_dav_svn.c>
<Location /repo-local>
DAV svn
SVNPath "/srv/polarion/svn/repo"
SVNAutoversioning on
AuthzSVNAccessFile "/srv/polarion/svn/access"
SVNPathAuthz short_circuit
Require valid-user
AuthType Basic
AuthName "Subversion repository (local)"
AuthUserFile "/srv/polarion/svn/passwd"
AuthBasicProvider file
</Location>
</IfModule>
EOF

a2enconf polarionSVN-local >/dev/null 2>&1 || true
validate_apache_config
service apache2 reload

