#!/bin/bash
# Post-creation script for VSCode Dev Container
#
# This script runs after the container is created for the first time.
# It performs the following setup tasks:
# 1. Sources the ROS2 environment
# 2. Creates the workspace directory structure
# 3. Initializes and updates rosdep (ROS dependency manager)
# 4. Installs workspace dependencies from package.xml files
# 5. Builds the workspace using colcon if packages exist
#
# This script is automatically executed by VSCode's Dev Container extension
# as specified in devcontainer.json under "postCreateCommand".

set -e

echo "=========================================="
echo "Setting up ROS2 development environment..."
echo "=========================================="

# Get ROS distro from environment or default to jazzy
ROS_DISTRO="${ROS_DISTRO:-jazzy}"

# Source ROS2 environment
if [ -f "/opt/ros/$ROS_DISTRO/setup.bash" ]; then
    source "/opt/ros/$ROS_DISTRO/setup.bash"
    echo "✓ Sourced ROS2 $ROS_DISTRO environment"
else
    echo "✗ Warning: ROS2 $ROS_DISTRO not found at /opt/ros/$ROS_DISTRO/setup.bash"
fi

# Create workspace structure if not exists
echo ""
echo "Creating workspace structure..."
mkdir -p /workspace/src
mkdir -p /workspace/install
mkdir -p /workspace/log
mkdir -p /workspace/build
echo "✓ Created /workspace/src, install, log, build directories"

# Initialize rosdep if not done
echo ""
echo "Setting up rosdep..."
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    echo "Initializing rosdep..."
    rosdep init 2>/dev/null || echo "rosdep already initialized"
fi

# Update rosdep database
echo "Updating rosdep database..."
rosdep update

# Install dependencies from workspace packages (if any exist)
echo ""
echo "Checking for workspace dependencies..."
if [ "$(ls -A /workspace/src 2>/dev/null)" ]; then
    echo "Found packages in /workspace/src, installing dependencies..."
    cd /workspace
    
    # Install dependencies using rosdep
    # --ignore-src: Don't install packages that are in the workspace
    # -y: Don't prompt for confirmation
    # --rosdistro: Specify ROS distribution
    rosdep install \
        --from-paths src \
        --ignore-src \
        -y \
        --rosdistro "$ROS_DISTRO" 2>/dev/null || {
        echo "Note: Some dependencies may have failed to install."
        echo "This is normal if there are no package.xml files yet."
    }
else
    echo "No packages found in /workspace/src. Skipping dependency installation."
    echo "Add packages to src/ and rebuild the container to install dependencies."
fi

# Build workspace if it has packages
echo ""
echo "Building workspace..."
if [ "$(ls -A /workspace/src 2>/dev/null)" ]; then
    cd /workspace
    colcon build --symlink-install
    echo "✓ Workspace built successfully"
    
    # Source the workspace
    if [ -f "/workspace/install/setup.bash" ]; then
        source /workspace/install/setup.bash
        echo "✓ Sourced workspace install/setup.bash"
    fi
else
    echo "No packages to build. Workspace is empty."
    echo "Add your ROS2 packages to /workspace/src and run 'colcon build'."
fi

echo ""
echo "=========================================="
echo "Dev container setup complete!"
echo "=========================================="
echo ""
echo "Quick start:"
echo "  1. Add packages to /workspace/src"
echo "  2. Run 'colcon build --symlink-install'"
echo "  3. Source: 'source install/setup.bash'"
echo ""
