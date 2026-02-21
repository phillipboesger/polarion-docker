#!/bin/bash

# --- PARAMETERS ---
# $1: File or Directory path (Source context from VS Code)
# $2: Container Name (default: polarion)
# $3: Extension Name/Target Folder (default: custom)
INPUT_PATH="$1"
CONTAINER_NAME="${2:-polarion}"
EXTENSION_NAME="${3:-custom}"

# Start timer
START_TIME=$(date +%s)

# Check: Was input provided?
if [ -z "$INPUT_PATH" ]; then
    echo "❌ Error: No path provided. Please open a file in the editor."
    exit 1
fi

echo "DEBUG: Input Path received: $INPUT_PATH"

# --- INTELLIGENT PATH LOGIC ---
if [ -d "$INPUT_PATH" ]; then
    cd "$INPUT_PATH" || exit 1
elif [ -f "$INPUT_PATH" ]; then
    cd "$(dirname "$INPUT_PATH")" || exit 1
else
    echo "❌ Error: Path does not exist: $INPUT_PATH"
    exit 1
fi

# Traverse up to find pom.xml
FOUND_POM=0
for i in {1..10}; do
    if [ -f "pom.xml" ]; then
        FOUND_POM=1
        break
    fi
    if [ "$PWD" == "/" ]; then break; fi
    cd ..
done

if [ $FOUND_POM -eq 0 ]; then
    echo "❌ No pom.xml found in hierarchy (starting from $INPUT_PATH)!"
    exit 1
fi

echo "📂 Project Root detected: $PWD"

# --- CONFIGURATION ---
PLUGIN_DEST="/opt/polarion/polarion/extensions/$EXTENSION_NAME/eclipse/plugins/"
CACHE_PATH="/opt/polarion/data/workspace/.config"
METADATA_PATH="/opt/polarion/data/workspace/.metadata"

echo "🚀 [1/5] Building Extension (Skipping Tests)..."
# Use wrapper if available
if [ -f "./mvnw" ]; then
    ./mvnw clean package -Dmaven.test.skip=true
else
    mvn clean package -Dmaven.test.skip=true
fi

if [ $? -ne 0 ]; then
    echo "❌ Build failed. Aborting."
    exit 1
fi

echo "🔍 Identifying JAR..."
JAR_FILE_NAME="$(find target/*.jar -maxdepth 0 ! -name '*original-*' ! -name '*sources*' ! -name '*javadoc*' | head -n 1)"

if [ -z "$JAR_FILE_NAME" ]; then
    echo "❌ No suitable JAR found in target/!"
    exit 1
fi

echo "📂 [2/5] Ensuring directory structure inside Docker..."
docker exec "$CONTAINER_NAME" mkdir -p "$PLUGIN_DEST"

# --- SMART CLEANUP LOGIC ---
JAR_BASENAME="$(basename "$JAR_FILE_NAME")"
BUNDLE_NAME="${JAR_BASENAME%%_*}" # Extract name before version

if [ "$BUNDLE_NAME" == "$JAR_BASENAME" ]; then
    BUNDLE_NAME="$(echo "$JAR_BASENAME" | sed -E 's/-[0-9].*//')"
fi

echo "🗑️ [2.5/5] Cleaning old versions of '$BUNDLE_NAME'..."
docker exec "$CONTAINER_NAME" find "${PLUGIN_DEST}" -name "${BUNDLE_NAME}[_-]*.jar" -delete

echo "⏹️ [3/5] Stopping Polarion Service..."
docker exec "$CONTAINER_NAME" service polarion stop

echo "🧹 [4/5] Clearing Cache while service is stopped..."
docker exec "$CONTAINER_NAME" rm -rf "$CACHE_PATH" "$METADATA_PATH"

echo "📦 [5/6] Copying ${JAR_BASENAME}..."
docker cp "$JAR_FILE_NAME" "$CONTAINER_NAME:$PLUGIN_DEST"

echo "▶️ [6/6] Starting Polarion Service..."
docker exec "$CONTAINER_NAME" service polarion start

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✅ Done in ${DURATION}s."
