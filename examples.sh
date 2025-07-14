#!/bin/zsh

# Polarion Docker - Example Usage
# This script shows different ways to create and manage Polarion containers

DOCKER_IMAGE="phillipboesger/polarion-docker:latest"

echo "Polarion Docker - Usage Examples"
echo "================================"
echo ""

# Pull image
echo "📥 Pulling latest image..."
docker pull ${DOCKER_IMAGE}

echo ""
echo "Choose your setup:"
echo "1) Standard setup (4GB memory)"
echo "2) High memory setup (8GB memory)"
echo "3) Production setup (8GB + optimized GC)"
echo "4) Custom setup"
echo ""

read "choice?Enter your choice (1-4): "

case $choice in
    1)
        echo "🐳 Creating standard container (4GB)..."
        docker create \
            --name polarion \
            --platform linux/amd64 \
            -p 80:80 -p 443:443 -p 5432:5432 \
            -v polarion_data:/polarion_root/data \
            -v polarion_logs:/polarion_root/logs \
            -v polarion_config:/polarion_root/config \
            -e JAVA_OPTS="-Xmx4g -Xms4g" \
            -e POLARION_HOME=/polarion_root \
            -e ALLOWED_HOSTS="localhost,127.0.0.1,0.0.0.0" \
            --restart unless-stopped \
            ${DOCKER_IMAGE}
        ;;
    2)
        echo "🐳 Creating high memory container (8GB)..."
        docker create \
            --name polarion \
            --platform linux/amd64 \
            -p 80:80 -p 443:443 -p 5432:5432 \
            -v polarion_data:/polarion_root/data \
            -v polarion_logs:/polarion_root/logs \
            -v polarion_config:/polarion_root/config \
            -e JAVA_OPTS="-Xmx8g -Xms8g" \
            -e POLARION_HOME=/polarion_root \
            -e ALLOWED_HOSTS="localhost,127.0.0.1,0.0.0.0" \
            --restart unless-stopped \
            ${DOCKER_IMAGE}
        ;;
    3)
        echo "🐳 Creating production container (8GB + G1GC)..."
        docker create \
            --name polarion \
            --platform linux/amd64 \
            -p 80:80 -p 443:443 -p 5432:5432 \
            -v polarion_data:/polarion_root/data \
            -v polarion_logs:/polarion_root/logs \
            -v polarion_config:/polarion_root/config \
            -e JAVA_OPTS="-Xmx8g -Xms8g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions" \
            -e POLARION_HOME=/polarion_root \
            -e ALLOWED_HOSTS="localhost,127.0.0.1,0.0.0.0" \
            --restart unless-stopped \
            ${DOCKER_IMAGE}
        ;;
    4)
        echo "🛠️ Custom setup..."
        read "memory?Enter memory size (e.g., 4g, 8g, 16g): "
        read "custom_opts?Enter custom Java options (optional): "
        read "container_name?Enter container name (default: polarion): "
        
        container_name=${container_name:-polarion}
        
        if [ -z "$custom_opts" ]; then
            java_opts="-Xmx${memory} -Xms${memory}"
        else
            java_opts="$custom_opts"
        fi
        
        echo "🐳 Creating custom container..."
        docker create \
            --name ${container_name} \
            --platform linux/amd64 \
            -p 80:80 -p 443:443 -p 5432:5432 \
            -v polarion_data:/polarion_root/data \
            -v polarion_logs:/polarion_root/logs \
            -v polarion_config:/polarion_root/config \
            -e JAVA_OPTS="${java_opts}" \
            -e POLARION_HOME=/polarion_root \
            -e ALLOWED_HOSTS="localhost,127.0.0.1,0.0.0.0" \
            --restart unless-stopped \
            ${DOCKER_IMAGE}
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    echo "✅ Container created successfully!"
    echo ""
    echo "🚀 Starting container..."
    docker start polarion 2>/dev/null || docker start ${container_name}
    
    echo ""
    echo "📋 Container Information:"
    echo "   HTTP:  http://localhost"
    echo "   HTTPS: https://localhost"
    echo ""
    echo "📝 Useful commands:"
    echo "   View logs:       docker logs -f polarion"
    echo "   Stop container:  docker stop polarion"
    echo "   Start container: docker start polarion"
    echo "   Shell access:    docker exec -it polarion /bin/bash"
    echo ""
    echo "⏱️  Please wait a few minutes for Polarion to fully start up..."
else
    echo "❌ Failed to create container"
fi
