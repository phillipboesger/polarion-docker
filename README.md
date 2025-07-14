# Polarion Docker for Mac with Apple Silicon

This setup enables running Polarion (x86-build) on a Mac with Apple Silicon using Docker and Rosetta.

## 🚀 Quick Start

### Option 1: Use Pre-built Image (Recommended)

```bash
# Pull the latest image
docker pull your-dockerhub-username/polarion-docker:latest

# Create and start container with 8GB memory
docker create \
  --name polarion \
  --platform linux/amd64 \
  -p 80:80 -p 443:443 \
  -v polarion_data:/polarion_root/data \
  -v polarion_logs:/polarion_root/logs \
  -v polarion_config:/polarion_root/config \
  -e JAVA_OPTS="-Xmx8g -Xms8g" \
  your-dockerhub-username/polarion-docker:latest

docker start polarion
```

### Option 2: Use Helper Script

```bash
./docker-standard.sh pull
./docker-standard.sh create --memory=8g
./docker-standard.sh start
```

### Option 3: Use Docker Compose

```bash
# Standard usage (pre-built image)
docker-compose up -d

# For development (local build)
docker-compose -f docker-compose-build.yml up -d
```

## 🔧 Prerequisites

1. **Docker Desktop for Mac** - installed and running
2. **Rosetta 2** - for x86 emulation on Apple Silicon
   ```bash
   softwareupdate --install-rosetta
   ```

## 📋 System Requirements

### Minimum Requirements

- **macOS**: Big Sur 11.0 or later (for Apple Silicon support)
- **RAM**: 8GB (16GB recommended for optimal performance)
- **Storage**: 10GB free space
- **Docker Desktop**: Version 4.0 or later

### Recommended Configuration

- **RAM**: 16GB or more
- **Storage**: SSD with at least 20GB free space
- **Docker Desktop Settings**:
  - Memory: 8GB allocated to Docker
  - CPUs: 4 cores allocated to Docker

## 🐳 Container Management

### Standard Docker Commands

```bash
# Pull latest image
docker pull your-dockerhub-username/polarion-docker:latest

# Create container with custom settings
docker create \
  --name polarion \
  --platform linux/amd64 \
  -p 80:80 -p 443:443 \
  -v polarion_data:/polarion_root/data \
  -v polarion_logs:/polarion_root/logs \
  -v polarion_config:/polarion_root/config \
  -e JAVA_OPTS="-Xmx8g -Xms8g -XX:+UseG1GC" \
  your-dockerhub-username/polarion-docker:latest

# Basic operations
docker start polarion
docker stop polarion
docker restart polarion
docker logs -f polarion
docker rm polarion  # Remove container (keeps data)
```

### Helper Script Options

```bash
# Container management
./docker-standard.sh pull                              # Pull latest image
./docker-standard.sh create                            # Create with defaults (4GB)
./docker-standard.sh create --memory=8g                # Create with 8GB memory
./docker-standard.sh create --java-opts="-Xmx8g -XX:+UseG1GC"  # Custom Java options
./docker-standard.sh start                             # Start container
./docker-standard.sh stop                              # Stop container
./docker-standard.sh restart                           # Restart container
./docker-standard.sh logs                              # Show logs
./docker-standard.sh status                            # Check status
./docker-standard.sh remove                            # Remove container
```

### Docker Compose Usage

| Use Case         | File                       | Command                                            |
| ---------------- | -------------------------- | -------------------------------------------------- |
| **Normal Usage** | `docker-compose.yml`       | `docker-compose up -d`                             |
| **Development**  | `docker-compose-build.yml` | `docker-compose -f docker-compose-build.yml up -d` |

## 🌐 Access & Configuration

### URLs

- **HTTP**: http://localhost
- **HTTPS**: https://localhost
- **Default Credentials**: user: `polarion`, password: `polarion`

### Data Persistence

Important data is stored in Docker volumes:

- `polarion_data` - Application data
- `polarion_logs` - Log files
- `polarion_config` - Configuration files

### Java Configuration Examples

```bash
# Standard (4GB)
-e JAVA_OPTS="-Xmx4g -Xms4g"

# High Performance (8GB + G1GC)
-e JAVA_OPTS="-Xmx8g -Xms8g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# Production (16GB + optimizations)
-e JAVA_OPTS="-Xmx16g -Xms16g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions"
```

## 🔄 CI/CD & Docker Hub Setup

This repository includes automated builds via GitHub Actions.

### For Repository Maintainers

1. **Create Docker Hub account** at [hub.docker.com](https://hub.docker.com)
2. **Generate Access Token**: Account Settings → Security → New Access Token
3. **Set GitHub Secrets**:
   ```
   DOCKERHUB_USERNAME: your-docker-hub-username
   DOCKERHUB_TOKEN: your-access-token
   ```
4. **Update image names** in all files:
   ```bash
   find . -name "*.sh" -o -name "*.yml" -o -name "*.md" | \
     xargs sed -i '' 's/your-dockerhub-username/YOUR-ACTUAL-USERNAME/g'
   ```
5. **Push changes** → Automatic build starts

### Available Tags

- `latest` - Latest stable build
- `v2410` - Specific Polarion version
- Semantic versions (e.g., `v1.0.0`)

## 🔍 Troubleshooting

### Container Issues

```bash
# Check logs
docker logs -f polarion

# Check container status
docker ps -a

# Access container shell
docker exec -it polarion /bin/bash
```

### Performance Issues

- Since the container runs via Rosetta, performance may be lower than native x86
- Allocate more RAM/CPU cores in Docker Desktop settings
- Use SSD storage for better I/O performance

### Rosetta Issues

```bash
# Check if Rosetta is running
pgrep oahd

# Install if missing
softwareupdate --install-rosetta
```

## 🧪 Development

### Project Structure

```
polarion-docker/
├── docker-compose.yml       # Standard usage (pre-built image)
├── docker-compose-build.yml # Development (local build)
├── dockerfile              # Docker image definition
├── docker-standard.sh      # Helper script for container management
├── examples.sh             # Interactive setup examples
├── polarion_starter.sh     # Container startup script
├── install.expect          # Automated installation script
├── polarion-linux.zip      # Polarion installation (via Git LFS)
└── .github/workflows/      # GitHub Actions for automated builds
```

### Git LFS for Large Files

The Polarion ZIP file (734 MB) is managed via Git LFS:

```bash
# For updates
cp /path/to/new/polarion-linux.zip .
git add polarion-linux.zip
git commit -m "Update Polarion to v24XX"
git push  # → Triggers automatic build
```

### Local Development

```bash
# Build locally
docker-compose -f docker-compose-build.yml up -d --build

# Or use the build script
./build-and-run.sh
```

## 📚 Version Information

- **Polarion Version**: 2410
- **Java Version**: OpenJDK 17.0.8
- **PostgreSQL Version**: 16
- **Apache Version**: 2.4
- **Ubuntu Base**: 24.04 LTS
- **Architecture**: linux/amd64 (via Rosetta on Apple Silicon)
