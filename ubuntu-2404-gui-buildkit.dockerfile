# syntax=docker/dockerfile:1.4
# BuildKit-optimized Dockerfile for Ubuntu 24.04 GUI development
# Author: Yongkie Wiyogo
#
# BuildKit benefits with this Dockerfile:
# - Better layer caching
# - Parallel instruction execution where possible
# - Improved build performance
# - Concurrent layer downloads
#
# This is a single-stage build optimized for BuildKit's parallel execution.
# BuildKit will automatically parallelize independent operations.

FROM ubuntu:24.04

# Build arguments for user configuration
ARG USERNAME=user
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV PATH="/root/.cargo/bin:${PATH}"

# Combined single layer for all apt packages with aggressive cleanup
# BuildKit will parallelize the download and extraction of packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    make \
    autoconf \
    automake \
    libtool \
    meson \
    # Version control
    git \
    # Basic utilities
    bzip2 \
    curl \
    wget \
    vim \
    nano \
    htop \
    tar \
    tree \
    tmux \
    zip \
    unzip \
    strace \
    ltrace \
    # Networking
    iputils-ping \
    net-tools \
    iproute2 \
    dnsutils \
    # Terminal utilities
    ncurses-term \
    bash-completion \
    sysstat \
    # C/C++ development
    gdb \
    clang \
    clangd \
    lldb \
    valgrind \
    clang-format \
    # Python development
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    ipython3 \
    python3-numpy \
    python3-pandas \
    python3-matplotlib \
    python3-scipy \
    python3-sklearn \
    python3-cryptography \
    python3-requests \
    # Video and image processing
    ffmpeg \
    v4l-utils \
    # OpenCV dependencies
    libopencv-dev \
    # Cryptography dependencies
    libssl-dev \
    # GUI and graphics development
    libgtk-3-dev \
    libsdl2-dev \
    libglfw3-dev \
    libglew-dev \
    # Mesa libraries and development files
    libgl1-mesa-dev \
    libegl1-mesa-dev \
    libglu1-mesa-dev \
    libgles2-mesa-dev \
    mesa-common-dev \
    mesa-utils \
    libvulkan1 \
    vulkan-tools \
    libglx-mesa0 \
    mesa-vulkan-drivers \
    # X11 support
    libx11-dev \
    libxext-dev \
    libxrender-dev \
    libxinerama-dev \
    libxi-dev \
    libxrandr-dev \
    libxcursor-dev \
    libxtst6 \
    libxcomposite-dev \
    libxdamage-dev \
    libxfixes-dev \
    libxss-dev \
    libdbus-1-dev \
    # Wayland and XWayland support
    xwayland \
    wayland-protocols \
    libwayland-bin \
    libwayland-dev \
    libwayland-egl1 \
    libxkbcommon-dev \
    # Additional GUI libraries
    libqt5widgets5 \
    libqt5gui5 \
    libqt5waylandcompositor5 \
    # Font support (minimal, no CJK)
    fonts-liberation \
    fonts-noto \
    # Audio support
    pulseaudio \
    alsa-utils \
    # Video codecs
    libavcodec-extra \
    # Screen sharing and remote desktop
    xvfb \
    x11vnc \
    # Locale
    locales \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/* \
    && locale-gen en_US.UTF-8

# ImGui setup (shallow clone)
# BuildKit can parallelize this with the Rust installation below
RUN --mount=type=cache,target=/tmp/git-cache \
    git clone --depth 1 https://github.com/ocornut/imgui.git /usr/local/imgui \
    && rm -rf /usr/local/imgui/.git

# Setup terminal colors
RUN echo 'eval "$(dircolors -b)"' >> /etc/bash.bashrc && \
    echo 'alias ls="ls --color=auto"' >> /etc/bash.bashrc && \
    echo 'alias ll="ls -la --color=auto"' >> /etc/bash.bashrc

# Install Rust with minimal profile and cleanup
# BuildKit cache mount for Rust downloads
RUN --mount=type=cache,target=/tmp/rust-cache \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal \
    && rm -rf /root/.rustup/toolchains/*/share \
    && rm -rf /root/.cargo/registry/cache

ENV PATH="/root/.cargo/bin:${PATH}"

# Remove default ubuntu user to free UID 1000, then create user
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -u ${USER_UID} -U -s /bin/bash ${USERNAME}

# Entrypoint
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Set working directory
WORKDIR /home/${USERNAME}
