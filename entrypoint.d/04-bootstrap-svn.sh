#!/bin/bash

SVN_DATA_DIR="/opt/polarion/data/svn"
SVN_BOOTSTRAP_DIR="/opt/polarion/bootstrap/svn"

if [ ! -d "$SVN_DATA_DIR" ]; then
	mkdir -p "$SVN_DATA_DIR"
fi

if [ -d "$SVN_BOOTSTRAP_DIR" ]; then
	cp -an "$SVN_BOOTSTRAP_DIR"/. "$SVN_DATA_DIR"/
fi

chown -R polarion:www-data "$SVN_DATA_DIR"
chmod 2775 "$SVN_DATA_DIR"
