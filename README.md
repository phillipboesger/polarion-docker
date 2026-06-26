# Polarion Docker

Run Polarion ALM in OCI-compatible containers on macOS, Windows, and Linux. This repository provides a flexible Dockerfile and setup scripts to easily containerize a fresh Polarion installation.

## 🌟 Features

The Docker image and its entrypoint scripts (`polarion_starter.sh` & `entrypoint.d/`) automatically handle many complex configurations that are usually manual:

- **Modular Entrypoint System**: Startup logic is split into lightweight scripts in `/opt/polarion/entrypoint.d/` for easy extensibility.
- **WebSocket Support**: Automatically configures Apache `ProxyPassMatch` to enable Polarion LiveDoc collaboration and other real-time features.
- **SVN HTTP Aliases**: Exposes the bundled Subversion repository externally under both `/repo` and `/repo-local`.
- **PostgreSQL Auto-Config**: Sets up `listen_addresses` and `pg_hba.conf` to allow external connections (essential for container networking).
- **URL Correction**: Automatically fixes `localhost` references in configuration files to `127.0.0.1` for proper container behavior.
- **Remote Debugging (JDWP)**: One-click remote debugging support on port 5005.
- **Memory Management**: Easy configuration of JVM memory via `JAVA_OPTS`.

## 🚀 Getting Started

### Runtime Support

| Runtime           | Status                       | Notes                                                                                                                               |
| :---------------- | :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------------- |
| Docker            | Primary                      | Supported for local development, Docker Compose, and CI publishing workflows.                                                       |
| Podman            | Secondary                    | Supported for local builds.                                                                                                         |
| Apple `container` | Local Apple silicon workflow | Supported for local macOS 26+ development through CLI commands and VS Code tasks. Docker Compose is not available for this runtime. |

There are two ways to use this image: building it yourself (recommended for most users) or requesting access to pre-built images.

### Option A: Local Build (Recommended)

Since Polarion requires a license and the installation media is proprietary, you can build this Docker image locally using your own Polarion ZIP file.

1.  **Download** the Polarion for Linux ZIP distribution (e.g., `Polarion-2512.zip`) from Siemens.
2.  **Place** the downloaded ZIP file in the `data` directory of this repository.
    - _Note: The build script automatically picks up any file matching `polarion_.zip`.\*
    - _Note: On Linux systems with SELinux enabled, set the context on `data` with `chcon -Rt 'container_file_t' data/`._
3.  **Place** your license files in the repo:
    - Put the Polarion core XML license in `files/` as `polarion.lic`. The start scripts sync XML `polarion.lic` files from `files/` into `/opt/polarion/polarion/license/polarion.lic`.
    - Put the avasis extension license in `data/` as `avasis.licence`. The start scripts sync it into `/opt/polarion/polarion/license/avasis.licence`.
4.  **Build** the Docker image:
    ```bash
    # With Docker
    docker build --platform linux/amd64 -t polarion:local .
    # With Podman
    podman build --network private -t polarion:local .
    # With Apple container
    container system start
    container builder start --cpus 8 --memory 8g
    container build --platform linux/amd64 -t polarion:local .
    container builder stop
    ```
5.  **Run** the container using the locally built image:
    ```bash
    # With Docker
    docker run -d \
      --name polarion \
      --platform linux/amd64 \
      --memory 4g \
      -p 80:80 \
      -p 5433:5433 \
      -p 5005:5005 \
      -e JAVA_OPTS="-Xmx3g -Xms3g" \
      -e JDWP_ENABLED=true \
      --volume polarion_repo:/opt/polarion/data/svn \
      --volume polarion_extensions:/opt/polarion/polarion/extensions \
      polarion:local
    # With Podman
    podman run -d \
      --name polarion \
      --memory 4g \
      -p 80:80 \
      -p 5433:5433 \
      -p 5005:5005 \
      -e JAVA_OPTS="-Xmx3g -Xms3g" \
      -e JDWP_ENABLED=true \
      --volume polarion_repo:/opt/polarion/data/svn \
      --volume polarion_extensions:/opt/polarion/polarion/extensions \
      polarion:local
    # With Apple container
    container run -d \
      --name polarion \
      --platform linux/amd64 \
      --rosetta \
      --cpus 8 \
      --memory 4g \
      -p 127.0.0.1:8080:80 \
      -p 127.0.0.1:5433:5433 \
      -p 127.0.0.1:5005:5005 \
      -e JAVA_OPTS="-Xmx3g -Xms3g" \
      -e JDWP_ENABLED=true \
      -v polarion_repo:/opt/polarion/data/svn \
      -v polarion_extensions:/opt/polarion/polarion/extensions \
      polarion:local
    ```

### Option B: Pre-built Images

Pre-built images are hosted on the GitHub Container Registry (`ghcr.io/phillipboesger/polarion-docker`).
**Note:** Access to these images is **restricted**. You must request access from the repository owner to pull them.

If you have access:

