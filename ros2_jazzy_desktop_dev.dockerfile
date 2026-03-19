# Use your base development environment
ARG BASE_IMAGE=docker.io/wiyogo/ubuntu-2404-gui:latest
FROM ${BASE_IMAGE}

# Set ROS2 version
ARG ROS_DISTRO=jazzy

# Switch to root user for installation
USER root

# Add ROS2 apt repository
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository universe \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && rm -rf /var/lib/apt/lists/*

# Fix for OpenJDK manpage installation failure in Ubuntu 24.04 Docker
# Dependency chain: ros-jazzy-desktop -> libpcl-dev -> libvtk9-dev -> default-jdk -> openjdk-21-jdk
RUN mkdir -p /usr/share/man/man1

# Install ROS2 packages and Gazebo simulator
RUN apt-get update && apt-get install -y \
    ros-${ROS_DISTRO}-desktop \
    ros-${ROS_DISTRO}-ros-base \
    ros-${ROS_DISTRO}-ros-gz \
    ros-${ROS_DISTRO}-navigation2 \
    ros-${ROS_DISTRO}-nav2-bringup \
    ros-${ROS_DISTRO}-nav2-minimal-tb* \
    ros-${ROS_DISTRO}-turtlebot4-simulator \
    ros-${ROS_DISTRO}-irobot-create-nodes \
    ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
    ros-dev-tools \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-rosdep \
    python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# Install packages for ROS2 tutorials
RUN apt-get update && apt-get install -y \
    ros-${ROS_DISTRO}-turtle-tf2-py \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init && \
  rosdep update --rosdistro $ROS_DISTRO

# Install NVIDIA Container Toolkit for Podman CDI GPU passthrough
# This provides nvidia-cdi-hook and nvidia-ctk used by run_podman_for_gui.sh
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg \
    && chmod a+r /usr/share/keyrings/nvidia-container-toolkit.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/$(dpkg --print-architecture) /" | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list \
    && apt-get update \
    && apt-get install -y nvidia-container-toolkit \
    && rm -rf /var/lib/apt/lists/*

# Remove Mesa EGL vendor file to prevent AMDGPU driver initialization.
# When using NVIDIA GPU, Mesa's libglvnd probe tries to load the AMD driver
# on /dev/dri/card0, causing errors. Hiding the vendor file stops the probe.
RUN mv /usr/share/glvnd/egl_vendor.d/50_mesa.json \
       /usr/share/glvnd/egl_vendor.d/50_mesa.json.bak 2>/dev/null || true

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
