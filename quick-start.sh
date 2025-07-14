#!/bin/zsh

# Quick Start script for Polarion - Pull and Run pre-built image
# This script downloads and runs a pre-built Polarion Docker image

echo "🚀 Polarion Docker Quick Start - Pre-built Image"
echo "==============================================="

# Configuration
DOCKER_IMAGE="phillipboesger/polarion-docker:latest"
CONTAINER_NAME="polarion-v2410"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Check if Rosetta is installed (for Apple Silicon Macs)
if [[ $(uname -m) == "arm64" ]]; then
    if ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
        echo "⚠️  Rosetta does not appear to be installed."
        echo "   Run: softwareupdate --install-rosetta"
        read "REPLY?Continue anyway? (y/N): "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# Check if container already exists
if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    echo "📦 Container '${CONTAINER_NAME}' already exists."
    read "REPLY?Remove existing container and create new one? (y/N): "
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️ Removing existing container..."
        docker stop ${CONTAINER_NAME} >/dev/null 2>&1
        docker rm ${CONTAINER_NAME}
    else
        echo "ℹ️ Starting existing container..."
        docker start ${CONTAINER_NAME}
        echo "✅ Container started!"
        exit 0
    fi
fi

echo "📥 Pulling latest Polarion Docker image..."
docker pull ${DOCKER_IMAGE}

if [ $? -eq 0 ]; then
    echo "✅ Image pulled successfully!"
    
    echo "🐳 Starting Polarion container..."
    
    # Create and start container with Docker Compose-like configuration
    docker run -d \
        --name ${CONTAINER_NAME} \
        --platform linux/amd64 \
        -p 80:80 \
        -p 443:443 \
        -p 5432:5432 \
        -v polarion_data:/polarion_root/data \
        -v polarion_logs:/polarion_root/logs \
        -v polarion_config:/polarion_root/config \
        -e POLARION_HOME=/polarion_root \
        -e JAVA_OPTS="-Xmx4g -Xms4g" \
        -e ALLOWED_HOSTS="localhost,127.0.0.1,0.0.0.0" \
        --restart unless-stopped \
        ${DOCKER_IMAGE}
    
    if [ $? -eq 0 ]; then
        echo "✅ Polarion container started!"
        echo ""
        echo "📋 Container Information:"
        echo "   - Container Name: ${CONTAINER_NAME}"
        echo "   - HTTP Port: http://localhost:80"
        echo "   - HTTPS Port: https://localhost:443"
        echo "   - SVN Repository: http://localhost/repo"
        echo "   - Architecture: x86_64 (Rosetta)"
        echo ""
        echo "📝 Useful commands:"
        echo "   - Show logs: docker logs -f ${CONTAINER_NAME}"
        echo "   - Stop container: docker stop ${CONTAINER_NAME}"
        echo "   - Restart container: docker restart ${CONTAINER_NAME}"
        echo "   - Login to container: docker exec -it ${CONTAINER_NAME} /bin/bash"
        echo "   - Remove container: docker rm -f ${CONTAINER_NAME}"
        echo ""
        echo "⏱️  Please wait a few minutes for Polarion to fully start up..."
        echo "   You can monitor progress with: docker logs -f ${CONTAINER_NAME}"
    else
        echo "❌ Error starting container"
        exit 1
    fi
else
    echo "❌ Error pulling image"
    echo "ℹ️ Make sure the image name is correct and you have access to it."
    exit 1
fi
