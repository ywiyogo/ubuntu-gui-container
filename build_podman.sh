#!/bin/bash
# Build Podman images from Dockerfiles with customizable image name and tag.
# Supports building base Ubuntu images and ROS2 development images.
# Usage: ./build_podman.sh [-d DOCKERFILE] [-n NAME] [-t TAG]
# Example: ./build_podman.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev

# Record start time for duration calculation
START_TIME=$(date +%s)

# Default values
DEFAULT_IMAGE_NAME="ubuntu2404_on_arch"
DEFAULT_IMAGE_TAG="latest"
DEFAULT_DOCKERFILE="ubuntu2404_on_arch.dockerfile"


# Function to print usage
print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Build a Podman image with current user credentials"
    echo
    echo "Options:"
    echo "  -d, --dockerfile PATH    Path to Dockerfile (default: $DEFAULT_DOCKERFILE)"
    echo "  -n, --name NAME          Image name (default: $DEFAULT_IMAGE_NAME)"
    echo "  -t, --tag TAG            Image tag (default: $DEFAULT_IMAGE_TAG)"
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

# Function to get Podman storage location
get_podman_root() {
    podman info --format '{{.Store.GraphRoot}}' 2>/dev/null || echo "/var/lib/containers/storage"
}

# Parse command line arguments
DOCKERFILE=$DEFAULT_DOCKERFILE
IMAGE_NAME=$DEFAULT_IMAGE_NAME
IMAGE_TAG=$DEFAULT_IMAGE_TAG

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

# Verify required files exist
if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found at $DOCKERFILE"
    exit 1
fi

# Print build information
echo "Podman Build Configuration:"
echo "------------------------"
echo "Dockerfile: $DOCKERFILE"
echo "Image Name: $IMAGE_NAME"
echo "Image Tag:  $IMAGE_TAG"
echo "------------------------"

# Build the image with build arguments
podman build \
    -t "$IMAGE_NAME:$IMAGE_TAG" \
    -f "$DOCKERFILE" \
    .

# Check if build was successful
if [ $? -eq 0 ]; then
    PODMAN_ROOT=$(get_podman_root)
    echo ""
    echo "=========================================="
    echo "Build successful!"
    print_elapsed_time
    echo "=========================================="
    echo ""
    echo "Storage location:"
    echo "  $PODMAN_ROOT"
    echo ""
    echo "Check disk usage: podman system df"
    echo ""
    echo "Cleanup commands:"
    echo "  podman system prune        # Remove stopped containers, unused images"
    echo "  podman system prune -a     # Remove all unused images"
    echo "  podman volume prune        # Remove unused volumes"
    echo ""
    echo "Run the container:"
    echo "  ./run_podman_for_gui.sh $IMAGE_NAME:$IMAGE_TAG"
else
    echo ""
    echo "=========================================="
    echo "Build failed!"
    print_elapsed_time
    echo "=========================================="
    exit 1
fi
