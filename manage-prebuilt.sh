#!/bin/zsh

# Management script for pre-built Polarion Docker container
# This script manages a container created from a pre-built image

CONTAINER_NAME="polarion"
DOCKER_IMAGE="phillipbosger/polarion-docker:latest"

show_help() {
    echo "Polarion Docker Management Script (Pre-built Image)"
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  pull      Pull latest image from registry"
    echo "  start     Start the Polarion container"
    echo "  stop      Stop the Polarion container"
    echo "  restart   Restart the Polarion container"
    echo "  status    Show container status"
    echo "  logs      Show container logs (real-time)"
    echo "  shell     Open shell in container"
    echo "  update    Pull latest image and recreate container"
    echo "  cleanup   Remove container and volumes"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start    # Start the container"
    echo "  $0 logs     # Show real-time logs"
    echo "  $0 update   # Update to latest image"
}

pull_image() {
    echo "📥 Pulling latest Polarion image..."
    docker pull ${DOCKER_IMAGE}
}

start_container() {
    if docker ps -q -f name=${CONTAINER_NAME} >/dev/null 2>&1; then
        echo "ℹ️ Container is already running"
        return 0
    fi
    
    if docker ps -a -q -f name=${CONTAINER_NAME} >/dev/null 2>&1; then
        echo "🚀 Starting existing container..."
        docker start ${CONTAINER_NAME}
    else
        echo "🐳 Creating and starting new container..."
        docker run -d \
            --name ${CONTAINER_NAME} \
            --platform linux/amd64 \
            -p 80:80 \
            -p 443:443 \
            -p 5432:5432 \
            -e POLARION_HOME=/polarion_root \
            -e JAVA_OPTS="-Xmx4g -Xms4g" \
            -e ALLOWED_HOSTS="localhost,127.0.0.1,0.0.0.0" \
            --restart unless-stopped \
            ${DOCKER_IMAGE}
    fi
    
    if [ $? -eq 0 ]; then
        echo "✅ Container started successfully!"
        echo "🌐 Access Polarion at: http://localhost"
    else
        echo "❌ Failed to start container"
        return 1
    fi
}

stop_container() {
    if docker ps -q -f name=${CONTAINER_NAME} >/dev/null 2>&1; then
        echo "🛑 Stopping container..."
        docker stop ${CONTAINER_NAME}
        echo "✅ Container stopped"
    else
        echo "ℹ️ Container is not running"
    fi
}

restart_container() {
    echo "🔄 Restarting container..."
    docker restart ${CONTAINER_NAME}
    if [ $? -eq 0 ]; then
        echo "✅ Container restarted successfully!"
    else
        echo "❌ Failed to restart container"
    fi
}

show_status() {
    echo "📊 Container Status:"
    echo "==================="
    
    if docker ps -f name=${CONTAINER_NAME} --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q ${CONTAINER_NAME}; then
        docker ps -f name=${CONTAINER_NAME} --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "🌐 Access URLs:"
        echo "   HTTP:  http://localhost"
        echo "   HTTPS: https://localhost"
    elif docker ps -a -f name=${CONTAINER_NAME} --format "table {{.Names}}\t{{.Status}}" | grep -q ${CONTAINER_NAME}; then
        echo "Container exists but is not running:"
        docker ps -a -f name=${CONTAINER_NAME} --format "table {{.Names}}\t{{.Status}}"
    else
        echo "❌ Container '${CONTAINER_NAME}' does not exist"
        echo "💡 Use '$0 start' to create and start the container"
    fi
}

show_logs() {
    if docker ps -a -q -f name=${CONTAINER_NAME} >/dev/null 2>&1; then
        echo "📋 Showing logs for ${CONTAINER_NAME}..."
        echo "Press Ctrl+C to exit log view"
        docker logs -f ${CONTAINER_NAME}
    else
        echo "❌ Container '${CONTAINER_NAME}' does not exist"
    fi
}

open_shell() {
    if docker ps -q -f name=${CONTAINER_NAME} >/dev/null 2>&1; then
        echo "🐚 Opening shell in container..."
        docker exec -it ${CONTAINER_NAME} /bin/bash
    else
        echo "❌ Container is not running"
        echo "💡 Use '$0 start' to start the container first"
    fi
}

update_container() {
    echo "🔄 Updating Polarion to latest version..."
    
    # Stop and remove existing container
    if docker ps -q -f name=${CONTAINER_NAME} >/dev/null 2>&1; then
        echo "🛑 Stopping existing container..."
        docker stop ${CONTAINER_NAME}
    fi
    
    if docker ps -a -q -f name=${CONTAINER_NAME} >/dev/null 2>&1; then
        echo "🗑️ Removing old container..."
        docker rm ${CONTAINER_NAME}
    fi
    
    # Pull latest image
    pull_image
    
    # Start new container
    start_container
}

cleanup() {
    echo "🧹 Cleaning up Polarion Docker setup..."
    read "REPLY?This will remove the container and all data volumes. Continue? (y/N): "
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Stop and remove container
        docker stop ${CONTAINER_NAME} >/dev/null 2>&1
        docker rm ${CONTAINER_NAME} >/dev/null 2>&1
        
        # Remove image
        docker rmi ${DOCKER_IMAGE} >/dev/null 2>&1
        
        echo "✅ Cleanup completed"
    else
        echo "❌ Cleanup cancelled"
    fi
}

# Main script logic
case "${1:-help}" in
    "pull")
        pull_image
        ;;
    "start")
        start_container
        ;;
    "stop")
        stop_container
        ;;
    "restart")
        restart_container
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs
        ;;
    "shell")
        open_shell
        ;;
    "update")
        update_container
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|*)
        show_help
        ;;
esac
