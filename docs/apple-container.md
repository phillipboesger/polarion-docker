# Apple `container` Workflow

This repository supports Apple `container` as a local development runtime on Apple silicon Macs running macOS 26 or later.

Use Docker for CI and Docker Compose workflows. Use Apple `container` when you want a native macOS-hosted OCI workflow and direct VS Code tasks for local start, logs, debugging, and redeploy.

## Requirements

- Apple silicon Mac
- macOS 26 or later
- Apple `container` CLI installed and working
- Polarion ZIP in `data/`

Verify the runtime is available:

```bash
container system version --format table
```

## CLI Quickstart

Start Apple `container` system services:

```bash
container system start
```

Start the builder with enough resources for Polarion:

```bash
container builder start --cpus 8 --memory 8g
```

Build the image from this repository:

```bash
container build --platform linux/amd64 -t polarion:local .
container builder stop
```

Start Polarion locally:

```bash
container run -d \
  --name polarion \
  --platform linux/amd64 \
  --rosetta \
  --cpus 8 \
  --memory 4g \
  -p 0.0.0.0:8080:80 \
  -p 0.0.0.0:5433:5433 \
  -p 0.0.0.0:5005:5005 \
  -e JAVA_OPTS="-Xmx3g -Xms3g" \
  -e JDWP_ENABLED=true \
  -v polarion_repo:/opt/polarion/data/svn \
  -v polarion_extensions:/opt/polarion/polarion/extensions \
  polarion:local
```

Open Polarion locally at `http://127.0.0.1:8080/polarion/`.

For access from another machine on the same network, use:

```bash
http://<your-mac-ip>:8080/polarion/
```

This repository's `.vscode/tasks.json` publishes on `0.0.0.0` and defaults to `POLARION_HTTP_PORT=8080`, so the expected URLs are `http://127.0.0.1:8080/polarion/` locally and `http://<your-mac-ip>:8080/polarion/` from outside.

## VS Code Tasks

The repository includes runtime tasks in [.vscode/tasks.json](../.vscode/tasks.json):

- `Polarion: System Start`
- `Polarion: Builder Start`
- `Polarion: Builder Stop`
- `Polarion: Build Image`
- `Polarion: Start`
- `Polarion: Full Start`
- `Polarion: Stop`
- `Polarion: Live Logs`
- `Polarion: Live Errors ONLY`
- `Polarion: Redeploy Workspace`
- `Polarion: Full Redeploy Workspace`
- `Polarion: Full Redeploy`
- `Polarion: Full Redeploy (Active File)`

Recommended order:

1. Run `Polarion: Full Start`.
   This uses `Polarion: Build Image`, which auto-starts and auto-stops the Apple builder.
2. Start `Debug Polarion Container` from [.vscode/launch.json](../.vscode/launch.json).
3. Use `Polarion: Full Redeploy Workspace` or `Polarion: Full Redeploy (Active File)` for plugin updates.

## Runtime Notes

- Docker Compose files in this repository are Docker-only.
- The Apple workflow uses named volumes because anonymous volumes are not automatically deleted by Apple `container` on `--rm`.
- The current documented Apple path assumes `linux/amd64` with `--rosetta`. Native `arm64` validation for Polarion is still an open item.
- The JDWP debugger attach configuration remains the same because the Apple task maps host port `5005` to container port `5005`.
- `bash scripts/polarionctl.sh build-image` starts the builder on demand with an `8g` cap and stops it again after the build.

## Logs and Redeploy

Stream Polarion application logs with:

```bash
POLARION_RUNTIME=container bash scripts/polarionctl.sh logs
```

Use Apple `container` for redeploy with:

```bash
POLARION_RUNTIME=container bash scripts/redeploy.sh path/to/plugin/file polarion custom container
```

The redeploy script copies the built JAR into the running Apple `container` instance, clears workspace cache, and restarts the Polarion service.

If the selected path does not have a `pom.xml` in its upward hierarchy, the redeploy script searches below the selected directory for plugin projects up to `POLARION_REDEPLOY_SEARCH_DEPTH` levels deep. The default is `1`, which matches a plugin workspace root such as `plugins/` that contains multiple `biz.avasis.polarion.*` module folders directly below it.

To redeploy all plugins directly below a workspace root:

```bash
POLARION_RUNTIME=container POLARION_REDEPLOY_SEARCH_DEPTH=1 bash scripts/redeploy.sh /path/to/plugins polarion custom container
```
