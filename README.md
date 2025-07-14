# Polarion Docker for Mac with Apple Silicon

This setup enables running Polarion (x86-build) on a Mac with Apple Silicon using Docker and Rosetta.

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
- **Apple Silicon**: M1, M1 Pro, M1 Max, M2, or newer

### Recommended Configuration

- **RAM**: 16GB or more
- **Storage**: SSD with at least 20GB free space
- **Docker Desktop Settings**:
  - Memory: 8GB allocated to Docker
  - CPUs: 4 cores allocated to Docker
  - Disk Image Size: At least 64GB

## 🔐 Security Considerations

- Default credentials are used for database setup (user: `polarion`, password: `polarion`)
- SSL certificates are self-signed (for production, use proper certificates)
- Container runs with elevated privileges for installation
- Network ports are exposed on localhost only

## 🚀 Quick Start

### Initial Installation

```bash
# Build and start container
./build-and-run.sh
```

### Container Management

```bash
# Manage containers
./manage-polarion.sh [OPTION]

# Available options:
./manage-polarion.sh start    # Start container
./manage-polarion.sh stop     # Stop container
./manage-polarion.sh restart  # Restart container
./manage-polarion.sh logs     # Show logs
./manage-polarion.sh status   # Check status
./manage-polarion.sh shell    # Login to container
./manage-polarion.sh rebuild  # Rebuild
./manage-polarion.sh cleanup  # Delete everything
```

## 🌐 Access to Polarion

After startup, Polarion is available at:

- **HTTP**: http://localhost:80
- **HTTPS**: https://localhost:443

## 📁 Data Persistence

Important data is stored in Docker volumes:

- `polarion_data` - Application data
- `polarion_logs` - Log files
- `polarion_config` - Configuration files

## 🔍 Troubleshooting

### Container won't start

```bash
# Check logs
./manage-polarion.sh logs

# Check container status
./manage-polarion.sh status
```

### Performance Issues

Since the container is emulated via Rosetta, performance may be lower than on native x86 systems.

### Rosetta Issues

```bash
# Check Rosetta status
pgrep oahd

# If not installed:
softwareupdate --install-rosetta
```

## 📋 Important Commands

```bash
# Manage Docker containers directly
docker-compose up -d        # Start container
docker-compose down         # Stop container
docker-compose logs -f      # Show live logs

# Login to container
docker exec -it polarion-v2410 /bin/bash

# Restart container
docker-compose restart
```

## ⚡ Performance Tips

1. **Allocate more RAM**: Increase RAM allocation in Docker Desktop
2. **CPU cores**: Provide more CPU cores in Docker Desktop
3. **Disk cache**: Use SSD storage for better I/O performance

## 🧪 Development

### Project Structure

```
v2410/
├── build-and-run.sh      # Main build and startup script
├── manage-polarion.sh    # Container management script
├── polarion_starter.sh   # Container startup script
├── dockerfile           # Docker image definition
├── docker-compose.yml   # Service orchestration
├── install.expect       # Automated installation script
├── polarion-linux.zip   # Polarion installation archive
├── .dockerignore       # Docker build exclusions
└── README.md           # This documentation
```

### Building from Source

1. Ensure `polarion-linux.zip` contains the correct Polarion installation files
2. Modify environment variables in `docker-compose.yml` as needed
3. Run the build script: `./build-and-run.sh`

### Customization

- **Memory allocation**: Edit `JAVA_OPTS` in `docker-compose.yml`
- **Port mapping**: Modify port configurations in `docker-compose.yml`
- **SSL certificates**: Replace default certificates in `polarion_starter.sh`

## 🚀 Advanced Usage

### Custom Java Options

```bash
# Edit docker-compose.yml
environment:
  - JAVA_OPTS=-Xmx8g -Xms8g -XX:+UseG1GC
```

## 📚 Version Information

- **Polarion Version**: 2410
- **Java Version**: OpenJDK 17.0.8
- **PostgreSQL Version**: 16
- **Apache Version**: 2.4
- **Ubuntu Base**: 24.04 LTS
