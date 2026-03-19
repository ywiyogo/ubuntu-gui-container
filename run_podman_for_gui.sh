#!/bin/bash
# Bash script for running any Ubuntu-based Podman image on any Linux host.
# Supports X11 and Wayland display servers with GPU passthrough.
# Example: ./run_podman_for_gui.sh ros2-jazzy-dev
# Author: Yongkie Wiyogo

set -euo pipefail

# Check for image name argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <image_name> [--gpu=nvidia|amd|none] [command]"
    echo "Example: $0 ros2-jazzy-dev"
    echo "        $0 ros2-jazzy-dev --gpu=none"
    echo "        $0 ros2-jazzy-dev --gpu=nvidia rviz2"
    echo ""
    echo "GPU modes:"
    echo "  nvidia  - Use NVIDIA GPU (via CDI)"
    echo "  amd     - Use AMD/Intel GPU (via /dev/dri)"
    echo "  none    - Software rendering only"
    echo "  auto    - Auto-detect (default: NVIDIA if available, else AMD, else none)"
    exit 1
fi

IMAGE_NAME="$1"
shift

# Parse GPU override flag before extracting positional args
GPU_MODE="auto"
REMAINING_ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --gpu=*)
            GPU_MODE="${1#*=}"
            shift
            ;;
        --gpu)
            GPU_MODE="${2:-}"
            shift 2
            ;;
        *)
            REMAINING_ARGS+=("$1")
            shift
            ;;
    esac
done

if [[ ${#REMAINING_ARGS[@]} -gt 0 ]]; then
    set -- "${REMAINING_ARGS[@]}"
else
    set -- "/bin/bash"
fi
CONTAINER_COMMAND="$*"

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
GPU_ACTIVE=""

detect_gpu_nvidia() {
    if ! command -v nvidia-ctk &>/dev/null; then
        echo "Warning: nvidia-ctk not found. Install nvidia-container-toolkit:"
        echo "  Arch:   sudo pacman -S nvidia-container-toolkit"
        echo "  Ubuntu: sudo apt install nvidia-container-toolkit"
        return 1
    fi

    if [ ! -d "/var/run/cdi" ] || [ -z "$(ls -A /var/run/cdi 2>/dev/null)" ]; then
        echo "Generating NVIDIA CDI specification..."
        sudo nvidia-ctk cdi generate --output=/var/run/cdi/nvidia.json
    fi

    GPU_ARGS=(
        --device nvidia.com/gpu=all
    )
    GPU_ENV=(
        -e "LIBGL_ALWAYS_SOFTWARE=0"
        -e "NVIDIA_VISIBLE_DEVICES=${NVIDIA_VISIBLE_DEVICES:-all}"
        -e "NVIDIA_DRIVER_CAPABILITIES=${NVIDIA_DRIVER_CAPABILITIES:-all}"
    )
    echo "NVIDIA GPU support enabled (via CDI)"
    return 0
}

detect_gpu_amd() {
    if [ -d "/dev/dri" ]; then
        GPU_ARGS=(
            --device "/dev/dri:/dev/dri"
        )
        if [ -c "/dev/kfd" ]; then
            GPU_ARGS+=(--device "/dev/kfd:/dev/kfd")
        fi
        GPU_ENV=(
            -e "LIBGL_ALWAYS_SOFTWARE=0"
        )
        echo "AMD/Intel GPU support enabled"
        return 0
    fi
    return 1
}

case "$GPU_MODE" in
    nvidia)
        echo "GPU mode: forced NVIDIA"
        if detect_gpu_nvidia; then
            GPU_ACTIVE="nvidia"
        else
            echo "Falling back to software rendering."
            GPU_ENV=(-e "LIBGL_ALWAYS_SOFTWARE=1")
            GPU_ACTIVE="none"
        fi
        ;;
    amd)
        echo "GPU mode: forced AMD/Intel"
        if detect_gpu_amd; then
            GPU_ACTIVE="amd"
        else
            echo "No AMD/Intel GPU found. Falling back to software rendering."
            GPU_ENV=(-e "LIBGL_ALWAYS_SOFTWARE=1")
            GPU_ACTIVE="none"
        fi
        ;;
    none)
        echo "GPU mode: software rendering only"
        GPU_ENV=(-e "LIBGL_ALWAYS_SOFTWARE=1")
        GPU_ACTIVE="none"
        ;;
    auto|"")
        echo "GPU mode: auto-detect"
        if lspci 2>/dev/null | grep -qi nvidia && command -v nvidia-smi &>/dev/null; then
            if detect_gpu_nvidia; then
                GPU_ACTIVE="nvidia"
            else
                echo "Auto-detect: falling back to AMD/Intel."
                if detect_gpu_amd; then
                    GPU_ACTIVE="amd"
                else
                    GPU_ENV=(-e "LIBGL_ALWAYS_SOFTWARE=1")
                    GPU_ACTIVE="none"
                fi
            fi
        elif detect_gpu_amd; then
            GPU_ACTIVE="amd"
        else
            echo "No GPU detected, using software rendering."
            GPU_ENV=(-e "LIBGL_ALWAYS_SOFTWARE=1")
            GPU_ACTIVE="none"
        fi
        ;;
    *)
        echo "Error: Unknown GPU mode '$GPU_MODE'"
        echo "Valid options: nvidia, amd, none, auto"
        exit 1
        ;;
esac

# Configure render group for GPU access
# Only needed for AMD/Intel GPU mode
GROUP_ARGS=()
if [ "$GPU_ACTIVE" = "amd" ]; then
    if [ -d "/dev/dri" ]; then
        if getent group render > /dev/null 2>&1; then
            if groups | grep -q '\brender\b'; then
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
    --cap-add=NET_RAW \
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
