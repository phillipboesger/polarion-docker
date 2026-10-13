#!/bin/bash

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
    # Remove stale PID file from a previous container run before starting
    rm -f /var/run/apache2/apache2.pid 2>/dev/null || true
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

# Add /repo-local for external SVN clients that log in with Polarion user credentials. /repo
# stays untouched: it is Polarion's internal endpoint and only knows the system user (passwd on
# 2410/2506, the svnauthn table on 2512+). /repo-local authenticates against the store Polarion
# keeps the real user passwords in, detected from Polarion's own /repo block:
#   2410/2506 (file auth): passwd_credentials, as in Siemens' "/repo-access" setup
#   2512+ (DB auth):       the userauthn table, over the DBD connection /repo already uses
POLARION_APACHE_SVN_CONF="${POLARION_APACHE_SVN_CONF:-/etc/apache2/conf-available/polarionSVN.conf}"
POLARION_REPO_BLOCK="$(sed -n '/<Location \/repo>/,/<\/Location>/p' "$POLARION_APACHE_SVN_CONF" 2>/dev/null)"
if grep -q '^[[:space:]]*AuthUserFile' <<<"$POLARION_REPO_BLOCK"; then
	REPO_LOCAL_AUTH='AuthBasicProvider file
AuthUserFile "/srv/polarion/svn/passwd_credentials"'
elif grep -q 'AuthDBDUserPWQuery' <<<"$POLARION_REPO_BLOCK"; then
	REPO_LOCAL_AUTH='AuthBasicProvider dbd
AuthDBDUserPWQuery "SELECT password FROM polarion_internal.userauthn WHERE username = %s"'
else
	REPO_LOCAL_AUTH='AuthBasicProvider file
AuthUserFile "/srv/polarion/svn/passwd"'
fi
cat >/etc/apache2/conf-available/polarionSVN-local.conf << EOF
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
$REPO_LOCAL_AUTH
</Location>
</IfModule>
EOF

a2enconf polarionSVN-local >/dev/null 2>&1 || true
validate_apache_config
service apache2 reload

