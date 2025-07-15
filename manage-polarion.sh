#!/bin/bash

# Simple Polarion Container Manager
# Creates and manages individual Polarion containers for different versions

set -e

REGISTRY="phillipboesger/polarion-docker"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

usage() {
    echo "Usage: $0 [COMMAND] [VERSION]"
    echo
    echo "Commands:"
    echo "  create <version>     Create new Polarion container"
    echo "  start <version>      Start Polarion container"
    echo "  stop <version>       Stop Polarion container"
    echo "  remove <version>     Remove Polarion container"
    echo "  logs <version>       Show container logs"
    echo "  list                 List all Polarion containers"
    echo "  pull <version>       Pull Docker image for version"
    echo
    echo "Examples:"
    echo "  $0 create v2410      # Creates polarion-v2410 container"
    echo "  $0 start v2410       # Starts the container"
    echo "  $0 stop v2410        # Stops the container"
    echo "  $0 logs v2410        # Shows logs"
    echo "  $0 list              # Lists all containers"
}

create_container() {
    local version="$1"
    local container_name="polarion-$version"
    local image="$REGISTRY:$version"
    
    # Check if container already exists
    if docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        warn "Container $container_name already exists"
        return 0
    fi
    
    log "Creating Polarion container: $container_name"
    log "Using image: $image"
    
    docker create \
        --name "$container_name" \
        --platform linux/amd64 \
        -p "80:80" \
        -p "443:443" \
        -e "JAVA_OPTS=-Xmx4g -Xms4g" \
        -e "ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0" \
        "$image"
    
    log "Container $container_name created successfully"
    log "Start it with: $0 start $version"
}

start_container() {
    local version="$1"
    local container_name="polarion-$version"
    
    if ! docker ps -a --format '{{.Names}}' | grep -q "^$container_name$"; then
        error "Container $container_name does not exist. Create it first with: $0 create $version"
    fi
    
    log "Starting container: $container_name"
    docker start "$container_name"
    
    log "Container started. Access Polarion at:"
    log "  HTTP:  http://localhost"
    log "  HTTPS: https://localhost"
    log "Monitor logs with: $0 logs $version"
}

stop_container() {
    local version="$1"
    local container_name="polarion-$version"
    
    log "Stopping container: $container_name"
    docker stop "$container_name" 2>/dev/null || warn "Container $container_name was not running"
}

remove_container() {
    local version="$1"
    local container_name="polarion-$version"
    
    warn "This will remove the container $container_name"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Cancelled"
        return 0
    fi
    
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name"
    log "Container $container_name removed"
}

show_logs() {
    local version="$1"
    local container_name="polarion-$version"
    
    log "Showing logs for $container_name (Press Ctrl+C to exit):"
    docker logs -f "$container_name"
}

list_containers() {
    log "Polarion containers:"
    docker ps -a --filter "name=polarion-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || {
        warn "No Polarion containers found"
    }
}

pull_image() {
    local version="$1"
    local image="$REGISTRY:$version"
    
    log "Pulling image: $image"
    docker pull --platform linux/amd64 "$image"
}

# Validate version format
check_version() {
    if [[ ! "$1" =~ ^v[0-9]{4}$ ]]; then
        error "Invalid version format. Use format like 'v2410'"
    fi
}

# Main logic
case "${1:-}" in
    create)
        [[ -z "$2" ]] && { usage; exit 1; }
        check_version "$2"
        create_container "$2"
        ;;
    start)
        [[ -z "$2" ]] && { usage; exit 1; }
        check_version "$2"
        start_container "$2"
        ;;
    stop)
        [[ -z "$2" ]] && { usage; exit 1; }
        check_version "$2"
        stop_container "$2"
        ;;
    remove)
        [[ -z "$2" ]] && { usage; exit 1; }
        check_version "$2"
        remove_container "$2"
        ;;
    logs)
        [[ -z "$2" ]] && { usage; exit 1; }
        check_version "$2"
        show_logs "$2"
        ;;
    list)
        list_containers
        ;;
    pull)
        [[ -z "$2" ]] && { usage; exit 1; }
        check_version "$2"
        pull_image "$2"
        ;;
    *)
        usage
        exit 1
        ;;
esac
