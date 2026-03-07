# Use your base development environment
FROM wiyogo/ubuntu2404_on_arch:latest

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
