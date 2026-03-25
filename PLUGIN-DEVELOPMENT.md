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
- `$2` – Container name (default: `polarion`).
- `$3` – Extension name / target subfolder inside `/opt/polarion/polarion/extensions/` (e.g. `custom`).
- `$4` – Runtime (`docker` or `container`, default: `docker`).

The script traverses up from the given path until it finds a `pom.xml`, so you never need to manually point it to the project root.

Before the script stops Polarion, it runs a preflight check against the built plugin manifests. The preflight verifies that every declared `Require-Bundle` dependency is already present in the running runtime or included in the current deployment batch.

If you only want to run the preflight without deploying, set `POLARION_REDEPLOY_PREFLIGHT_ONLY=true`.

```sh
# Usage:
./scripts/redeploy.sh ../path/to/your/extension polarion <extension-name> docker

# Example with the default settings from tasks.json:
./scripts/redeploy.sh . polarion custom docker

# Preflight only, no restart and no copy:
POLARION_REDEPLOY_PREFLIGHT_ONLY=true ./scripts/redeploy.sh . polarion custom docker
```

## 3. VS Code configuration in the repository

This repository already ships preconfigured VS Code files in `.vscode/`:

| File                  | Purpose                                                     |
| :-------------------- | :---------------------------------------------------------- |
| `.vscode/tasks.json`  | Build, deploy, and log streaming tasks                      |
| `.vscode/launch.json` | Remote debug attach configuration for Polarion on port 5005 |

**Tasks available out of the box:**

- `Polarion: Full Redeploy` – builds your current plugin project (auto-detects `pom.xml`) and deploys it. The runtime is auto-detected by the scripts (prefers `docker` if available) or can be forced by setting the `POLARION_RUNTIME` environment variable to `docker` or `container`.
- `Polarion: Redeploy Preflight` – builds your current plugin project and checks manifest dependencies without stopping Polarion. The runtime is auto-detected or overridden via `POLARION_RUNTIME`.
- `Polarion: Live Logs` – streams all server logs from the active runtime (auto-detected / configurable via `POLARION_RUNTIME`).
- `Polarion: Live Errors ONLY` – streams only errors/exceptions from the logs.
- `Polarion: System Start` – starts platform/system services if required (no-op for Docker; used by Apple `container`).
- `Polarion: Builder Start` – starts the Apple `container` builder (used only for the `container` runtime).
- `Polarion: Build Image` – builds the Polarion image for the selected runtime.
- `Polarion: Start` – starts Polarion on the selected runtime.
- `Polarion: Stop` – stops and removes the running Polarion instance for the selected runtime.
- `Polarion: Full Start` – sequence: System Start → Builder Start → Build Image → Start.
- `Polarion: Redeploy Workspace` – rebuilds and deploys the repository (runtime auto-detected or set via `POLARION_RUNTIME`).
- `Polarion: Full Redeploy Workspace` – runs `Polarion: Full Start` followed by `Polarion: Redeploy Workspace`.

**Debug configuration available out of the box:**

- `Debug Polarion Container` – attaches the Java debugger to `127.0.0.1:5005`.

How to use the repo tasks:

1. Open this repository in VS Code.
2. The script is already located at `${workspaceFolder}/scripts/redeploy.sh` — no manual path setup required.
3. Open the Command Palette (Cmd+Shift+P / Ctrl+Shift+P) → **Tasks: Run Task**.
4. Select one of the tasks, e.g. `Polarion: Full Redeploy`.

> Note: The tasks in this repo are intentionally configured without user-specific paths so they work on any machine that clones this repository.

### 3.1 Apple `container` workflow in VS Code

Use this sequence when you want to run Polarion directly from VS Code with Apple `container` (preferred on Apple silicon):

1. Ensure the `container` CLI is installed and available on PATH.
2. Optionally export `POLARION_RUNTIME=container` in your shell or set it in your user tasks to force the `container` runtime.
3. Run `Polarion: System Start` once after login or reboot.
4. Run `Polarion: Builder Start` before the first build or after changing builder resources.
5. Run `Polarion: Build Image` to build the local image.
6. Run `Polarion: Start` to launch Polarion.
7. Use `Debug Polarion Container` to attach the debugger to `127.0.0.1:5005`.
8. Use `Polarion: Full Redeploy Workspace` for plugin redeploys (the redeploy task will detect the configured runtime).
9. Use `Polarion: Redeploy Preflight` when you want to catch missing bundle dependencies before a redeploy.
10. Use `Polarion: Live Logs` or `Polarion: Live Errors ONLY` for runtime inspection.

This flow assumes Apple silicon, macOS 26+, and the Apple `container` CLI installed under `/usr/local/bin/container`.

### 3.2 Optional global user tasks

If you want to have the same tasks available globally (for all workspaces) as **user tasks**, you can additionally add them to your user `tasks.json`. Steps:

1. Copy the redeployment script globally: `mkdir -p ~/scripts && cp ./scripts/redeploy.sh ~/scripts/redeploy.sh && chmod +x ~/scripts/redeploy.sh`
2. Open the Command Palette (Cmd+Shift+P / Ctrl+Shift+P).
3. Choose **Tasks: Open User Tasks**.
4. Copy the task definitions from [`.vscode/tasks.json`](.vscode/tasks.json) into your user tasks file.
5. In the `Polarion: Full Redeploy` task, change the `command` from `${workspaceFolder}/scripts/redeploy.sh` to `~/scripts/redeploy.sh`.
6. Adjust the third argument (`custom`) to match your own extension folder name.

### 3.3 Global Debugging & Settings (settings.json)

1. Open Command Palette.
2. Type **Preferences: Open User Settings (JSON)**.
3. To make the debug configuration globally available across all workspaces, copy the launch configuration from [`.vscode/launch.json`](.vscode/launch.json) and embed it under a `"launch"` key. Add `"projectName": "${fileWorkspaceFolderBasename}"` so source code resolves correctly when multiple workspaces are open.
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
3. Press Cmd+Shift+P → Run Task → **Polarion: Full Redeploy**.
4. Wait for the final `Polarion is reachable at ...` message in the terminal.

For Apple `container`, use **Polarion: Full Redeploy (Apple Container)** instead.

### 5.2 Debugging & Hot Code Replace (Logic)

Use this for logic changes inside method bodies.

1. Open the Run and Debug view (Cmd+Shift+D).
2. Select **Debug Polarion Container** (from the repo's `.vscode/launch.json`), or **Global: Attach to Polarion (5005)** if you set up the global config from section 3.2.
3. Press F5 or the green play button.

Note: Code changes within methods are hot-swapped automatically on save (Cmd+S).

### 5.3 Viewing Logs

To see server errors without leaving VS Code:

1. Press Cmd+Shift+P → Run Task.
2. Select **Polarion: Live Errors ONLY (Docker)** or **Polarion: Live Logs (Docker)** for Docker, or the matching Apple `container` task for the Apple runtime.
3. A new terminal panel will open, streaming output from the selected container runtime in real-time.
