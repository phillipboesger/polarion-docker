# Polarion Docker

Run Polarion ALM in OCI-compatible containers on macOS, Windows, and Linux. This repository provides a flexible Dockerfile and setup scripts to easily containerize a fresh Polarion installation.

## 🌟 Features

The Docker image and its entrypoint scripts (`polarion_starter.sh` & `entrypoint.d/`) automatically handle many complex configurations that are usually manual:

- **Modular Entrypoint System**: Startup logic is split into lightweight scripts in `/opt/polarion/entrypoint.d/` for easy extensibility.
- **WebSocket Support**: Automatically configures Apache `ProxyPassMatch` to enable Polarion LiveDoc collaboration and other real-time features.
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
2.  **Place** the downloaded ZIP file in the data directory of this repository.
    - _Note: The build script automatically picks up any file matching `polarion_.zip`.\*
    - _Note: On Linux systems with SELinux enabled, set the context on `data` with `chcon -Rt 'container_file_t' data/`._
3.  **Build** the Docker image:
    ```bash
    # With Docker
    docker build -t polarion .
    # With Podman
    podman build --network private -t polarion .
    # With Apple container
    container system start
    container builder start --cpus 8 --memory 16g
    container build --platform linux/amd64 -t polarion:local .
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
    `bash
docker run -d \
    --name polarion \
    --platform linux/amd64 \
    -p 80:80 \
    -p 5433:5433 \
    -p 5005:5005 \
    -e JAVA_OPTS="-Xmx8g -Xms8g" \
    -e JDWP_ENABLED=true \
    --volume polarion_repo:/opt/polarion/data/svn \
    --volume polarion_extensions:/opt/polarion/polarion/extensions \
    ghcr.io/phillipboesger/polarion-docker:latest
`
    _(Replace `polarion:latest` with the appropriate image name depending on how you built or pulled it)_

For Apple `container`, authenticate and run the same OCI image with explicit local port publishing:

```bash
container registry login ghcr.io
container run -d \
    --name polarion \
    --platform linux/amd64 \
    --rosetta \
    --cpus 8 \
    --memory 16g \
    -p 127.0.0.1:8080:80 \
    -p 127.0.0.1:5433:5433 \
    -p 127.0.0.1:5005:5005 \
    -e JAVA_OPTS="-Xmx8g -Xms8g" \
    -e JDWP_ENABLED=true \
    -v polarion_repo:/opt/polarion/data/svn \
    -v polarion_extensions:/opt/polarion/polarion/extensions \
    ghcr.io/phillipboesger/polarion-docker:latest
```

### Via Docker Compose

A `docker-compose.yml` is included for convenience.

Note: Docker Compose files in this repository are Docker-only. Apple `container` support is provided through direct CLI commands and the VS Code tasks documented in [docs/apple-container.md](./docs/apple-container.md).

1.  Clone this repository.
2.  Verify the `image` name in `docker-compose.yml` matches your local build (e.g., change to `polarion`) or the remote registry if you have access.
3.  Start the container:
    ```bash
    docker-compose up -d
    ```

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
| `JAVA_OPTS`     | Java memory and VM arguments                 | `-Xmx8g -Xms8g`               |
| `JDWP_ENABLED`  | Enable Java Debug Wire Protocol              | `true`                        |
| `ALLOWED_HOSTS` | Comma-separated list of allowed host headers | `localhost,127.0.0.1,0.0.0.0` |

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

### Plugin Development

For developing custom plugins with live reloading, refer to [PLUGIN-DEVELOPMENT.md](./PLUGIN-DEVELOPMENT.md).

### Apple `container` Workflow

If you are developing on Apple silicon with macOS 26 or later, see [docs/apple-container.md](./docs/apple-container.md) for the Apple `container` quickstart and the included VS Code tasks for:

- system start
- builder start
- image build
- Polarion start and stop
- live logs and error logs
- one-click redeploy into a running Apple `container` instance

## 🖥️ Platform Support

- **macOS (Apple Silicon)**: Supported via Docker `--platform linux/amd64` and via Apple `container` on macOS 26+ using `--platform linux/amd64 --rosetta`.
- **macOS (Intel)**: Supported natively.
- **Windows (WSL2)**: Recommended for best performance.
- **Linux**: Native support.

## 🔍 Troubleshooting

- **Port Conflicts:** Ensure ports 80, 5005, and 5433 are free.
- **Memory:** Polarion is heavy. Assign at least 8GB RAM to Docker Desktop.
- **Access Denied:** If pulling `ghcr.io/...` fails, ensure you have requested and been granted access by the owner, or build locally (Option A).
