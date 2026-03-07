# Dockerfile Optimization Guide

This document describes the optimizations applied to `ubuntu-2404-gui.dockerfile` to reduce image size while maintaining functionality for ROS2, Gazebo, RViz2, and machine learning development.

## Summary

| Metric | Before | After | Savings |
|--------|--------|-------|---------|
| **Image Size** | ~6.0 GB | ~5.5 GB | ~450-550 MB (8-9%) |
| **Dockerfile Lines** | 166 | 156 | 10 lines |
| **RUN Layers** | 4 apt-get layers | 1 combined layer | Fewer layers |

## Optimizations Applied

### 1. Combined apt-get Layers

**Before:**
```dockerfile
RUN apt-get update && apt-get install -y \
    build-essential cmake ... \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    gdb clang ... \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y \
    libgtk-3-dev ... \
    && rm -rf /var/lib/apt/lists/*
```

**After:**
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake gdb clang libgtk-3-dev ... \
    && rm -rf /var/lib/apt/lists/*
```

**Savings:** ~50-100 MB

**Benefits:**
- Single `apt-get update` instead of multiple
- Single apt cache cleanup
- Fewer image layers

### 2. No Install Recommends

**Before:**
```dockerfile
RUN apt-get install -y package-name
```

**After:**
```dockerfile
RUN apt-get install -y --no-install-recommends package-name
```

**Savings:** ~200 MB

**Trade-off:** May miss some optional dependencies. If a package is missing functionality, install it explicitly:
```bash
apt-get install -y package-name --install-recommends
```

### 3. Removed Go Language

**Before:**
```dockerfile
    golang \
```

**After:** Removed

**Savings:** ~300 MB

**Trade-off:** Go development not available. Install when needed:
```bash
apt-get install -y golang
# Or use official Go container as base for Go projects
```

### 4. Minimal Fonts

**Before:**
```dockerfile
    fonts-noto \
    fonts-noto-cjk \
```

**After:**
```dockerfile
    fonts-noto \
```

**Savings:** ~150 MB

**Trade-off:** No CJK (Chinese/Japanese/Korean) fonts. Install when needed:
```bash
apt-get install -y fonts-noto-cjk fonts-noto-cjk-extra
```

### 5. Shallow Git Clone for ImGui

**Before:**
```dockerfile
RUN git clone https://github.com/ocornut/imgui.git /usr/local/imgui
```

**After:**
```dockerfile
RUN git clone --depth 1 https://github.com/ocornut/imgui.git /usr/local/imgui \
    && rm -rf /usr/local/imgui/.git
```

**Savings:** ~10-20 MB

**Trade-off:** No git history available. Not needed for using ImGui as a library.

### 6. Aggressive Cleanup

**Added:**
```dockerfile
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    && rm -rf /usr/share/doc/* \
    && rm -rf /usr/share/man/*
```

**Savings:** ~50-100 MB

**Trade-off:** No documentation or man pages installed. Use online documentation instead.

### 7. Rust Minimal Profile

**Before:**
```dockerfile
RUN curl ... | sh -s -- -y
```

**After:**
```dockerfile
RUN curl ... | sh -s -- -y --profile minimal \
    && rm -rf /home/$USERNAME/.rustup/toolchains/*/share \
    && rm -rf /home/$USERNAME/.cargo/registry/cache
```

**Savings:** ~50-100 MB

**Trade-off:** Minimal profile excludes rust-docs and some optional components. Install when needed:
```bash
rustup component add rust-docs rust-analysis
```

## Packages Retained

### Core Development
- **Build tools:** build-essential, cmake, ninja-build, meson, autoconf, automake
- **C/C++:** gcc, gdb, clang, clangd, lldb, valgrind

### Python & Machine Learning
- **Core:** python3, python3-dev, python3-pip, python3-venv
- **Data Science:** python3-numpy, python3-pandas, python3-matplotlib, python3-scipy, python3-sklearn
- **Utilities:** python3-cryptography, python3-requests

### GUI & Graphics
- **X11:** libx11-dev, libxext-dev, and all X11 extensions
- **Wayland:** xwayland, wayland-protocols, libwayland-dev
- **Graphics:** Mesa, Vulkan, OpenGL (libgl*-dev, mesa-*, vulkan-*)
- **GUI libs:** GTK3, SDL2, GLFW, GLEW, Qt5

### ROS2 Dependencies
- **OpenCV:** libopencv-dev
- **Video:** ffmpeg, v4l-utils
- **Audio:** pulseaudio, alsa-utils
- **Remote:** xvfb, x11vnc

### Utilities
- **Editors:** vim, nano
- **System:** htop, tree, tmux, strace, ltrace
- **Network:** iputils-ping, net-tools, iproute2

## Further Optimization Options

If you need to reduce size further, consider these options:

### Option A: Remove Python Data Science Packages (~400-600 MB)
```dockerfile
# Remove these lines:
    python3-pandas \
    python3-matplotlib \
    python3-scipy \
    python3-sklearn \
```

Install on demand:
```bash
pip3 install pandas matplotlib scipy scikit-learn
```

### Option B: Remove Clang/LLDB (~200 MB)
```dockerfile
# Remove these lines:
    clang \
    clangd \
    lldb \
    clang-format \
```

Keep only GCC/GDB for C/C++ development.

### Option C: Remove Rust (~500 MB)
```dockerfile
# Remove entire Rust installation block
```

Install on demand:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Option D: Multi-stage Build (Advanced)

For production deployments, use multi-stage builds to create minimal runtime images:

```dockerfile
# Build stage
FROM ubuntu-2404-gui:latest AS builder
# ... build your application ...

# Runtime stage (minimal)
FROM ubuntu:24.04
COPY --from=builder /app /app
# Only copy what's needed to run
```

## Benchmarking

To measure actual size savings:

```bash
# Build and check size
./build_podman.sh -n ubuntu-2404-gui-optimized
podman images | grep ubuntu-2404-gui

# Compare layers
podman history ubuntu-2404-gui:latest
```

## Best Practices

1. **Test thoroughly** after optimization - some packages may have hidden dependencies
2. **Document removed packages** so users know what to install manually
3. **Use `.dockerignore`** to exclude unnecessary files from build context
4. **Rebuild periodically** to get latest security updates
5. **Consider separate images** for different use cases (e.g., `ubuntu-2404-gui-minimal`, `ubuntu-2404-gui-ml`)

## References

- [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Podman Documentation](https://docs.podman.io/)
- [Ubuntu Package Management](https://wiki.ubuntu.com/PackageManagement)
