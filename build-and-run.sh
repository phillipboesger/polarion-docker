#!/bin/zsh

# Build and run script for Polarion on Mac with Apple Silicon
# This script forces x86_64 architecture for Rosetta compatibility

echo "🚀 Polarion Docker Build for Mac with Apple Silicon"
echo "================================================"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Check if Rosetta is installed
if ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
    echo "⚠️  Rosetta does not appear to be installed."
    echo "   Run: softwareupdate --install-rosetta"
    read "REPLY?Continue anyway? (y/N): "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📦 Building Polarion image for x86_64 architecture..."

# Build Docker image with explicit x86_64 platform
docker buildx build --platform linux/amd64 -t polarion:v2410 .

if [ $? -eq 0 ]; then
    echo "✅ Image built successfully!"
    
    echo "🐳 Starting Polarion container..."
    docker-compose up -d
    
    if [ $? -eq 0 ]; then
        echo "✅ Polarion container started!"
        echo ""
        echo "📋 Container Information:"
        echo "   - Container Name: polarion-v2410"
        echo "   - HTTP Port: http://localhost:80"
        echo "   - HTTPS Port: https://localhost:443"
        echo "   - SVN Repository: http://localhost/repo"
        echo "   - Architecture: x86_64 (Rosetta)"
        echo ""
        echo "📝 Useful commands:"
        echo "   - Show logs: docker-compose logs -f"
        echo "   - Stop container: docker-compose down"
        echo "   - Restart container: docker-compose restart"
        echo "   - Login to container: docker exec -it polarion-v2410 /bin/bash"
        echo "   - Management script: ./manage-polarion.sh help"
        echo ""
        echo "⏱️  Please wait a few minutes for Polarion to fully start up..."
        echo "   You can monitor progress with: ./manage-polarion.sh logs"
    else
        echo "❌ Error starting container"
        exit 1
    fi
else
    echo "❌ Error building image"
    exit 1
fi
