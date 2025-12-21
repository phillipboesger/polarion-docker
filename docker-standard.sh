#!/bin/zsh

# Standard Docker Container Management for Polarion
# Usage: ./docker-standard.sh [pull|create|start|stop|restart|logs|remove|status]

DOCKER_IMAGE="phillipboesger/polarion-docker:latest"
CONTAINER_NAME="polarion"

show_help() {
    echo "Polarion Docker - Standard Container Management"
    echo "=============================================="
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  pull                     Pull latest image from registry"
    echo "  create [OPTIONS]         Create container with custom settings"
    echo "  start                    Start existing container"
    echo "  stop                     Stop running container"
    echo "  restart                  Restart container"
    echo "  logs                     Show container logs"
    echo "  remove                   Remove container (keeps volumes)"
    echo "  status                   Show container status"
    echo "  help                     Show this help"
    echo ""
    echo "Create Options:"
    echo "  --memory=SIZE            Set Java memory (e.g., --memory=8g)"
    echo "  --java-opts=\"OPTS\"       Custom Java options"
    echo "  --ports=\"HOST:CONTAINER\" Custom port mapping (default: 80:80,443:443)"
    echo "  --name=NAME              Custom container name (default: polarion)"
    echo ""
    echo "Examples:"
    echo "  $0 pull                                    # Pull latest image"
    echo "  $0 create                                  # Create with defaults"
    echo "  $0 create --memory=8g                      # Create with 8GB memory"
    echo "  $0 create --java-opts=\"-Xmx8g -XX:+UseG1GC\"  # Custom Java settings"
    echo "  $0 start                                   # Start container"
    echo "  $0 logs                                    # Show logs"
}

pull_image() {
    echo "📥 Pulling Polarion Docker image..."
    docker pull ${DOCKER_IMAGE}
    if [ $? -eq 0 ]; then
        echo "✅ Image pulled successfully!"
    else
        echo "❌ Failed to pull image"
        exit 1
    fi
}

create_container() {
    # Default values
    local memory="4g"
    local java_opts=""
    local ports="-p 80:80 -p 443:443 -p 5433:5433"
    local container_name=${CONTAINER_NAME}
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --memory=*)
                memory="${1#*=}"
                shift
                ;;
            --java-opts=*)
                java_opts="${1#*=}"
                shift
                ;;
            --ports=*)
                ports="-p ${1#*=}"
                shift
                ;;
            --name=*)
                container_name="${1#*=}"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Build Java options
    if [ -z "$java_opts" ]; then
        java_opts="-Xmx${memory} -Xms${memory}"
    fi
    
    # Check if container already exists
    if docker ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "❌ Container '${container_name}' already exists"
        echo "💡 Use 'docker rm ${container_name}' to remove it first, or choose a different name"
        exit 1
    fi
    
    echo "🐳 Creating Polarion container..."
    echo "   Name: ${container_name}"
    echo "   Memory: ${memory}"
    echo "   Java Options: ${java_opts}"
    
    docker create \
        --name ${container_name} \
        --platform linux/amd64 \
        ${ports} \
        -e POLARION_HOME=/polarion_root \
        -e JAVA_OPTS="${java_opts}" \
        -e ALLOWED_HOSTS="localhost,127.0.0.1,0.0.0.0" \
        --restart unless-stopped \
        ${DOCKER_IMAGE}
    
    if [ $? -eq 0 ]; then
        echo "✅ Container '${container_name}' created successfully!"
        echo "💡 Use '$0 start' to start the container"
    else
        echo "❌ Failed to create container"
        exit 1
    fi
}

start_container() {
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "ℹ️ Container '${CONTAINER_NAME}' is already running"
        return 0
    fi
    
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "❌ Container '${CONTAINER_NAME}' does not exist"
        echo "💡 Use '$0 create' to create the container first"
        exit 1
    fi
    
    echo "🚀 Starting Polarion container..."
    docker start ${CONTAINER_NAME}
    
    if [ $? -eq 0 ]; then
        echo "✅ Container started successfully!"
        echo "🌐 Polarion will be available at:"
        echo "   HTTP:  http://localhost"
        echo "   HTTPS: https://localhost"
        echo ""
        echo "⏱️  Please wait a few minutes for Polarion to fully start up..."
    else
        echo "❌ Failed to start container"
        exit 1
    fi
}

stop_container() {
    if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "ℹ️ Container '${CONTAINER_NAME}' is not running"
        return 0
    fi
    
    echo "🛑 Stopping Polarion container..."
    docker stop ${CONTAINER_NAME}
    
    if [ $? -eq 0 ]; then
        echo "✅ Container stopped successfully!"
    else
        echo "❌ Failed to stop container"
        exit 1
    fi
}

restart_container() {
    echo "🔄 Restarting Polarion container..."
    docker restart ${CONTAINER_NAME}
    
    if [ $? -eq 0 ]; then
        echo "✅ Container restarted successfully!"
    else
        echo "❌ Failed to restart container"
        exit 1
    fi
}

show_logs() {
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        echo "❌ Container '${CONTAINER_NAME}' does not exist"
        exit 1
    fi
    
    echo "📋 Showing logs for '${CONTAINER_NAME}'..."
    echo "Press Ctrl+C to exit"
    docker logs -f ${CONTAINER_NAME}
}

remove_container() {
    echo "🗑️ Removing Polarion container..."
    echo "⚠️ This will remove the container but keep your data volumes"
    
    # Stop if running
    docker stop ${CONTAINER_NAME} >/dev/null 2>&1
    
    # Remove container
    docker rm ${CONTAINER_NAME}
    
    if [ $? -eq 0 ]; then
        echo "✅ Container removed successfully!"
        echo "💾 Data volumes are preserved and can be reused"
    else
        echo "❌ Failed to remove container"
        exit 1
    fi
}

show_status() {
    echo "📊 Polarion Container Status"
    echo "============================"
    
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "^${CONTAINER_NAME}"; then
        echo "✅ Container is running:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -1
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "^${CONTAINER_NAME}"
        echo ""
        echo "🌐 Access URLs:"
        echo "   HTTP:  http://localhost"
        echo "   HTTPS: https://localhost"
    elif docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -q "^${CONTAINER_NAME}"; then
        echo "⏸️ Container exists but is not running:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}" | head -1
        docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep "^${CONTAINER_NAME}"
        echo ""
        echo "💡 Use '$0 start' to start the container"
    else
        echo "❌ Container '${CONTAINER_NAME}' does not exist"
        echo "💡 Use '$0 create' to create the container"
    fi
    
    # Show volumes
    echo ""
    echo "💾 Data Volumes:"
    docker volume ls | grep polarion || echo "   No Polarion volumes found"
}

# Main script logic
case "${1:-help}" in
    "pull")
        pull_image
        ;;
    "create")
        shift  # Remove 'create' from arguments
        create_container "$@"
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
    "logs")
        show_logs
        ;;
    "remove")
        remove_container
        ;;
    "status")
        show_status
        ;;
    "help"|*)
        show_help
        ;;
esac
