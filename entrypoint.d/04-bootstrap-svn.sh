#!/bin/bash

SVN_DATA_DIR="${SVN_DATA_DIR:-/opt/polarion/data/svn}"
SVN_BOOTSTRAP_DIR="${SVN_BOOTSTRAP_DIR:-/opt/polarion/bootstrap/svn}"
POLARION_PLUGINS_DIR="${POLARION_PLUGINS_DIR:-/opt/polarion/polarion/plugins}"
SVN_VERSION_MARKER="$SVN_DATA_DIR/.polarion-docker-version"
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

# passwd belongs to Polarion (system secrets on 2410/2506, unused for /repo on 2512+): never edit
# it here. /repo-local authenticates against Polarion's real user store instead (05).

# Record which Polarion version last used this SVN volume and note a version switch in the log,
# which helps when diagnosing a volume shared between versions (see README "Data volumes").
if image_version="$(polarion_image_version)"; then
	last_version="$(cat "$SVN_VERSION_MARKER" 2>/dev/null || true)"
	if [ -n "$last_version" ] && [ "$last_version" != "$image_version" ]; then
		echo "NOTE: this SVN volume was last used by Polarion $last_version, this container runs Polarion $image_version (README: \"Data volumes\")."
	fi
	echo "$image_version" > "$SVN_VERSION_MARKER"
fi

chown -R polarion:www-data "$SVN_DATA_DIR"
chmod 2775 "$SVN_DATA_DIR"
