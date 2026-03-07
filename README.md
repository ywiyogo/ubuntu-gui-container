![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu)
![ROS2](https://img.shields.io/badge/ROS2-Jazzy-22314E?logo=ros)
![Docker](https://img.shields.io/badge/Docker-Supported-2496ED?logo=docker)
![Podman](https://img.shields.io/badge/Podman-Supported-892CA0?logo=podman)
![VSCode Dev Container](https://img.shields.io/badge/VSCode-Dev%20Container-007ACC?logo=visualstudiocode)

# Ubuntu GUI Container

Run Ubuntu 24.04 with full GUI support on any Linux distribution using Docker or Podman. Features X11/Wayland passthrough, GPU acceleration (NVIDIA/AMD/Intel), and pre-installed development tools. Ideal for **ROS2 development**, Gazebo simulation, RViz2, and general desktop applications.

## Features

- **Universal Compatibility** - Run Ubuntu 24.04 on Arch, Fedora, Debian, or any Linux distro
- **GUI Support** - X11 and Wayland passthrough for graphical applications
- **GPU Acceleration** - NVIDIA, AMD, and Intel GPU support with OpenGL/Vulkan
- **ROS2 Ready** - Pre-configured for ROS2 Jazzy development

## GUI & Graphics Support

### Display Servers

| Server | Support | Notes |
|--------|---------|-------|
| X11 | ✅ Full | Native X11 passthrough via `/tmp/.X11-unix` |
| Wayland | ✅ Full | Wayland socket passthrough with XWayland fallback |
| XWayland | ✅ Full | For X11 apps running on Wayland hosts |

### Graphics Libraries

| Library | Version | Purpose |
|---------|---------|---------|
| Mesa | Latest | OpenGL, GLES, EGL implementation |
| Vulkan | Latest | Modern graphics API with Vulkan tools |
| GLFW | 3.x | Window and input handling for OpenGL |
| GLEW | Latest | OpenGL extension loading |
| SDL2 | 2.x | Cross-platform multimedia library |

### GUI Toolkits

| Toolkit | Version | Notes |
|---------|---------|-------|
| Qt5 | 5.x | Widgets, GUI, Wayland compositor support |
| GTK3 | 3.x | GNOME toolkit with development headers |
| Dear ImGui | Latest | Immediate-mode GUI (cloned to `/usr/local/imgui`) |

### X11 Libraries

Full X11 development support including:
- `libx11`, `libxext`, `libxrender` - Core X11
- `libxinerama`, `libxi`, `libxrandr` - Multi-monitor and input
- `libxcursor`, `libxtst`, `libxss` - Cursor, testing, screensaver
- `libxcomposite`, `libxdamage`, `libxfixes` - Compositing extensions

### Audio & Multimedia

- **PulseAudio** - Audio server support
- **ALSA** - Advanced Linux Sound Architecture
- **FFmpeg** - Video and audio processing with extra codecs

### Remote Desktop

- **Xvfb** - Virtual framebuffer for headless GUI testing
- **x11vnc** - VNC server for remote access

## Prerequisites

| Tool | Installation |
|------|--------------|
| Docker | `curl -fsSL https://get.docker.com \| sh` |
| Podman | `sudo pacman -S podman` (Arch) or `sudo apt install podman` (Debian/Ubuntu) |

Optional for NVIDIA GPU support:
- **Arch:** `sudo pacman -S nvidia-container-toolkit`
- **Ubuntu:** `sudo apt install nvidia-container-toolkit`

## Quick Start

### Docker

```bash
# 1. Build base Ubuntu 24.04 image
./build_docker.sh

# 2. Build ROS2 Jazzy image
./build_docker.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev

# 3. Run container with GUI support
./run_docker_for_gui.sh ros2-jazzy-dev
```

### Podman

```bash
# 1. Build base Ubuntu 24.04 image
./build_podman.sh

# 2. Build ROS2 Jazzy image
./build_podman.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev

# 3. Run container with GUI support
./run_podman_for_gui.sh ros2-jazzy-dev
```

### VSCode Dev Container

For VSCode users, this project includes Dev Container support with automatic workspace setup:

1. **Prerequisites:**
   - Install [VSCode](https://code.visualstudio.com/)
   - Install [Dev Container extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
   - Build the ROS2 image first (see Docker Quick Start above)

2. **Open in Container:**
   - Open this folder in VSCode
   - Press `F1` → "Dev Containers: Reopen in Container"
   - Wait for container setup (rosdep, workspace build)

3. **Start Developing:**
   - Terminal auto-sources ROS2 environment
   - Extensions pre-installed (C++, CMake, ROS, Python, Docker, GitLens)

See [`.devcontainer/README.md`](.devcontainer/README.md) for detailed instructions.

## Project Structure

| File | Description |
|------|-------------|
| `ubuntu2404_on_arch.dockerfile` | Base Ubuntu 24.04 image with dev tools, GUI libs, and GPU support |
| `ros2_jazzy_desktop_dev.dockerfile` | ROS2 Jazzy + Gazebo + Nav2 + TurtleBot4 simulator |
| `build_docker.sh` / `build_podman.sh` | Build container images |
| `run_docker_for_gui.sh` / `run_podman_for_gui.sh` | Run containers with X11/Wayland passthrough |
| `entrypoint.sh` | Container entrypoint for user/GPU setup |
| `ros2_entrypoint.sh` | Sources ROS2 environment on container start |
| `.devcontainer/` | VSCode Dev Container configuration |

## Usage

### Building Images

```bash
# Docker
./build_docker.sh                                    # Base image
./build_docker.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev

# Podman
./build_podman.sh                                    # Base image
./build_podman.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev
```

### Running Containers

```bash
# Docker
./run_docker_for_gui.sh ros2-jazzy-dev

# Podman
./run_podman_for_gui.sh ros2-jazzy-dev
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WORK_DIR` | `$HOME` | Working directory inside container |
| `ROS_DOMAIN_ID` | `8` | ROS2 DDS domain ID |

### Running ROS2 Applications

Inside the container:
```bash
# Start RViz2
rviz2

# Start Gazebo with TurtleBot4
ros2 launch turtlebot4_ignition_bringup turtlebot4_ignition.launch.py

# Check ROS2 nodes
ros2 node list
```

## Enabling GPU Support

### NVIDIA GPU

On Arch Linux, install the NVIDIA Container Toolkit to enable GPU support in Docker:

```bash
sudo pacman -S nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

On Ubuntu:
```bash
sudo apt install nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

### AMD/Intel GPU

No additional setup required. The container automatically detects and uses `/dev/dri` for GPU access.

## Fixing Nvidia and libOgre Crash on Qt Applications

If RViz2 crashes with a backtrace similar to this:

```bash
#0  0x0000779c4c93514d in ?? () from /usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0
#1  0x0000779c3e8b3943 in ?? () from /usr/lib/x86_64-linux-gnu/libnvidia-glcore.so.565.77
#2  0x0000779c4c95615e in ?? () from /usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0
#3  0x0000779c4c924490 in ?? () from /usr/lib/x86_64-linux-gnu/libGLX_nvidia.so.0
#4  0x0000779c5fce82aa in Ogre::RenderSystem::_swapAllRenderTargetBuffers() ()
   from /opt/ros/jazzy/opt/rviz_ogre_vendor/lib/libOgreMain.so.1.12.10
#5  0x0000779c5fd2039b in Ogre::Root::_updateAllRenderTargets() ()
   from /opt/ros/jazzy/opt/rviz_ogre_vendor/lib/libOgreMain.so.1.12.10
#6  0x0000779c5fd18890 in Ogre::Root::renderOneFrame() ()
   from /opt/ros/jazzy/opt/rviz_ogre_vendor/lib/libOgreMain.so.1.12.10
```

Create `/etc/docker/daemon.json` with the following content:

```json
{
  "runtimes": {
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
```

Then restart Docker and ensure `--runtime nvidia` is included in the `docker run` command (already handled by `run_docker_for_gui.sh`):

```bash
sudo systemctl restart docker
```

## Allowing UDP Multicast for Multi-Robot Communication

If the UFW firewall is enabled, ROS2 nodes and topics may not be detected across the network. Allow UDP multicast for your local network:

```bash
# Example: Allow UDP from 192.168.8.0/24 network
sudo ufw allow in proto udp from 192.168.8.0/24 to any
```

Replace `192.168.8.0/24` with your actual network subnet.

## Disk Space Management

Container images and data can consume significant disk space over time. The build scripts automatically detect and display your storage location. Here's how to monitor and clean up:

### Docker

**Check storage location:**
```bash
docker info --format '{{.DockerRootDir}}'
```

**Check disk usage:**
```bash
docker system df       # Summary
docker system df -v    # Detailed
```

**Cleanup commands:**
```bash
docker system prune           # Remove stopped containers, unused networks, dangling images
docker system prune -a        # Also remove unused images (use with caution)
docker volume prune           # Remove unused volumes
docker image prune -a         # Remove all unused images
docker container prune        # Remove all stopped containers
```

### Podman

**Check storage location:**
```bash
podman info --format '{{.Store.GraphRoot}}'
```

**Check disk usage:**
```bash
podman system df       # Summary
podman system df -v    # Detailed
```

**Cleanup commands:**
```bash
podman system prune           # Remove stopped containers, unused images
podman system prune -a        # Remove all unused images
podman volume prune           # Remove unused volumes
podman image prune            # Remove unused images
podman container prune        # Remove all stopped containers
```

### Typical Disk Usage

| Component | Size Range |
|-----------|------------|
| Base Ubuntu 24.04 image | ~1-2 GB |
| ROS2 Jazzy Desktop | ~3-5 GB |
| ROS2 + Gazebo + Nav2 | ~6-10 GB |
| Full dev environment | ~10-15 GB |

### Moving Docker Data Directory

If your root partition is full, you can move Docker's data directory:

```bash
# Stop Docker
sudo systemctl stop docker

# Move data to another drive
sudo mv /var/lib/docker /path/to/new/location

# Create symlink
sudo ln -s /path/to/new/location /var/lib/docker

# Restart Docker
sudo systemctl start docker
```

## License

MIT License
