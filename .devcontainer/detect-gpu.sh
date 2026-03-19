#!/bin/bash
# GPU Detection Script for VSCode Dev Container
#
# This script detects the available GPU (NVIDIA, AMD, or Intel) and outputs
# the appropriate Docker run arguments for GPU passthrough.
#
# Usage:
#   ./detect-gpu.sh
#
# Output:
#   Space-separated Docker run arguments for GPU support
#
# Example:
#   ARGS=$(./detect-gpu.sh)
#   docker run $ARGS ...

set -e

detect_gpu_args() {
    # Check for NVIDIA GPU
    if lspci 2>/dev/null | grep -qi nvidia && command -v nvidia-smi &>/dev/null; then
        # Ensure NVIDIA CDI specification exists for Podman
        if command -v nvidia-ctk &>/dev/null; then
            if [ ! -d "/var/run/cdi" ] || [ -z "$(ls -A /var/run/cdi 2>/dev/null)" ]; then
                echo "Generating NVIDIA CDI specification..."
                sudo nvidia-ctk cdi generate --output=/var/run/cdi/nvidia.json 2>/dev/null || true
            fi
        fi
        # Use Podman-compatible CDI device flag
        echo "--device=nvidia.com/gpu=all"
        return 0
    fi

    # Check for AMD/Intel GPU (via DRI)
    if [ -d "/dev/dri" ] && [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
        echo "--device=/dev/dri --device=/dev/kfd"
        return 0
    fi

    # No GPU detected
    echo ""
}

# Output the detected GPU arguments
detect_gpu_args