1.  **Create a Personal Access Token (PAT)**:
    - Go to **GitHub Settings** > **Developer settings** > **Personal access tokens** > **Tokens (classic)**.
    - Generate a new token with the `read:packages` scope selected.
2.  **Login to the registry**:
    Replace `YOUR_GITHUB_TOKEN` and `YOUR_GITHUB_USERNAME` with your details:
    ```bash
    echo "YOUR_GITHUB_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
    ```
3.  **Run the container**:
    This command pulls the latest image and starts Polarion immediately:
    ```bash
    docker run -d \
    --name polarion \
    --platform linux/amd64 \
    --memory 4g \
    -p 80:80 \
    -p 5433:5433 \
    -p 5005:5005 \
    -e JAVA_OPTS="-Xmx3g -Xms3g" \
    -e JDWP_ENABLED=true \
    --volume polarion_repo:/opt/polarion/data/svn \
    --volume polarion_extensions:/opt/polarion/polarion/extensions \
    ghcr.io/phillipboesger/polarion-docker:latest
    ```
    _(Replace `polarion:latest` with the appropriate image name depending on how you built or pulled it)_

For Apple `container`, authenticate and run the same OCI image with explicit local port publishing:

```bash
container registry login ghcr.io
container run -d \
    --name polarion \
    --platform linux/amd64 \
    --rosetta \
    --cpus 8 \
    --memory 4g \
    -p 127.0.0.1:8080:80 \
    -p 127.0.0.1:5433:5433 \
    -p 127.0.0.1:5005:5005 \
    -e JAVA_OPTS="-Xmx3g -Xms3g" \
    -e JDWP_ENABLED=true \
    -v polarion_repo:/opt/polarion/data/svn \
    -v polarion_extensions:/opt/polarion/polarion/extensions \
    ghcr.io/phillipboesger/polarion-docker:latest
```

### Via Docker Compose

A `docker-compose.yml` is included for convenience.

Note: Docker Compose files in this repository are Docker-only. Apple `container` support is provided through direct CLI commands and the VS Code tasks documented in [docs/apple-container.md](./docs/apple-container.md).

1.  Clone this repository.
2.  Build the local image once (default compose image is `polarion:local`):
    ```bash
    DOCKER_BUILDKIT=1 docker build --platform linux/amd64 -t polarion:local -f Dockerfile .
    ```
    Use `POLARION_IMAGE=ghcr.io/phillipboesger/polarion-docker:latest` only if you explicitly want to run the registry image.
3.  Start the container:
    ```bash
    docker-compose up -d
    ```

The checked-in Compose files cap the Polarion container at `4g` RAM and default the JVM to `-Xmx3g -Xms3g`.

## ⚙️ Configuration & Customization

### Modular Customization

The entrypoint system allows you to inject custom startup logic without modifying the base image. The container looks for scripts in `/opt/polarion/entrypoint.d/` and executes them in alphanumeric order.

To add your own configuration:

1.  Create a shell script (e.g., `90-custom-setup.sh`).
2.  Mount it into the container:
    ```yaml
    volumes:
      - ./my-script.sh:/opt/polarion/entrypoint.d/90-custom-setup.sh
    ```

### Environment Variables

| Variable        | Description                                  | Default                       |
| :-------------- | :------------------------------------------- | :---------------------------- |
| `JAVA_OPTS`     | Java memory and VM arguments                 | `-Xmx3g -Xms3g`               |
| `JDWP_ENABLED`  | Enable Java Debug Wire Protocol              | `true`                        |
| `ALLOWED_HOSTS` | Comma-separated list of allowed host headers | `localhost,127.0.0.1,0.0.0.0` |
| `SMTP_HOST`     | SMTP host for mail notifications. When set, the entrypoint enables notifications and points Polarion's `announcer.smtp.host` at it. Unset on standalone runs. | _(unset; `mailpit` via Compose)_ |
| `SMTP_PORT`     | SMTP port used together with `SMTP_HOST`     | `25`                          |
| `MAILPIT_EMBEDDED` | Start the Mailpit catcher **inside** the Polarion container (SMTP `:25`, UI `:8025`) and auto-point Polarion at `127.0.0.1:25`. Lets a single container debug mail without a sidecar. An explicit `SMTP_HOST` still wins. | `false` |

### External SVN Endpoints

After startup, Apache serves the bundled Subversion repository through both of these authenticated endpoints:

- `http://<host>/repo`
- `http://<host>/repo-local`

The startup scripts also normalize the bundled SVN password file so the default bootstrap user remains `admin` / `admin`.

## 🛠️ Development & Debugging

### Remote Debugging (JDWP)

The container exposes port **5005** for Java remote debugging.

1.  Ensure `JDWP_ENABLED` is `true`.
2.  Connect your IDE (Eclipse, IntelliJ, VS Code) to `localhost:5005`.

Included `.vscode/launch.json` configuration:

