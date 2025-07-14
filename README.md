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

### 2. Run Polarion

```bash
# Pull and start Polarion (one command)
docker run -d \
  --name polarion \
  --platform linux/amd64 \
  -p 80:80 -p 443:443 \
  -v polarion_data:/polarion_root/data \
  -v polarion_logs:/polarion_root/logs \
  -v polarion_config:/polarion_root/config \
  -e JAVA_OPTS="-Xmx8g -Xms8g" \
  phillipboesger/polarion-docker:latest
```

### 3. Access Polarion

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
-p 80:80 -p 443:443

# Custom ports (e.g., if port 80 is occupied)
-p 8080:80 -p 8443:443
# Access via: http://localhost:8080
```

### Data Persistence

Your Polarion data is automatically saved in Docker volumes:

- `polarion_data` - Application data and projects
- `polarion_logs` - Log files
- `polarion_config` - Configuration files

These volumes persist even when the container is removed.

## 🔄 Development & Updates

### Updating to a New Polarion Version

1. **Create a new branch:**

   ```bash
   git checkout -b vXXXX  # Replace XX with version number
   ```

2. **Replace the Polarion ZIP file:**

   ```bash
   # Remove old version
   git rm polarion-linux.zip

   # Add new version (make sure it's exactly named "polarion-linux.zip")
   cp /path/to/new/polarion-linux.zip .
   git lfs track "*.zip"
   git add polarion-linux.zip
   git commit -m "Update Polarion to vXXXX"
   ```

3. **Update and test:**

   ```bash
   # Push branch
   git push origin vXXXX

   # GitHub Actions will automatically build the image
   # Wait for build to complete, then test:
   docker pull phillipboesger/polarion-docker:latest
   docker run --rm -p 8080:80 phillipboesger/polarion-docker:latest
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

# Build locally
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
