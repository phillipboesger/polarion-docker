# VS Code Development Setup for Polarion

This guide describes how to configure Visual Studio Code for efficient Polarion extension development using a local container runtime. It enables **Hot Code Replacement**, **Remote Debugging**, **Live Logs**, and **One-Click Deployments** for any project in your workspace.

## 1. Prerequisites

- **Container runtime:** Either Docker or Apple `container`, with **Port 5005** exposed to the host.
  _Note:_ Ensure the container starts with JDWP enabled (e.g., `-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005`).
- **VS Code:** Installed with the **Extension Pack for Java** (Red Hat/Microsoft).
- **Maven:** Installed locally or via wrapper.
- **Scripts Folder:** A central folder for automation scripts (e.g., `~/scripts/`).

## 2. Automation Script (`scripts/redeploy.sh`)

This script handles the build process, cleans old plugin versions from the container to prevent conflicts, and deploys the new artifact to a running Polarion container.

Parameters:

- `$1` – Path to any file or folder inside your plugin project (VS Code passes `${file}` here).
- `$2` – Container name. Optional — auto-detected from the running container whose image contains "polarion" (e.g. `polarion:local` or `ghcr.io/.../polarion-docker:latest`). Override with the `POLARION_CONTAINER_NAME` environment variable or by passing it explicitly.
- `$3` – Extension name / target subfolder inside `/opt/polarion/polarion/extensions/` (e.g. `custom`). Optional — defaults to `POLARION_EXTENSION_NAME` (default: `custom`).
- `$4` – Runtime (`docker` or `container`, default: `docker`).

The script traverses up from the given path until it finds a `pom.xml`, so you never need to manually point it to the project root.

Before the script stops Polarion, it runs a preflight check against the built plugin manifests. The preflight verifies that every declared `Require-Bundle` dependency is already present in the running runtime or included in the current deployment batch.

If you only want to run the preflight without deploying, set `POLARION_REDEPLOY_PREFLIGHT_ONLY=true`.

**Container auto-detection:** The scripts automatically find the currently running Polarion container by searching for any running container whose image name contains `polarion`. This means tasks work without any manual configuration as long as the container was started from a `polarion`-named image (e.g. `polarion:local`, `polarion:2512`, or `ghcr.io/.../polarion-docker:latest`). To override, set `POLARION_CONTAINER_NAME` to a specific name.

```sh
# Usage:
./scripts/redeploy.sh ../path/to/your/extension

# With explicit container and extension name:
./scripts/redeploy.sh . polarion custom

# Preflight only, no restart and no copy:
POLARION_REDEPLOY_PREFLIGHT_ONLY=true ./scripts/redeploy.sh .
```

## 3. VS Code configuration in the repository

This repository ships preconfigured VS Code files. Open
[`polarion-docker.code-workspace`](./polarion-docker.code-workspace) in VS Code
(File > Open Workspace from File…) to load both task groups into the task picker.

| File | Purpose |
| :--- | :--- |
| `polarion-docker.code-workspace` | Container-management tasks (Build Image, Start, Stop) |
| `.vscode/tasks.json` | Polarion developer tasks (Redeploy, Logs) |
| `.vscode/launch.json` | Remote debug attach configuration for Polarion on port 5005 |

**Container tasks** (from `polarion-docker.code-workspace`):

| Task | Description |
| :--- | :--- |
| `Container: Build Image` | Build the `polarion:local` image from the Dockerfile |
| `Container: Start` | Start the container and wait for the HTTP endpoint |
| `Container: Stop` | Stop and remove the container (volumes are preserved) |
| `Container: System Start` | *(macOS only)* Start Apple container system services |
| `Container: Builder Start` | *(macOS only)* Start the Apple container builder |
| `Container: Builder Stop` | *(macOS only)* Stop the Apple container builder |

**Polarion developer tasks** (from `.vscode/tasks.json`):

| Task | Description |
| :--- | :--- |
| `Polarion: Logs` | Stream the Polarion application log live |
| `Polarion: Redeploy Single` | Build the active file's plugin (auto-detects `pom.xml`) and hot-deploy it into the running container |
| `Polarion: Redeploy All` | Build and deploy all workspace plugins |
| `Polarion: Error Logs` | *(optional)* Stream only ERROR / Exception lines |
| `Polarion: Redeploy Preflight` | *(optional)* Validate bundle dependencies without stopping Polarion or deploying |

The runtime is auto-detected by the scripts (prefers `docker` if available) or can be forced with `POLARION_RUNTIME=docker` or `POLARION_RUNTIME=container`. The container name is auto-detected from the running container whose image name contains `polarion` — no configuration needed. Set `POLARION_CONTAINER_NAME` to override.

**Debug configuration:**

- `Debug Polarion Container` – attaches the Java debugger to `127.0.0.1:5005`.

How to use the repo tasks:

1. Open `polarion-docker.code-workspace` in VS Code.
2. The scripts are already at `${workspaceFolder}/scripts/` — no manual path setup required.
3. Open the Command Palette (Cmd+Shift+P / Ctrl+Shift+P) → **Tasks: Run Task**.
4. Select a task, e.g. `Polarion: Redeploy Single`.

> Note: Tasks are intentionally configured without user-specific paths so they work on any machine that clones this repository.

### 3.1 Apple `container` workflow in VS Code

Use this sequence when running Polarion with Apple `container` (preferred on Apple silicon):

