#!/bin/bash
# Build Docker images from Dockerfiles with customizable image name and tag.
# Supports building base Ubuntu images and ROS2 development images.
# Uses BuildKit for parallel builds and better caching (Docker 23.0+ default).
# Usage: ./build_docker.sh [-d DOCKERFILE] [-n NAME] [-t TAG]
# Example: ./build_docker.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev

# Record start time for duration calculation
START_TIME=$(date +%s)

# Default values
DEFAULT_IMAGE_NAME="ubuntu-2404-gui"
DEFAULT_IMAGE_TAG="latest"
DEFAULT_DOCKERFILE="ubuntu-2404-gui-buildkit.dockerfile"
DEFAULT_BASE_IMAGE=""
DEFAULT_BUILDKIT="true"


# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Build a Docker image with current user credentials"
    echo
    echo "Options:"
    echo "  -d, --dockerfile PATH    Path to Dockerfile (default: $DEFAULT_DOCKERFILE)"
    echo "  -n, --name NAME          Image name (default: $DEFAULT_IMAGE_NAME)"
    echo "  -t, --tag TAG            Image tag (default: $DEFAULT_IMAGE_TAG)"
    echo "  -b, --base-image IMAGE   Base image for multi-stage builds (e.g., localhost/ubuntu-2404-gui:latest)"
    echo "  --no-buildkit            Disable BuildKit mode (use traditional builder)"
    echo "  -h, --help               Show this help message"
    echo
    echo "Example:"
    echo "  $0 --dockerfile ./Dockerfile.dev --name my-dev-env --tag v1.0"
}

# Function to format and print elapsed time
print_elapsed_time() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local hours=$((duration / 3600))
    local minutes=$(((duration % 3600) / 60))
    local seconds=$((duration % 60))
    
    if [ $hours -gt 0 ]; then
        printf "Build time: %dh %dm %ds" $hours $minutes $seconds
    elif [ $minutes -gt 0 ]; then
        printf "Build time: %dm %ds" $minutes $seconds
    else
        printf "Build time: %ds" $seconds
    fi
}

# Function to get Docker storage location
get_docker_root() {
    docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker"
}

# Parse command line arguments
DOCKERFILE=$DEFAULT_DOCKERFILE
IMAGE_NAME=$DEFAULT_IMAGE_NAME
IMAGE_TAG=$DEFAULT_IMAGE_TAG
BASE_IMAGE=$DEFAULT_BASE_IMAGE
BUILDKIT=$DEFAULT_BUILDKIT

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dockerfile)
            DOCKERFILE="$2"
            shift 2
            ;;
        -n|--name)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -b|--base-image)
            BASE_IMAGE="$2"
            shift 2
            ;;
        --no-buildkit)
            BUILDKIT="false"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            print_usage
            exit 1
            ;;
    esac
done

# Auto-detect BuildKit Dockerfile for ROS2
if [ "$BUILDKIT" = "true" ] && [ "$DOCKERFILE" = "ros2_jazzy_desktop_dev.dockerfile" ]; then
    if [ -f "ros2_jazzy_desktop_dev-buildkit.dockerfile" ]; then
        echo "Note: Using BuildKit-optimized ROS2 Dockerfile"
        DOCKERFILE="ros2_jazzy_desktop_dev-buildkit.dockerfile"
    fi
fi

# Verify required files exist
if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE"
    exit 1
fi

# Print build information
echo "Docker Build Configuration:"
echo "------------------------"
echo "Dockerfile: $DOCKERFILE"
echo "Image Name: $IMAGE_NAME"
echo "Image Tag:  $IMAGE_TAG"
if [ -n "$BASE_IMAGE" ]; then
    echo "Base Image: $BASE_IMAGE"
fi
echo "BuildKit:   $BUILDKIT"
echo "------------------------"

# Build the image with build arguments
BUILD_ARGS=""
if [ -n "$BASE_IMAGE" ]; then
    BUILD_ARGS="--build-arg BASE_IMAGE=$BASE_IMAGE"
fi

# BuildKit environment variable (for Docker < 23.0)
if [ "$BUILDKIT" = "true" ]; then
    export DOCKER_BUILDKIT=1
fi

docker build \
    -t "$IMAGE_NAME:$IMAGE_TAG" \
    -f "$DOCKERFILE" \
    $BUILD_ARGS \
    .

# Check if build was successful
if [ $? -eq 0 ]; then
    DOCKER_ROOT=$(get_docker_root)
    echo ""
    echo "=========================================="
    echo "Build successful!"
    print_elapsed_time
    echo "=========================================="
    
    # Prompt to push to Docker Hub
    echo ""
    read -p "Push '$IMAGE_NAME:$IMAGE_TAG' to Docker Hub? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Ask for Docker Hub username
        read -p "Docker Hub username: " DOCKERHUB_USER
        
        if [ -z "$DOCKERHUB_USER" ]; then
            echo "Error: Username cannot be empty. Skipping push."
        else
            # Tag for Docker Hub
            echo "Tagging image..."
            docker tag "$IMAGE_NAME:$IMAGE_TAG" "$DOCKERHUB_USER/$IMAGE_NAME:$IMAGE_TAG"
            
            # Push to Docker Hub
            echo "Pushing to Docker Hub..."
            if docker push "$DOCKERHUB_USER/$IMAGE_NAME:$IMAGE_TAG"; then
                echo ""
                echo "✓ Successfully pushed to: $DOCKERHUB_USER/$IMAGE_NAME:$IMAGE_TAG"
            else
                echo "✗ Failed to push image. Make sure you are logged in: docker login"
            fi
        fi
    fi
    
    echo ""
    echo "Storage location:"
    echo "  $DOCKER_ROOT"
    echo ""
    echo "Check disk usage: docker system df"
    echo ""
    echo "Cleanup commands:"
    echo "  docker system prune        # Remove stopped containers, unused networks"
    echo "  docker system prune -a     # Also remove unused images"
    echo "  docker volume prune        # Remove unused volumes"
    echo ""
    echo "Run the container:"
    echo "  ./run_docker_for_gui.sh $IMAGE_NAME:$IMAGE_TAG"
else
    echo ""
    echo "=========================================="
    echo "Build failed!"
    print_elapsed_time
    echo "=========================================="
    exit 1
fi
