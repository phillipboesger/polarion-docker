# VS Code Development Setup for Polarion (Docker)

This guide describes how to configure Visual Studio Code for efficient Polarion extension development using a local Docker container. It enables **Hot Code Replacement**, **Remote Debugging**, **Live Logs**, and **One-Click Deployments** for any project in your workspace.

## 1. Prerequisites

- **Docker:** A running Polarion container with **Port 5005** exposed.  
  *Note:* Ensure the container starts with JDWP enabled (e.g., `-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005`).
- **VS Code:** Installed with the **Extension Pack for Java** (Red Hat/Microsoft).
- **Maven:** Installed locally or via wrapper.
- **Scripts Folder:** A central folder for automation scripts (e.g., `~/scripts/`).

## 2. Automation Script (`redeploy.sh`)

This script handles the build process, cleans old plugin versions from the container to prevent conflicts, and deploys the new artifact.

1. Create the file `~/scripts/redeploy.sh`.
2. Paste the content below.
3. Make it executable: `chmod +x ~/scripts/redeploy.sh`.

```bash
#!/bin/bash

# --- PARAMETERS ---
# $1: File or Directory path (Source context from VS Code)
# $2: Container Name (default: polarion)
# $3: Extension Name/Target Folder (default: boesger)
INPUT_PATH="$1"         
CONTAINER_NAME="$2"
EXTENSION_NAME="$3"

# Start timer
START_TIME=$(date +%s)

# Set defaults
: "${CONTAINER_NAME:=polarion}"
: "${EXTENSION_NAME:=boesger}"

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

PROJECT_ROOT="$PWD"
echo "📂 Project Root detected: $PROJECT_ROOT"

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
JAR_FILE_NAME=$(ls target/*.jar | grep -v 'original-' | grep -v 'sources' | grep -v 'javadoc' | head -n 1)

if [ -z "$JAR_FILE_NAME" ]; then
    echo "❌ No suitable JAR found in target/!"
    exit 1
fi

echo "📂 [2/5] Ensuring directory structure inside Docker..."
docker exec "$CONTAINER_NAME" mkdir -p "$PLUGIN_DEST"

# --- SMART CLEANUP LOGIC ---
JAR_BASENAME=$(basename "$JAR_FILE_NAME")
BUNDLE_NAME="${JAR_BASENAME%%_*}" # Extract name before version

if [ "$BUNDLE_NAME" == "$JAR_BASENAME" ]; then
    BUNDLE_NAME=$(echo "$JAR_BASENAME" | sed -E 's/-[0-9].*//')
fi

echo "🗑️ [2.5/5] Cleaning old versions of '$BUNDLE_NAME'..."
docker exec "$CONTAINER_NAME" sh -c "rm -f ${PLUGIN_DEST}${BUNDLE_NAME}_*.jar ${PLUGIN_DEST}${BUNDLE_NAME}-*.jar"

echo "⏹️ [3/5] Stopping Polarion Service..."
docker exec "$CONTAINER_NAME" service polarion stop

echo "🧹 [4/5] Clearing Cache while service is stopped..."
docker exec "$CONTAINER_NAME" rm -rf "$CACHE_PATH"
docker exec "$CONTAINER_NAME" rm -rf "$METADATA_PATH"

echo "📦 [5/6] Copying $(basename "$JAR_FILE_NAME")..."
docker cp "$JAR_FILE_NAME" "$CONTAINER_NAME:$PLUGIN_DEST"

echo "▶️ [6/6] Starting Polarion Service..."
docker exec "$CONTAINER_NAME" service polarion start

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo "✅ Done in ${DURATION}s."
```

3. Global VS Code Configuration

To enable these features across all your Polarion projects without per-project configuration, we use global User Settings.

3.1 Global Tasks (tasks.json)
	1.	Open Command Palette (Cmd+Shift+P / Ctrl+Shift+P).
	2.	Type “Tasks: Open User Tasks”.
	3.	Add the following tasks configuration.
Important: Update the command path to match your script location.

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Polarion: Redeploy Active File",
            "type": "shell",
            "command": "~/scripts/redeploy.sh",
            "args": [
                "${file}",
                "polarion",
                "boesger"
            ],
            "presentation": {
                "reveal": "always",
                "panel": "shared",
                "clear": true
            },
            "problemMatcher": []
        },
        {
            "label": "Polarion: Live Logs (Errors Only)",
            "type": "process",
            "command": "docker",
            "args": [
                "exec", "-i", "polarion", "sh", "-c",
                "tail -f $(ls -t /opt/polarion/data/logs/main/*.log | head -n 1) | grep --line-buffered -E 'ERROR|Exception|Caused by'"
            ],
            "presentation": {
                "echo": false,
                "reveal": "always",
                "focus": false,
                "panel": "new",
                "group": "polarion-logs"
            },
            "isBackground": true,
            "problemMatcher": []
        },
        {
            "label": "Polarion: Live Logs (All)",
            "type": "process",
            "command": "docker",
            "args": [
                "exec", "-i", "polarion", "sh", "-c",
                "tail -f $(ls -t /opt/polarion/data/logs/main/*.log | head -n 1)"
            ],
            "presentation": {
                "echo": false,
                "reveal": "always",
                "focus": false,
                "panel": "new",
                "group": "polarion-logs"
            },
            "isBackground": true,
            "problemMatcher": []
        }
    ]
}
```

3.2 Global Debugging & Settings (settings.json)
	1.	Open Command Palette.
	2.	Type “Preferences: Open User Settings (JSON)”.
	3.	Add the following configuration to enable One-Click Debugging and performance tuning.

```json
{
    // ... existing settings ...

    // 1. Global Launch Configuration for Remote Debugging
    "launch": {
        "version": "0.2.0",
        "configurations": [
            {
                "type": "java",
                "name": "Global: Attach to Polarion (5005)",
                "request": "attach",
                "hostName": "127.0.0.1",
                "port": 5005,
                // Automatically resolves source code from open workspace folders
                "projectName": "${fileWorkspaceFolderBasename}"
            }
        ]
    },

    // 2. Java Performance Tuning for Large Projects
    "java.jdt.ls.vmargs": "-XX:+UseParallelGC -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Dsun.zip.disableMemoryMapping=true -Xmx4G -Xms100m -Xlog:disable",

    // 3. Enable Hot Code Replace (HCR)
    "java.debug.settings.hotCodeReplace": "auto",
    "java.autobuild.enabled": true
}
```

4. Developer Workflow

A. Deploying Changes (Structural)

Use this when you add classes, change plugin.xml, or add dependencies.
	1.	Open a file in the project you want to deploy (e.g., MyClass.java).
	2.	Ensure the cursor is active in the editor.
	3.	Press Cmd+Shift+P -> Run Task -> Polarion: Redeploy Active File.
	4.	Wait for the “✅ Done” message in the terminal.

B. Debugging & Hot Code Replace (Logic)

Use this for logic changes inside method bodies.
	1.	Open the Run and Debug view (Cmd+Shift+D).
	2.	Select Global: Attach to Polarion (5005).
	3.	Press F5 or the green play button.
Note: Code changes within methods are hot-swapped automatically on save (Cmd+S).

C. Viewing Logs

To see server errors without leaving VS Code:
	1.	Press Cmd+Shift+P -> Run Task.
	2.	Select Polarion: Live Logs (Errors Only).
	3.	A new terminal panel will open, streaming exceptions from the Docker container in real-time.

