# VS Code Development Setup for Polarion

This guide describes how to configure Visual Studio Code for efficient Polarion extension development using a local container runtime. It enables **Hot Code Replacement**, **Remote Debugging**, **Live Logs**, and **One-Click Deployments** for any project in your workspace.

## 1. Prerequisites

- **Container runtime:** Either Docker or Apple `container`, with **Port 5005** exposed to the host.
  _Note:_ Ensure the container starts with JDWP enabled (e.g., `-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005`).
- **VS Code:** Installed with the **Extension Pack for Java** (Red Hat/Microsoft).
- **Maven:** Installed locally or via wrapper.
- **Scripts Folder:** A central folder for automation scripts (e.g., `~/scripts/`).
- **Optional — multiple plugin projects open at once:** the [`rioj7.command-variable`](https://marketplace.visualstudio.com/items?itemName=rioj7.command-variable) extension, needed for the "pick project" debug configuration described in [3.4](#34-debugging-with-multiple-plugin-projects-open). Not required if you only ever have a single Java project open per workspace.

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

**Container auto-detection:** The scripts automatically find the currently running Polarion container by searching for any running container whose image name contains `polarion`. This means tasks work without any manual configuration as long as the container was started from a `polarion`-named image (e.g. `polarion:local`, `polarion:2512`, or `ghcr.io/.../polarion-docker:latest`). If multiple matching containers are running, the first one found is used. To always target a specific container, set `POLARION_CONTAINER_NAME` to override auto-detection.

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

- `Debug Polarion Container` – attaches the Java debugger to `127.0.0.1:5005`. Works when exactly one Java/Maven project is open in the workspace.
- `Debug Polarion Container (pick project)` – same attach target, but prompts for which open plugin project to resolve breakpoints/watches against. Use this when several plugin repos are open at once; see [3.4](#34-debugging-with-multiple-plugin-projects-open).

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
> **More than one plugin project open at once:** `${fileWorkspaceFolderBasename}` only resolves to *a* project — it doesn't let you choose one interactively, and it breaks down once several plugin repos share one multi-root workspace. For that case, replace the static `"projectName"` value with the picker-based `${input:targetProject}` config from [3.4](#34-debugging-with-multiple-plugin-projects-open) instead (works with or without a `.code-workspace` file).
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

### 3.4 Debugging with Multiple Plugin Projects Open

**Problem:** with more than one Java/Maven plugin project open in the same VS Code workspace (e.g. a multi-root workspace, or several plugin repos opened side by side), attaching to the shared JDWP port 5005 and then setting a Watch or Evaluate expression fails with:

```
IllegalStateException: Cannot evaluate, please specify projectName
```

or, once a `"projectName"` is set to the wrong value:

```
Project <name> cannot be found
```

`projectName` becomes mandatory for Watches/Evaluate as soon as more than one Java project is open, but it is a single, fixed-value field — VS Code's Java debugger has no wildcard or "any project" option (tracked upstream as [microsoft/vscode-java-debug#1197](https://github.com/microsoft/vscode-java-debug/issues/1197), open for years with no native fix).

> **Note:** JDWP over `dt_socket` only accepts one active debugger connection per port. This does **not** let you debug several projects at the same time — there is still exactly one attach session. The picker below only controls which project's source/classpath that one session resolves breakpoints, Watches, and Evaluate expressions against; switching projects means stopping the session and reattaching with a new pick.

**Setup — `rioj7.command-variable` extension:**

1. Install [`rioj7.command-variable`](https://marketplace.visualstudio.com/items?itemName=rioj7.command-variable) from the Extensions view (this repo's [`.vscode/extensions.json`](.vscode/extensions.json) already recommends it).
2. If you're on Remote-SSH or a Dev Container, install it a second time **in the remote context** — it's a workspace-kind extension, so the local install alone isn't enough. Use **Install in SSH: `<host>`** (or the equivalent Dev Containers action) from the Extensions view.
3. Reload once after installing: **Developer: Reload Window** — otherwise its commands aren't registered yet and the picker step in launch.json silently fails to resolve.

**Usage:**

- Local repo config: select **Debug Polarion Container (pick project)** from [`.vscode/launch.json`](.vscode/launch.json) in the Run and Debug view.
- Global config (section 3.3): replace the static `"projectName": "${fileWorkspaceFolderBasename}"` with the same `"projectName": "${input:targetProject}"` + `inputs` block from this repo's `.vscode/launch.json`.

Either way, starting the session opens a Quick Pick listing every `pom.xml` found in the open workspace (folders named `target` excluded), labeled by its containing folder name. The selection determines which project Watches/Evaluate resolve against for that session.

> **Known limitation:** the picker's regex assumes the registered JDT/Eclipse project name matches the pom's containing folder name exactly — that's the common case for Maven-imported projects, but not guaranteed (e.g. a project renamed on import, or a `<name>` override). Verify the actual name in the **JAVA PROJECTS** view in the Explorer sidebar. If a project's JDT name differs from its folder name, evaluation still fails with `Project ... cannot be found`; either adjust the `valueTransform` regex in `.vscode/launch.json` to match, or see the artifactId-based variant below.

**Advanced (optional): resolve the actual Maven `artifactId` instead of the folder name**

The default picker above uses the pom's *folder name* as a stand-in for the project name — simple and reliable, but a mismatch is possible (see limitation above). `rioj7.command-variable` can instead read the selected pom.xml's content and extract its own `<artifactId>` via a two-step regex (first strip any `<parent>...</parent>` block, so the parent's `artifactId` isn't picked up by mistake, then extract the first remaining `<artifactId>`):

```json
{
  "id": "targetProject",
  "type": "command",
  "command": "extension.commandvariable.transform",
  "args": {
    "text": "${fileContent:pomContent}",
    "fileContent": {
      "pomContent": { "fileName": "${pickFile:pomFile}" }
    },
    "pickFile": {
      "pomFile": {
        "include": "**/pom.xml",
        "exclude": "**/target/**",
        "fromWorkspace": true,
        "display": "relativePath"
      }
    },
    "apply": [
      { "find": "<parent>[\\s\\S]*?<\\/parent>", "replace": "" },
      { "find": "[\\s\\S]*?<artifactId>([^<]+)<\\/artifactId>", "replace": "$1" }
    ]
  }
}
```

This is not wired up as the repo default because it hasn't been verified end-to-end against a live multi-module workspace — treat it as a starting point, not a drop-in fix, and confirm the resolved value against the JAVA PROJECTS view before relying on it.

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
2. Select **Debug Polarion Container** (from the repo's `.vscode/launch.json`), or **Global: Attach to Polarion (5005)** if you set up the global config from section 3.2. If several plugin projects are open at once, use **Debug Polarion Container (pick project)** instead — see [3.4](#34-debugging-with-multiple-plugin-projects-open).
3. Press F5 or the green play button. With the "pick project" config, choose the project from the Quick Pick that appears.

Note: Code changes within methods are hot-swapped automatically on save (Cmd+S).

### 5.3 Viewing Logs

To see server errors without leaving VS Code:

1. Press Cmd+Shift+P → Run Task.
2. Select **Polarion: Logs** for the full log stream, or **Polarion: Error Logs** to see only errors and exceptions.
3. A new terminal panel will open, streaming output from the running container in real-time.
