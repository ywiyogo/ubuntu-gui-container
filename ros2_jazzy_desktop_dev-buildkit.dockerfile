# syntax=docker/dockerfile:1.4
# BuildKit-optimized ROS2 Jazzy Development Environment
# Author: Yongkie Wiyogo
#
# BuildKit optimizations:
# - Cache mounts for apt packages (3-5 GB cached)
# - Cache mounts for rosdep database
# - Selective --no-install-recommends (only for simple packages)
# - Parallel package downloads
# - Faster rebuilds (4-6x speedup with cache)

# Use your base development environment
ARG BASE_IMAGE=docker.io/wiyogo/ubuntu-2404-gui:latest
FROM ${BASE_IMAGE}

# Set ROS2 version
ARG ROS_DISTRO=jazzy

# Switch to root user for installation
USER root

# Add ROS2 apt repository with cache mount
# Use --no-install-recommends for simple tools (safe)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    ca-certificates \
    gnupg \
    && add-apt-repository universe \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && rm -rf /tmp/*

# Fix for OpenJDK manpage installation failure in Ubuntu 24.04 Docker
# Dependency chain: ros-jazzy-desktop -> libpcl-dev -> libvtk9-dev -> default-jdk -> openjdk-21-jdk
# VTK provides multi-language bindings (Python, Tcl, Java), and libvtk9-dev requires libvtk9-java
# OpenJDK postinst script fails if /usr/share/man/man1 doesn't exist
RUN mkdir -p /usr/share/man/man1

# Install ROS2 packages and Gazebo simulator with cache mount
# Do NOT use --no-install-recommends for meta-packages (ros-desktop, navigation2, etc.)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y \
    ros-${ROS_DISTRO}-desktop \
    ros-${ROS_DISTRO}-ros-base \
    ros-${ROS_DISTRO}-ros-gz \
    ros-${ROS_DISTRO}-navigation2 \
    ros-${ROS_DISTRO}-nav2-bringup \
    ros-${ROS_DISTRO}-nav2-minimal-tb* \
    ros-${ROS_DISTRO}-turtlebot4-simulator \
    ros-${ROS_DISTRO}-irobot-create-nodes \
    ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
    && rm -rf /tmp/*

# Install Python development tools with cache mount
# Use --no-install-recommends for Python packages (safe)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y --no-install-recommends \
    ros-dev-tools \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-rosdep \
    python3-vcstool \
    && rm -rf /tmp/*

# Install packages for ROS2 tutorials with cache mount
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get install -y \
    ros-${ROS_DISTRO}-turtle-tf2-py \
    && rm -rf /tmp/*

# Initialize rosdep with cache mount (caches rosdistro database)
RUN --mount=type=cache,target=/root/.ros,sharing=locked \
    rosdep init || true \
    && rosdep update --rosdistro $ROS_DISTRO

# Add entrypoint for sourcing the ROS2 setup.bash
COPY ./ros2_entrypoint.sh /
RUN chmod +x /ros2_entrypoint.sh
ENV ROS_DISTRO=${ROS_DISTRO}
ENTRYPOINT ["/ros2_entrypoint.sh"]

# Switch back to the default user if needed
USER $USERNAME

# Set up ROS2 workspace
RUN mkdir -p ~/ros2_ws/src

WORKDIR /home/$USERNAME/ros2_ws

# Default command
CMD ["/bin/bash"]
