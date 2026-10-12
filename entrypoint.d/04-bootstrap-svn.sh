#!/bin/bash

SVN_DATA_DIR="${SVN_DATA_DIR:-/opt/polarion/data/svn}"
SVN_BOOTSTRAP_DIR="${SVN_BOOTSTRAP_DIR:-/opt/polarion/bootstrap/svn}"
POLARION_PLUGINS_DIR="${POLARION_PLUGINS_DIR:-/opt/polarion/polarion/plugins}"
SVN_VERSION_MARKER="$SVN_DATA_DIR/.polarion-docker-version"
POLARION_APACHE_SVN_CONF="${POLARION_APACHE_SVN_CONF:-/etc/apache2/conf-available/polarionSVN.conf}"

# True when Polarion's own /repo block authenticates against the passwd file (2410/2506; 2512+
# use PostgreSQL). Polarion then owns that file: it holds only system secrets, user passwords
# live in passwd_credentials, and Polarion overwrites any edit to passwd.
svn_repo_uses_passwd_file() {
	sed -n '/<Location \/repo>/,/<\/Location>/p' "$POLARION_APACHE_SVN_CONF" 2>/dev/null | grep -q '^[[:space:]]*AuthUserFile'
}

# Polarion release of this image, from the platform plugin (com.polarion.platform_3.25.6 -> 2506).
polarion_image_version() {
	local dirs=("$POLARION_PLUGINS_DIR"/com.polarion.platform_3.*)
	[[ "${dirs[0]##*/}" =~ _3\.([0-9]+)\.([0-9]+) ]] || return 1
	printf '%02d%02d\n' "$((10#${BASH_REMATCH[1]}))" "$((10#${BASH_REMATCH[2]}))"
}

if [ ! -d "$SVN_DATA_DIR" ]; then
	mkdir -p "$SVN_DATA_DIR"
fi

if [ -d "$SVN_BOOTSTRAP_DIR" ]; then
	cp -an "$SVN_BOOTSTRAP_DIR"/. "$SVN_DATA_DIR"/
fi

# Keep admin/admin for /repo-local where passwd is a plain user file. Not on 2410/2506: an admin
# entry written into Polarion's passwd only works until Polarion rewrites the file, which made
# SVN access with user credentials fail intermittently (/repo-local uses passwd_credentials there).
if ! svn_repo_uses_passwd_file; then
	if [ -f "$SVN_DATA_DIR/passwd" ]; then
		htpasswd -bm "$SVN_DATA_DIR/passwd" admin admin >/dev/null
	else
		htpasswd -cbm "$SVN_DATA_DIR/passwd" admin admin >/dev/null
	fi
fi

# The SVN volume must belong to one Polarion version: record it, and say so loudly when a
# volume last used by another version is mounted (see README "Data volumes").
if image_version="$(polarion_image_version)"; then
	last_version="$(cat "$SVN_VERSION_MARKER" 2>/dev/null || true)"
	if [ -n "$last_version" ] && [ "$last_version" != "$image_version" ]; then
		echo "WARNING: this SVN volume was last used by Polarion $last_version, this container runs Polarion $image_version." >&2
		echo "WARNING: Polarion versions must not share an SVN volume: they keep SVN credentials differently and extensions are built per version." >&2
		echo "WARNING: Use one SVN/extensions volume pair per Polarion version (README: \"Data volumes\")." >&2
	fi
	echo "$image_version" > "$SVN_VERSION_MARKER"
fi

chown -R polarion:www-data "$SVN_DATA_DIR"
chmod 2775 "$SVN_DATA_DIR"
