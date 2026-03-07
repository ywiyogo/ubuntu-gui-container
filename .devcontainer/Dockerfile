# Dockerfile for VSCode Dev Container
# This Dockerfile uses the pre-built ROS2 Jazzy image.
# Build the base image first using: ./build_docker.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev

ARG BASE_IMAGE=ros2-jazzy-dev:latest
FROM ${BASE_IMAGE}

# Install additional packages useful for VSCode development
RUN apt-get update && apt-get install -y \
    # Python tools for VSCode Python extension
    python3-pip \
    python3-venv \
    # Debugging tools
    gdb \
    lldb \
    # Git and version control
    git \
    git-lfs \
    # Additional utilities
    curl \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages for development
RUN pip3 install --break-system-packages \
    black \
    flake8 \
    pylint \
    ipython

# Set up workspace directory
WORKDIR /workspace

# Keep the ROS2 entrypoint
ENTRYPOINT ["/ros2_entrypoint.sh"]
CMD ["/bin/bash"]
