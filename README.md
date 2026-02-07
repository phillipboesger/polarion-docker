# Polarion Docker

Run Polarion ALM in Docker containers on macOS, Windows, and Linux.

## Table of Contents

- [Quick Start](#-quick-start)
- [Prerequisites](#-prerequisites)
- [Platform Support](#-platform-support)
- [Container Management](#-container-management)
- [Configuration Options](#-configuration-options)
- [Development & Updates](#-development--updates)
- [Troubleshooting](#-troubleshooting)
- [Advanced Usage](#-advanced-usage)

## 🚀 Quick Start

### 1. Install Docker

**macOS:**

```bash
# Install Docker Desktop for Mac
# Download from: https://www.docker.com/products/docker-desktop/
# Or via Homebrew:
brew install --cask docker
```

**Windows:**

```bash
# Install Docker Desktop for Windows
# Download from: https://www.docker.com/products/docker-desktop/
# Enable WSL2 backend for better performance
```

**Linux:**

```bash
# Install Docker Engine
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### 2. Login to Registry (Optional)

If the image is private, you must authenticate first:

```bash
# Login to GitHub Container Registry
# You need a GitHub Personal Access Token (classic) with 'read:packages' scope
echo "YOUR_GITHUB_TOKEN" | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

### 2. Create Polarion Container

```bash
# Pull and start Polarion (minimal example)
# Note: --platform linux/amd64 is required for Apple Silicon Macs
docker run -d \
  --name polarion \
  --platform linux/amd64 \
  -p 80:80 -p 443:443 \
  -p 5433:5433 \
  -p 5005:5005 \
  -e JAVA_OPTS="-Xmx4g -Xms4g" \
  -e JDWP_ENABLED=true \
  ghcr.io/phillipboesger/polarion-docker:latest
```

**Replace the version information by any major version > 2310 that you want or use latest**

### 4. Access Polarion

- **URL**: http://localhost
- **Default Login**: user: `polarion`, password: `polarion`

That's it! Polarion is running. 🎉

## 🔧 Prerequisites

### All Platforms

- **Docker Desktop** or **Docker Engine** (latest version)
- **8GB RAM minimum** (16GB recommended)
- **10GB free disk space**

### macOS with Apple Silicon (M1/M2/M3)

```bash
# Install Rosetta 2 for x86 emulation
softwareupdate --install-rosetta
```

### Windows

- **WSL2** enabled (for better performance)
- **Hyper-V** or **WSL2 backend** in Docker Desktop

## 🖥️ Platform Support

| Platform                | Status      | Notes                                |
| ----------------------- | ----------- | ------------------------------------ |
| **macOS Intel**         | ✅ Native   | Full performance                     |
| **macOS Apple Silicon** | ✅ Emulated | Requires Rosetta 2, good performance |
| **Windows**             | ✅ Native   | WSL2 recommended                     |
| **Linux x86_64**        | ✅ Native   | Full performance                     |

_Tested and verified on macOS. Should work on Windows and Linux._

## 🐳 Container Management

### Simple Commands

```bash
# Start Polarion
docker start polarion

# Stop Polarion
docker stop polarion

# View logs
docker logs -f polarion

# Remove container (keeps data)
docker rm polarion
```

### Helper Script (Optional)

For easier management, use the included helper script:

```bash
# Download the repository for helper scripts
git clone https://github.com/avasis-solutions/polarion-docker.git
cd polarion-docker

# Use helper script
./docker-standard.sh pull                    # Pull latest image
./docker-standard.sh create --memory=8g      # Create container with 8GB
./docker-standard.sh start                   # Start container
./docker-standard.sh logs                    # View logs
./docker-standard.sh stop                    # Stop container
```

### Docker Compose (Optional)

```bash
# Clone repository
git clone https://github.com/avasis-solutions/polarion-docker.git
cd polarion-docker

# Start with Docker Compose
docker-compose up -d

# Stop
docker-compose down
```

## 🔧 Remote Debugging (JDWP)

Polarion is started with JDWP (Java Debug Wire Protocol) enabled so that you can remotely debug the running JVM from VS Code or any other Java IDE.

### How JDWP is configured

- The container exposes JDWP on port **5005**.
- `docker-compose.yml` maps it by default as:
  ```yaml
  ports:
    - "5005:5005" # JDWP debug port
  ```
- Inside the container, Polarion’s JVM is started with:
  ```
  -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005
  ```
- This configuration is injected via `polarion_starter.sh` into `/opt/polarion/etc/config.sh` (variable `PSVN_JServer_opt`).
- JDWP can be toggled via the environment variable `JDWP_ENABLED` (default: `true`).

### Start debugging from VS Code

1. Ensure the container is running:
   ```bash
   docker ps
   ```
2. Open VS Code in the `polarion-docker` folder.
3. Go to **Run and Debug** (Ctrl+Shift+D).
4. Select the configuration **"Debug Polarion Container"**.
5. Press the green **Start Debugging** button.

Once attached, you can:

- Set breakpoints in your Polarion / plugin Java sources.
- Step through code (F10, F11, Shift+F11).
- Inspect variables, call stack, and threads.

### Example VS Code launch configuration

The repository already contains a ready-to-use launch configuration in `.vscode/launch.json`. For reference, a minimal configuration looks like this:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug Polarion Container",
      "type": "java",
      "request": "attach",
      "hostName": "127.0.0.1",
      "port": 5005,
      "presentation": {
        "group": "Polarion",
        "order": 1
      }
    }
  ]
}
```

You can adapt the `hostName` and `port` if you change the Docker port mapping.

### JDWP port and configuration

- **Default JDWP port (inside container)**: `5005`
- **Default mapping in `docker-compose.yml`**: `5005:5005`
- **Toggle JDWP**: set `JDWP_ENABLED=false` in `docker-compose.yml` if you want to disable debugging:
  ```yaml
  environment:
    - JDWP_ENABLED=false
  ```

For more details and troubleshooting tips, see [DEBUGGING.md](./DEBUGGING.md).

## 🧩 Plugin Development

For developing custom Polarion plugins with live reloading and debugging:

See [PLUGIN-DEVELOPMENT.md](./PLUGIN-DEVELOPMENT.md) for a complete step-by-step setup guide.

**In short:**

1. Mount your plugin source (and compiled classes) into the container via `docker-compose.yml`.
2. Let your IDE compile automatically so the container always sees the latest classes.
3. Attach the VS Code debugger using the **"Debug Polarion Container"** configuration.
4. Trigger your plugin functionality in Polarion and hit breakpoints without rebuilding images or redeploying JARs. 🚀

## ⚙️ Configuration Options

### Memory Settings

```bash
# 4GB (minimum)
-e JAVA_OPTS="-Xmx4g -Xms4g"

# 8GB (recommended)
-e JAVA_OPTS="-Xmx8g -Xms8g"

# 16GB (high performance)
-e JAVA_OPTS="-Xmx16g -Xms16g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
```

### Port Configuration

```bash
# Default ports
-p 80:80

# Custom ports (e.g., if port 80 is occupied)
-p 8080:80 -p 8443:443
# Access via: http://localhost:8080
```

### Data Persistence & Local Mounts

For better transparency and easier backup, you can map Polarions data
directories directly to host folders instead of anonymous Docker volumes.

**Example host paths (adapt for your environment):**

```bash
-v "/Users/your-user/Polarion/repo:/opt/polarion/repo" \
-v "/Users/your-user/Polarion/extensions:/opt/polarion/polarion/extensions" \
```

If you do **not** configure these mounts, Polarion falls back to the
default behavior inside the container and uses internal Docker-managed
storage.

## 🔄 Development & Updates

### Updating to a New Polarion Version

1. **Create a new branch:**

   ```bash
   git checkout -b vXXXX  # Replace XX with version number
   ```

2. **Update the Polarion ZIP source configuration:**

   ```bash
   # Polarion installation ZIP files are no longer versioned
   # inside this repository. They are downloaded automatically
   # during the Docker build from a central Google Drive folder
   # based on the branch version (e.g. v2410, v2506, v2512).
   git commit -m "Update Polarion to vXXXX"
   ```

3. **Update and test:**

   ```bash
   # Push branch
   git push origin vXXXX

   # GitHub Actions will automatically build the image
   # Wait for build to complete, then test:
   docker pull --platform linux/amd64 ghcr.io/phillipboesger/polarion-docker:latest
   docker run --rm --platform linux/amd64 -p 8080:80 ghcr.io/phillipboesger/polarion-docker:latest
   ```

4. **Merge to main:**
   ```bash
   # If tests pass, merge to main
   git checkout main
   git merge vXXXX
   git push origin main
   ```

### Local Development

```bash
# Clone repository
git clone https://github.com/avasis-solutions/polarion-docker.git
cd polarion-docker

# Build locally (incl. JDWP debug port 5005)
docker-compose -f docker-compose-build.yml up -d --build
```

## 🔍 Troubleshooting

### Container Won't Start

```bash
# Check logs for errors
docker logs polarion

# Common issues:
# 1. Port 80/443 already in use
#    Solution: Use different ports (-p 8080:80 -p 8443:443)
# 2. Insufficient memory
#    Solution: Allocate more RAM to Docker Desktop
```

### Performance Issues

**macOS Apple Silicon:**

- Performance is ~70-80% of native due to Rosetta emulation
- Allocate more RAM in Docker Desktop settings
- Use SSD storage for better I/O performance

**All Platforms:**

- Increase Docker memory allocation (Docker Desktop → Settings → Resources)
- Allocate 8GB+ to Docker
- Use fast storage (SSD preferred)

### Platform-Specific Issues

**macOS:**

```bash
# Check if Rosetta is installed
pgrep oahd || softwareupdate --install-rosetta
```

**Windows:**

```bash
# Enable WSL2 if not already enabled
wsl --install
# Restart computer and configure Docker to use WSL2 backend
```

**Linux:**

```bash
# Add user to docker group to avoid sudo
sudo usermod -aG docker $USER
# Logout and login again
```

## 🧪 Advanced Usage

### CI/CD Integration

This repository includes GitHub Actions for automated builds. Images are automatically built and published to Docker Hub when changes are pushed.

### Available Tags

- `latest` - Latest stable build
- `v2410` - Specific Polarion version
- Semantic versions (e.g., `v1.0.0`)

### Custom Builds

```bash
# Build with specific memory settings
docker build --build-arg JAVA_MEMORY=16g -t custom-polarion .

# Multi-stage builds for optimization
docker build --target=runtime -t polarion-slim .
```

### Version Information

- **Polarion Version**: 2410
- **Java Version**: OpenJDK 17.0.8
- **PostgreSQL Version**: 16
- **Apache Version**: 2.4
- **Ubuntu Base**: 24.04 LTS
- **Architecture**: linux/amd64
