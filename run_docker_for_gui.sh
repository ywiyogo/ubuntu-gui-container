#!/bin/bash
# Bash script for running any Ubuntu-based Docker image on any Linux host.
# Supports X11 and Wayland display servers with GPU passthrough.
# Example: ./run_docker_for_gui.sh ros2-jazzy-dev
# Author: Yongkie Wiyogo

set -euo pipefail

# Check for image name argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <image_name> [command]"
    echo "Example: $0 ros2-jazzy-dev"
    exit 1
fi

IMAGE_NAME="$1"
shift 2>/dev/null || true
CONTAINER_COMMAND="${*:-/bin/bash}"

# Default working directory, can be overridden by environment variable
WORK_DIR="${WORK_DIR:-$HOME}"

# Detect if running under Wayland or X11
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "Wayland session detected"
    # Set up Wayland-specific environment
    # RViz2's Ogre3D backend requires X11 display even under Wayland (XWayland)
    DOCKER_DISPLAY_ARGS=(
        -e "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
        -e "XDG_RUNTIME_DIR=/run/user/$(id -u)"
        -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:/run/user/$(id -u)/$WAYLAND_DISPLAY"
        # Qt applications use XCB backend via XWayland for compatibility
        -e "QT_QPA_PLATFORM=xcb"
        -e "QT_X11_NO_MITSHM=1"
        -e "QT_OPENGL_MULTI_THREADED=1"
        -v "/tmp/.X11-unix:/tmp/.X11-unix:rw"
        -e "DISPLAY=$DISPLAY"
        -e "XAUTHORITY=/tmp/.Xauthority"
        -v "$XAUTHORITY:/tmp/.Xauthority:ro"
        -e "GDK_BACKEND=wayland"
    )
else
    echo "X11 session detected"
    # Check if X11 is available
    if ! xset q &>/dev/null; then
        echo "Warning: X11 display not found"
    fi
    DOCKER_DISPLAY_ARGS=(
        -e "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
        -v "$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR"
    )
fi

# Ensure required directories exist
if [ ! -d "$HOME" ]; then
    echo "Error: Home directory not found"
    exit 1
fi

# Detect GPU and configure GPU support
GPU_ARGS=()
GPU_ENV=()

if lspci | grep -qi nvidia && command -v nvidia-smi &>/dev/null; then
    # NVIDIA GPU detected
    # Check if Docker daemon is configured for NVIDIA runtime
    if [ ! -f "/etc/docker/daemon.json" ]; then
        echo "Error: NVIDIA GPU support requires nvidia-container-toolkit"
        echo ""
        echo "Installation:"
        echo "  Arch:   sudo pacman -S nvidia-container-toolkit"
        echo "  Ubuntu: sudo apt install nvidia-container-toolkit"
        echo ""
        echo "Then configure Docker:"
        echo "  sudo nvidia-ctk runtime configure --runtime=docker"
        echo "  sudo systemctl restart docker"
        exit 1
    fi

    GPU_ARGS=(
        # Expose all NVIDIA GPUs to the container
        --gpus all
        # Use NVIDIA container runtime for GPU support
        --runtime nvidia
        # Specify which NVIDIA devices to expose (default: all)
        -e "NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all}"
        # Specify NVIDIA driver capabilities (compute, graphics, utility, etc.)
        -e "NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES:-all}"
    )
    GPU_ENV=(
        # Use hardware OpenGL rendering
        -e "LIBGL_ALWAYS_SOFTWARE=0"
    )
    echo "NVIDIA GPU support enabled"

elif [ -d "/dev/dri" ]; then
    # AMD/Intel integrated GPU detected
    GPU_ARGS=(
        # Mount DRI device for OpenGL/Vulkan access
        --device "/dev/dri:/dev/dri"
    )
    GPU_ENV=(
        # Use hardware OpenGL rendering with Mesa
        -e "LIBGL_ALWAYS_SOFTWARE=0"
    )
    echo "AMD/Intel GPU support enabled"

else
    echo "No GPU detected, using software rendering"
    GPU_ENV=(
        # Force software rendering as fallback
        -e "LIBGL_ALWAYS_SOFTWARE=1"
    )
fi

# Allow X11 local connections (only needed for X11, not Wayland)
if [ "$XDG_SESSION_TYPE" != "wayland" ]; then
    xhost +local: 2>/dev/null || true
fi

# Build SSH auth socket path (handle empty variable)
SSH_SOCKET_ARGS=()
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    SSH_SOCKET_ARGS=(
        -e "SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
        -v "$SSH_AUTH_SOCK:$SSH_AUTH_SOCK"
    )
fi

# Run Docker container
# Configuration notes:
#
# Security:
#   --security-opt=no-new-privileges  - Prevents privilege escalation attacks
#   --init                             - Adds tini init process for proper signal handling (SIGTERM, SIGINT)
#
# Network & IPC:
#   --net=host                         - Uses host network stack (required for ROS2 DDS discovery)
#   --ipc=host                         - Shares host IPC namespace (required for shared memory GUI apps)
#
# User & Environment:
#   --user $(id -u):$(id -g)           - Runs as host user (prevents file permission issues)
#   --group-add render                 - Adds user to render group for GPU access
#   -e USER, -e HOME, -e USERNAME      - Preserves user environment
#   -e TERM                            - Enables terminal colors and features
#   -h $HOSTNAME                       - Sets container hostname to match host
#
# Volumes:
#   -v /tmp:/tmp                       - Shares tmp directory (X11 sockets, temp files)
#   -v /run/user/$(id -u)              - Shares runtime directory (Wayland/PulseAudio sockets)
#   -v $HOME:$HOME                     - Mounts home directory (preserves workspace)
#   -v $HOME/.ssh:ro                   - Mounts SSH keys read-only (for git/remote access)
#   -v /etc/passwd, /etc/group:ro      - Mounts user database (for user resolution)
#   -v /etc/timezone, /etc/localtime   - Preserves host timezone
#
# GPU Support:
#   --gpus all --runtime nvidia        - NVIDIA GPU passthrough
#   --device /dev/dri                  - AMD/Intel GPU passthrough
#
# ROS2:
#   -e ROS_DOMAIN_ID                   - Sets DDS domain for multi-robot communication
#
# Note: AppImage applications are not supported inside Docker containers

exec docker run --rm -it \
    --security-opt=no-new-privileges \
    --init \
    --net=host \
    --ipc=host \
    --user "$(id -u):$(id -g)" \
    --group-add render \
    -e "USER=$USER" \
    -e "HOME=$HOME" \
    -e "USERNAME=$USER" \
    -e "TERM=xterm-256color" \
    -h "$HOSTNAME" \
    "${DOCKER_DISPLAY_ARGS[@]}" \
    "${GPU_ARGS[@]}" \
    "${GPU_ENV[@]}" \
    "${SSH_SOCKET_ARGS[@]}" \
    -e "HTTP_PROXY=${docker_http_proxy:-}" \
    -e "HTTPS_PROXY=${docker_https_proxy:-}" \
    -e "NO_PROXY=${docker_no_proxy:-},localhost" \
    -e "ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-8}" \
    -v /tmp:/tmp \
    -v "/run/user/$(id -u):/run/user/$(id -u)" \
    -v "$HOME:$HOME" \
    -v "$HOME/.ssh:$HOME/.ssh:ro" \
    -v /etc/passwd:/etc/passwd:ro \
    -v /etc/group:/etc/group:ro \
    -v /etc/timezone:/etc/timezone:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -w "$WORK_DIR" \
    "$IMAGE_NAME" \
    $CONTAINER_COMMAND