```json
{
  "name": "Debug Polarion Container",
  "type": "java",
  "request": "attach",
  "hostName": "127.0.0.1",
  "port": 5005
}
```

### Mail Notifications (Mailpit)

The Compose files bundle a [Mailpit](https://github.com/axllent/mailpit) sidecar that captures **every** outgoing Polarion notification mail so you can inspect and debug it — no real mailbox required. Polarion is a pure SMTP client, so a catcher like Mailpit (or Papercut, MailHog, …) takes the role of the SMTP server.

How it is wired by default:

- Polarion's entrypoint sets `announcer.smtp.host=mailpit` / `announcer.smtp.port=25` and enables notifications (driven by `SMTP_HOST` / `SMTP_PORT`).
- The sidecar listens for SMTP on port **25** and serves a web UI on **8025**, both published to the host.

Usage:

1.  `docker-compose up -d` (Mailpit starts alongside Polarion).
2.  Trigger a notification in Polarion (e.g. assign a Work Item to a user that has an e-mail address; notification rules must be configured in the project).
3.  Open the catcher UI at **http://localhost:8025** to read the captured mail.

To attach your **own** external catcher instead of the bundled one, point it at host port **25**, or override `SMTP_HOST` / `SMTP_PORT` to target a different server (e.g. `host.docker.internal`).

#### Single container: embedded catcher

The image also ships a pinned Mailpit binary that can run **inside** the Polarion container, so the common "start a single container" workflow gets a mail catcher without a second container. Enable it with `MAILPIT_EMBEDDED=true`:

```bash
docker run -d --name polarion \
  -p 80:80 -p 8025:8025 \
  -e MAILPIT_EMBEDDED=true \
  polarion:local
# SMTP is reached in-container at 127.0.0.1:25; the web UI is at http://localhost:8025
```

When `MAILPIT_EMBEDDED=true` and no `SMTP_HOST` is given, the entrypoint starts Mailpit (SMTP `:25`, UI `:8025`) and auto-sets `announcer.smtp.host=127.0.0.1`. Publish `-p 8025:8025` to open the UI from the host (add `-p 25:25` only if you also want to send to it from outside the container).

**Embedded vs. sidecar — which to use?**

| | Embedded (`MAILPIT_EMBEDDED=true`) | Sidecar (Compose default) |
| :-- | :-- | :-- |
| Containers | One | Two (Polarion + `mailpit`) |
| Best for | `docker run` / `polarionctl.sh start`, single-container dev | `docker compose up`, multi-service setups |
| Mailpit version | Pinned in the image | `mailpit:latest`, independent of the image |

Both are supported. **Compose keeps the dedicated sidecar** (separation of concerns, always-fresh `mailpit:latest`); the **embedded** mode exists for the single-container workflow where a second container is unwanted. For manually wiring a *separate* Mailpit container to a single Polarion container over a user-defined network, see the manual / non-Compose wiring docs (issue #54).

> Notifications are delivered on Polarion's notification cron, so a captured mail can take a short moment to appear.

### Plugin Development

For developing custom plugins with live reloading, refer to [PLUGIN-DEVELOPMENT.md](./PLUGIN-DEVELOPMENT.md).

### Apple `container` Workflow

If you are developing on Apple silicon with macOS 26 or later, see [docs/apple-container.md](./docs/apple-container.md) for the Apple `container` quickstart and the VS Code task reference.

Open [`polarion-docker.code-workspace`](./polarion-docker.code-workspace) in VS Code to get all tasks available in the task picker:

| Group | Tasks |
| :--- | :--- |
| Container | `Build Image` · `Start` · `Stop` · `System Start` · `Builder Start/Stop` |
| Polarion | `Logs` · `Error Logs` · `Redeploy Single` · `Redeploy All` · `Redeploy Preflight` |

## 🖥️ Platform Support

- **macOS (Apple Silicon)**: Supported via Docker `--platform linux/amd64` and via Apple `container` on macOS 26+ using `--platform linux/amd64 --rosetta`.
- **macOS (Intel)**: Supported natively.
- **Windows (WSL2)**: Recommended for best performance.
- **Linux**: Native support.

## 🔍 Troubleshooting

- **Port Conflicts:** Ensure ports 80, 5005, and 5433 are free. The Mailpit sidecar additionally binds host ports **25** (SMTP) and **8025** (web UI); make sure no local mail server is already using port 25.
- **Memory:** This repo defaults Polarion to `4g` container RAM and a `3g` JVM heap so the process still has native headroom. Increase only if a specific workload requires it.
- **Apple `container` builder:** `bash scripts/polarionctl.sh build-image` starts the builder on demand with an `8g` cap and stops it again after the image build finishes.
- **Apple `container` first start:** A cold `linux/amd64` start on Apple silicon can spend multiple minutes in image unpacking before the container becomes visible or HTTP responds.
- **Access Denied:** If pulling `ghcr.io/...` fails, ensure you have requested and been granted access by the owner, or build locally (Option A).
