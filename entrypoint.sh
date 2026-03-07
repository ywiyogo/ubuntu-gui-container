#!/bin/bash

set -e

XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/1000}

# Logging function
log() {
    echo "[ENTRYPOINT] $*" >&2
}

# Error handling
trap 'log "Error: Command failed with exit code $?"' ERR

# Setup runtime directory
setup_runtime_dir() {
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
    chown 1000:1000 "$XDG_RUNTIME_DIR"
}

# Setup display socket permissions
setup_display_permissions() {
    # Wayland
    if [ -n "$WAYLAND_DISPLAY" ] && [ -e "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        chmod 0600 "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
        chown 1000:1000 "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
    fi

    # X11
    if [ -e "/tmp/.X11-unix" ]; then
        chmod 1777 /tmp/.X11-unix
    fi
}

# Setup audio socket permissions
setup_audio_permissions() {
    for socket in /tmp/pulse-* /tmp/pipewire-*; do
        if [ -e "$socket" ]; then
            chown 1000:1000 "$socket"
        fi
    done
}

# Setup GPU access
setup_gpu_access() {
    if [ -d "/dev/dri" ]; then
        log "Setting up GPU access"
        for device in /dev/dri/*; do
            if [ -e "$device" ]; then
                group=$(stat -c '%g' "$device")
                if [ -n "$group" ]; then
                    usermod -a -G "$group" 1000 2>/dev/null || log "Could not add user to GPU group"
                fi
            fi
        done
    else
        log "No DRI devices found"
    fi
}

# Main entry point logic
if [ "$(id -u)" = "0" ]; then
    log "Running as root, setting up environment"

    setup_runtime_dir
    setup_display_permissions
    setup_audio_permissions
    setup_gpu_access

    # Switch to user 1000
    log "Switching to user 1000"
    exec su -c "$*" 1000
else
    log "Already running as non-root user: $*"
    # Execute the passed command (e.g., /bin/bash) with all arguments
    exec "$@"
fi
