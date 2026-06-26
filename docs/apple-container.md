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

When several `polarion*.zip` files coexist in `data/`, select one and tag the image per version with a build arg (passing both tags so `polarion:local` keeps pointing at the latest build):

```bash
container build --platform linux/amd64 \
  --build-arg POLARION_ZIP=PolarionALM_2512.zip \
  -t polarion:2512 -t polarion:local .
```

The helper does this for you — it derives the version tag from the ZIP name and applies both `polarion:2512` and `polarion:local` in one build:

```bash
POLARION_RUNTIME=container bash scripts/polarionctl.sh list-zips
POLARION_RUNTIME=container POLARION_ZIP=PolarionALM_2512.zip bash scripts/polarionctl.sh build-image
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

When several Polarion images exist locally, list them and pick which one to start:

```bash
POLARION_RUNTIME=container bash scripts/polarionctl.sh list-images
POLARION_RUNTIME=container POLARION_IMAGE=polarion:2512 bash scripts/polarionctl.sh start
```

Open Polarion locally at `http://127.0.0.1:8080/polarion/`.

For access from another machine on the same network, use:

```bash
http://<your-mac-ip>:8080/polarion/
```

This repository's `.vscode/tasks.json` publishes on `0.0.0.0` and defaults to `POLARION_HTTP_PORT=8080`, so the expected URLs are `http://127.0.0.1:8080/polarion/` locally and `http://<your-mac-ip>:8080/polarion/` from outside.

## VS Code Tasks

Open [`polarion-docker.code-workspace`](../polarion-docker.code-workspace) in VS Code
(File > Open Workspace from File…) to get both task groups merged in the task picker.

**Container tasks** (defined in `polarion-docker.code-workspace`):

| Task | Description |
| :--- | :--- |
| `Container: Build Image` | Build the image from the Dockerfile; prompts for the ZIP in `data/` when several exist and tags per version (alias `polarion:local`) |
| `Container: Start` | Start the Polarion container and wait for the HTTP endpoint; prompts for the image when several Polarion images exist |
| `Container: Stop` | Stop and remove the container (volumes are preserved) |
| `Container: System Start` | *(macOS only)* Start Apple container system services |
| `Container: Builder Start` | *(macOS only)* Start the Apple container builder |
| `Container: Builder Stop` | *(macOS only)* Stop the Apple container builder |

**Polarion developer tasks** (defined in `.vscode/tasks.json`):

| Task | Description |
| :--- | :--- |
| `Polarion: Logs` | Stream the Polarion application log live |
| `Polarion: Redeploy Single` | Build the active file's plugin and hot-deploy it |
| `Polarion: Redeploy All` | Build and deploy all workspace plugins |
| `Polarion: Error Logs` | *(optional)* Stream only ERROR / Exception lines |
| `Polarion: Redeploy Preflight` | *(optional)* Validate bundle dependencies without deploying |

Recommended order for Apple `container`:

1. Run `Container: System Start` once after login or reboot.
2. Run `Container: Builder Start` before the first image build.
3. Run `Container: Build Image` to build the local image. The builder starts on demand and stops automatically.
4. Run `Container: Start` to launch Polarion.
5. Start `Debug Polarion Container` from [.vscode/launch.json](../.vscode/launch.json).
6. Use `Polarion: Redeploy Single` (active file) or `Polarion: Redeploy All` (workspace) for plugin updates.

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
