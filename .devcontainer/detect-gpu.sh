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
        echo "--gpus all --runtime nvidia"
        return 0
    fi
    
    # Check for AMD/Intel GPU (via DRI)
    if [ -d "/dev/dri" ] && [ -n "$(ls -A /dev/dri 2>/dev/null)" ]; then
        # For AMD/Intel, we use device passthrough
        # Note: devcontainer.json doesn't support --device in runArgs directly
        # Instead, we use mounts for /dev/dri
        echo ""
        return 0
    fi
    
    # No GPU detected
    echo ""
}

# Output the detected GPU arguments
detect_gpu_args