1. Ensure the `container` CLI is installed and available on PATH.
2. Optionally export `POLARION_RUNTIME=container` in your shell to force the `container` runtime.
3. Run `Container: System Start` once after login or reboot.
4. Run `Container: Builder Start` before the first build or after changing builder resources.
5. Run `Container: Build Image` to build the local image.
6. Run `Container: Start` to launch Polarion.
7. Use `Debug Polarion Container` to attach the debugger to `127.0.0.1:5005`.
8. Use `Polarion: Redeploy All` or `Polarion: Redeploy Single` for plugin updates.
9. Use `Polarion: Redeploy Preflight` to catch missing bundle dependencies before a redeploy.
10. Use `Polarion: Logs` or `Polarion: Error Logs` for runtime inspection.

This flow assumes Apple silicon, macOS 26+, and the Apple `container` CLI installed under `/usr/local/bin/container`.

### 3.2 Optional global user tasks

If you want to have the same tasks available globally (for all workspaces) as **user tasks**, you can additionally add them to your user `tasks.json`. Steps:

1. Copy the redeployment script to a stable location on your machine:

   **macOS / Linux:**
```bash
   mkdir -p ~/scripts && cp ./scripts/redeploy.sh ~/scripts/redeploy.sh && chmod +x ~/scripts/redeploy.sh
```

   **Windows (PowerShell — requires Git Bash on PATH):**
```powershell
   New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\scripts"
   Copy-Item .\scripts\redeploy.sh "$env:USERPROFILE\scripts\redeploy.sh"
```
   > **Windows prerequisite:** The tasks call bash scripts. You need **Git for Windows** (Git Bash) or **WSL2** with bash available on `PATH`. Verify with `bash --version` in PowerShell before continuing.
2. Open the Command Palette (Cmd+Shift+P / Ctrl+Shift+P).
3. Choose **Tasks: Open User Tasks**.
4. Copy the task definitions from [`.vscode/tasks.json`](.vscode/tasks.json) and the container tasks from [`polarion-docker.code-workspace`](./polarion-docker.code-workspace) into your user tasks file.
5. In the `Polarion: Redeploy Single` task, change the `command` to the absolute path where you placed the script:

   **macOS / Linux:** `~/scripts/redeploy.sh`
   **Windows:** `C:/Users/YourName/scripts/redeploy.sh`
   *(use forward slashes — Windows backslashes break bash path resolution)*

   Also set `"cwd"` in the task options so relative paths inside the script resolve correctly:
```jsonc
   "options": {
     "cwd": "C:/Dev/polarion-docker"
   }
```
6. If your extension folder is not named `custom`, override it by setting `POLARION_EXTENSION_NAME` in the task's `env` options instead of adjusting an argument.

### 3.3 Global Debugging & Settings (settings.json)

1. Open Command Palette.
2. Type **Preferences: Open User Settings (JSON)**.
3. To make the debug configuration globally available across all workspaces, copy the launch configuration from [`.vscode/launch.json`](.vscode/launch.json) and embed it under a `"launch"` key. Add `"projectName": "${fileWorkspaceFolderBasename}"` so source code resolves correctly when multiple workspaces are open. 
> **Windows edge case:** `${fileWorkspaceFolderBasename}` resolves correctly in `settings.json` when using a `.code-workspace` file. Without one — i.e., in a plain folder-open — VS Code may not substitute the variable and the debugger attaches but breakpoints never fire. Fix: move the launch configuration to the project's own `.vscode/launch.json` instead (identical content, without the `"launch"` wrapper key).
4. Additionally add the following settings for performance and Hot Code Replace:

```json
{
  // ... existing settings ...

  // Java Performance Tuning for Large Projects
  "java.jdt.ls.vmargs": "-XX:+UseParallelGC -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Dsun.zip.disableMemoryMapping=true -Xmx4G -Xms100m -Xlog:disable",

  // Enable Hot Code Replace (HCR)
  "java.debug.settings.hotCodeReplace": "auto",
  "java.autobuild.enabled": true
}
```

## 4. Docker Compose for Local Builds

If you are building the image yourself (e.g. during development), use `docker-compose.dev.yml` instead of the default compose file:

```sh
# Build and start with local image
docker-compose -f docker-compose.dev.yml up -d --build
```

The dev compose file builds from the local `Dockerfile` and uses a separate `polarion_network`. All ports (80, 5005, 5433) and the `JDWP_ENABLED=true` flag are pre-configured.

For production / pre-built images, continue to use the default `docker-compose.yml`.

Apple `container` does not use Docker Compose. Use the Apple `container` tasks from section 3.1 instead.

## 5. Developer Workflow

### 5.1 Deploying Changes (Structural)

Use this when you add classes, change plugin.xml, or add dependencies.

1. Open a file in the project you want to deploy (e.g., MyClass.java).
2. Ensure the cursor is active in the editor (so `${file}` resolves to a path inside your plugin project).
3. Press Cmd+Shift+P → Run Task → **Polarion: Redeploy Single**.
4. Wait for the final `Polarion is reachable at ...` message in the terminal.

The task works the same for both Docker and Apple `container` — the runtime is auto-detected.

### 5.2 Debugging & Hot Code Replace (Logic)

Use this for logic changes inside method bodies.

1. Open the Run and Debug view (Cmd+Shift+D).
2. Select **Debug Polarion Container** (from the repo's `.vscode/launch.json`), or **Global: Attach to Polarion (5005)** if you set up the global config from section 3.2.
3. Press F5 or the green play button.

Note: Code changes within methods are hot-swapped automatically on save (Cmd+S).

### 5.3 Viewing Logs

To see server errors without leaving VS Code:

1. Press Cmd+Shift+P → Run Task.
2. Select **Polarion: Logs** for the full log stream, or **Polarion: Error Logs** to see only errors and exceptions.
3. A new terminal panel will open, streaming output from the running container in real-time.
