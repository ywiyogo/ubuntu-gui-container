#!/bin/bash
# Bash script for running any Ubuntu-based Podman image on any Linux host.
# Supports X11 and Wayland display servers with GPU passthrough.
# Example: ./run_podman_for_gui.sh ros2-jazzy-dev
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

# Generate container name from image name (remove tag and special chars)
CONTAINER_NAME=$(echo "$IMAGE_NAME" | cut -d':' -f1 | tr '/.' '_')

# Default working directory, can be overridden by environment variable
WORK_DIR="${WORK_DIR:-$HOME}"

# Detect if running under Wayland or X11
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    echo "Wayland session detected"
    # Set up Wayland-specific environment
    # RViz2's Ogre3D backend requires X11 display even under Wayland (XWayland)
    PODMAN_DISPLAY_ARGS=(
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
    PODMAN_DISPLAY_ARGS=(
        -e "DISPLAY=$DISPLAY"
        -e "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
        -v "$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR"
        -v "/tmp/.X11-unix:/tmp/.X11-unix"
    )
fi

# Ensure required directories exist
if [ ! -d "$HOME" ]; then
    echo "Error: Home directory not found"
    exit 1
fi

# Detect GPU and configure GPU support
# Note: Podman uses different GPU passthrough methods than Docker
GPU_ARGS=()
GPU_ENV=()

if lspci | grep -qi nvidia && command -v nvidia-smi &>/dev/null; then
    # NVIDIA GPU detected
    # Podman supports NVIDIA GPUs via CDI (Container Device Interface)
    # Check if NVIDIA CDI is available
    if command -v nvidia-ctk &>/dev/null; then
        # Generate CDI specification if not exists
        if [ ! -d "/var/run/cdi" ] || [ -z "$(ls -A /var/run/cdi 2>/dev/null)" ]; then
            echo "Generating NVIDIA CDI specification..."
            sudo nvidia-ctk cdi generate --output=/var/run/cdi/nvidia.json
        fi

        GPU_ARGS=(
            # Use CDI for NVIDIA GPU support in Podman
            --device nvidia.com/gpu=all
        )
        GPU_ENV=(
            # Use hardware OpenGL rendering
            -e "LIBGL_ALWAYS_SOFTWARE=0"
            -e "NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all}"
            -e "NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES:-all}"
        )
        echo "NVIDIA GPU support enabled (via CDI)"
    else
        echo "Warning: nvidia-ctk not found. NVIDIA GPU support disabled."
        echo "Install nvidia-container-toolkit for GPU support:"
        echo "  Arch:   sudo pacman -S nvidia-container-toolkit"
        echo "  Ubuntu: sudo apt install nvidia-container-toolkit"
        GPU_ENV=(-e "LIBGL_ALWAYS_SOFTWARE=1")
    fi

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

# Configure render group for GPU access
# Note: Use GID instead of group name to avoid name resolution issues in container
GROUP_ARGS=()
if [ -d "/dev/dri" ]; then
    if getent group render > /dev/null 2>&1; then
        # Check if current user is in render group
        if groups | grep -q '\brender\b'; then
            # Use GID directly to avoid group name resolution issues
            RENDER_GID=$(getent group render | cut -d: -f3)
            GROUP_ARGS=(--group-add "$RENDER_GID")
        else
            echo "=========================================="
            echo "Error: Current user is not in 'render' group"
            echo "=========================================="
            echo ""
            echo "Your system has the 'render' group, but you're not a member."
            echo ""
            echo "To fix this issue, run:"
            echo "  sudo usermod -aG render \$USER"
            echo ""
            echo "Then apply the change in your current shell:"
            echo "  newgrp render"
            echo ""
            echo "Or logout and login again for the change to take effect."
            echo ""
            exit 1
        fi
    else
        echo "=========================================="
        echo "Error: 'render' group not found"
        echo "=========================================="
        echo ""
        echo "Your system doesn't have the 'render' group."
        echo ""
        echo "To fix this issue, run:"
        echo "  sudo groupadd -f render"
        echo "  sudo usermod -aG render \$USER"
        echo ""
        echo "Then apply the change in your current shell:"
        echo "  newgrp render"
        echo ""
        echo "Or logout and login again for the change to take effect."
        echo ""
        exit 1
    fi
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

# Run Podman container
# Configuration notes:
#
# Security:
#   --security-opt=no-new-privileges  - Prevents privilege escalation attacks
#   --init                             - Adds init process for proper signal handling
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
#   --device nvidia.com/gpu=all        - NVIDIA GPU via CDI (Container Device Interface)
#   --device /dev/dri                  - AMD/Intel GPU passthrough
#
# ROS2:
#   -e ROS_DOMAIN_ID                   - Sets DDS domain for multi-robot communication
#
# Note: AppImage applications are not supported inside Podman containers

# Detect rootless Podman and set user flag accordingly
# In rootless mode: container UID 0 maps to host user, so use --user 0:0
# In rootful mode: use actual UID/GID
USER_ARGS=()
if podman info --format '{{.Host.Security.Rootless}}' 2>/dev/null | grep -q "true"; then
    # Rootless Podman: container root (UID 0) maps to host user
    USER_ARGS=(--user "0:0")
else
    # Rootful Podman: use actual UID/GID
    USER_ARGS=(--user "$(id -u):$(id -g)")
fi

exec podman run --rm -it \
    --security-opt=no-new-privileges \
    --init \
    --net=host \
    --ipc=host \
    "${USER_ARGS[@]}" \
    "${GROUP_ARGS[@]}" \
    --name "$CONTAINER_NAME" \
    -e "USER=$USER" \
    -e "HOME=$HOME" \
    -e "USERNAME=$USER" \
    -e "TERM=xterm-256color" \
    -h "$HOSTNAME" \
    "${PODMAN_DISPLAY_ARGS[@]}" \
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
