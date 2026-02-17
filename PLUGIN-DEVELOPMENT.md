# VS Code Development Setup for Polarion (Docker)

This guide describes how to configure Visual Studio Code for efficient Polarion extension development using a local Docker container. It enables **Hot Code Replacement**, **Remote Debugging**, **Live Logs**, and **One-Click Deployments** for any project in your workspace.

## 1. Prerequisites

- **Docker:** A running Polarion container with **Port 5005** exposed.  
  _Note:_ Ensure the container starts with JDWP enabled (e.g., `-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005`).
- **VS Code:** Installed with the **Extension Pack for Java** (Red Hat/Microsoft).
- **Maven:** Installed locally or via wrapper.
- **Scripts Folder:** A central folder for automation scripts (e.g., `~/scripts/`).

## 2. Automation Script (`scripts/redeploy.sh`)

This script handles the build process, cleans old plugin versions from the container to prevent conflicts, and deploys the new artifact to a running Polarion container.

To use it, call it with the path to your plugin's project, the name of your Polarion container, and the name of your extension:

```sh
./scripts/redeploy.sh ../path/to/your/extension polarion extname
```

## 3. VS Code configuration in the repository

This repository already provides preconfigured tasks in `.vscode/tasks.json` that you can use out of the box:

- `Polarion: Full Redeploy` – builds your current plugin project and deploys it into the container.
- `Polarion: Live Logs (Docker)` – streams all server logs from the Polarion container.
- `Polarion: Live Errors ONLY (Docker)` – streams only errors/exceptions from the logs.

How to use the repo tasks:

1. Open this repository in VS Code.
2. Make sure `redeploy.sh` is located relative to your workspace as expected by `.vscode/tasks.json` (default: `${workspaceFolder}/../redeploy.sh`).
3. Open the Command Palette (Cmd+Shift+P / Ctrl+Shift+P) → **Tasks: Run Task**.
4. Select one of the tasks, e.g. `Polarion: Full Redeploy`.

> Note: The tasks in this repo are intentionally configured without user-specific paths so they work on any machine that uses the same repository.

### 3.1 Optional global user tasks

If you want to have the same tasks available globally (for all workspaces) as **user tasks**, you can additionally add them to your user `tasks.json`. Steps:

1. Copy the redeployment script globally: `mkdir -p ~/scripts && cp ./scripts/redeploy.sh ~/scripts/redeploy.sh && chmod +x ~/scripts/redeploy.sh`
2. Open the Command Palette (Cmd+Shift+P / Ctrl+Shift+P).
3. Choose **Tasks: Open User Tasks**.
4. Add (or create) the following configuration and only adjust the paths to match your environment:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Polarion: Full Redeploy",
      "type": "shell",
      "command": "~/scripts/redeploy.sh",
      "args": ["${file}", "polarion", "boesger"],
      "presentation": {
        "reveal": "always",
        "panel": "shared"
      },
      "problemMatcher": []
    },
    {
      "label": "Polarion: Live Logs (Docker)",
      "type": "process",
      "command": "docker",
      "args": [
        "exec",
        "-i",
        "polarion",
        "sh",
        "-c",
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
    },
    {
      "label": "Polarion: Live Errors ONLY (Docker)",
      "type": "process",
      "command": "docker",
      "args": [
        "exec",
        "-i",
        "polarion",
        "sh",
        "-c",
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
    }
  ]
}
```

### 3.2 Global Debugging & Settings (settings.json)

1. Open Command Palette.
2. Type “Preferences: Open User Settings (JSON)”.
3. Add the following configuration to enable One-Click Debugging and performance tuning.

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

## 4. Developer Workflow

### 4.1 Deploying Changes (Structural)

Use this when you add classes, change plugin.xml, or add dependencies.

1. Open a file in the project you want to deploy (e.g., MyClass.java).
2. Ensure the cursor is active in the editor.
3. Press Cmd+Shift+P -> Run Task -> Polarion: Redeploy Active File.
4. Wait for the “✅ Done” message in the terminal.

### 4.2 Debugging & Hot Code Replace (Logic)

Use this for logic changes inside method bodies.

1. Open the Run and Debug view (Cmd+Shift+D).
2. Select Global: Attach to Polarion (5005).
3. Press F5 or the green play button.

Note: Code changes within methods are hot-swapped automatically on save (Cmd+S).

### 4.3 Viewing Logs

To see server errors without leaving VS Code:

1. Press Cmd+Shift+P -> Run Task.
2. Select Polarion: Live Logs (Errors Only).
3. A new terminal panel will open, streaming exceptions from the Docker container in real-time.
