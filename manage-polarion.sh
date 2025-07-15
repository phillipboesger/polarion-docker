#!/bin/zsh

# Polarion Container Management Script

CONTAINER_NAME="polarion"
COMPOSE_FILE="docker-compose.yml"

function show_usage() {
    echo "🐳 Polarion Container Management"
    echo "================================"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  start     - Start container"
    echo "  stop      - Stop container"
    echo "  restart   - Restart container"
    echo "  logs      - Show logs"
    echo "  status    - Show container status"
    echo "  shell     - Login to container"
    echo "  rebuild   - Rebuild image and restart container"
    echo "  cleanup   - Delete container and volumes"
    echo "  help      - Show this help"
}

function check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker is not running. Please start Docker Desktop."
        exit 1
    fi
}

function container_exists() {
    docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

function container_running() {
    docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"
}

case "$1" in
    "start")
        check_docker
        echo "🚀 Starting Polarion container..."
        docker-compose up -d
        if [ $? -eq 0 ]; then
            echo "✅ Container started!"
            echo "📱 Polarion is available at: http://localhost"
            echo "🔒 HTTPS: https://localhost"
        fi
        ;;
    
    "stop")
        check_docker
        echo "🛑 Stopping Polarion container..."
        docker-compose down
        ;;
    
    "restart")
        check_docker
        echo "🔄 Restarting Polarion container..."
        docker-compose restart
        ;;
    
    "logs")
        check_docker
        echo "📋 Showing container logs (Ctrl+C to exit)..."
        docker-compose logs -f
        ;;
    
    "status")
        check_docker
        if container_exists; then
            if container_running; then
                echo "✅ Container is running"
                echo "🌐 Polarion accessible at:"
                echo "   📱 HTTP:  http://localhost"
                echo "   🔒 HTTPS: https://localhost"
                echo "   📁 SVN:   http://localhost/repo"
                echo ""
                docker stats --no-stream $CONTAINER_NAME
            else
                echo "⚠️  Container exists but is not running"
            fi
        else
            echo "❌ Container does not exist"
        fi
        ;;
    
    "shell")
        check_docker
        if container_running; then
            echo "🐚 Connecting to container shell..."
            docker exec -it $CONTAINER_NAME /bin/bash
        else
            echo "❌ Container is not running. Start it first with: $0 start"
        fi
        ;;
    
    "rebuild")
        check_docker
        echo "🔨 Rebuilding image and starting container..."
        docker-compose -f docker-compose-build.yml down
        docker-compose -f docker-compose-build.yml up -d --build
        ;;
    
    "cleanup")
        check_docker
        echo "⚠️  This will delete container and all volumes!"
        read "REPLY?Are you sure? (y/N): "
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down -v
            docker rmi phillipboesger/polarion-docker:latest 2>/dev/null || true
            echo "🗑️  Cleanup completed"
        else
            echo "❌ Cancelled"
        fi
        ;;
    
    "help"|"")
        show_usage
        ;;
    
    *)
        echo "❌ Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
