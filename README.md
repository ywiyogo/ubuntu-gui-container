![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-E95420?logo=ubuntu)
![ROS2](https://img.shields.io/badge/ROS2-Jazzy-22314E?logo=ros)
![Docker](https://img.shields.io/badge/Docker-Supported-2496ED?logo=docker)
![Podman](https://img.shields.io/badge/Podman-Supported-892CA0?logo=podman)
![BuildKit](https://img.shields.io/badge/BuildKit-Enabled-0db7ed?logo=docker)
![VSCode Dev Container](https://img.shields.io/badge/VSCode-Dev%20Container-007ACC?logo=visualstudiocode)

# Ubuntu GUI Container

Run Ubuntu 24.04 with full GUI support on any Linux distribution using Docker or Podman. Features X11/Wayland passthrough, GPU acceleration (NVIDIA/AMD/Intel), and pre-installed development tools. Ideal for **ROS2 development**, Gazebo simulation, RViz2, and general desktop applications.

## Features

- **Universal Compatibility** - Run Ubuntu 24.04 on Arch, Fedora, Debian, or any Linux distro
- **GUI Support** - X11 and Wayland passthrough for graphical applications
- **GPU Acceleration** - NVIDIA, AMD, and Intel GPU support with OpenGL/Vulkan
- **ROS2 Ready** - Pre-configured for ROS2 Jazzy development
- **BuildKit Optimized** - Parallel builds with 20-30% faster build times (see [BuildKit Guide](docs/buildkit_parallel.md))

## GUI & Graphics Support

### Display Servers

| Server   | Support | Notes                                             |
| -------- | ------- | ------------------------------------------------- |
| X11      | ✅ Full | Native X11 passthrough via `/tmp/.X11-unix`       |
| Wayland  | ✅ Full | Wayland socket passthrough with XWayland fallback |
| XWayland | ✅ Full | For X11 apps running on Wayland hosts             |

### Graphics Libraries

| Library | Version | Purpose                               |
| ------- | ------- | ------------------------------------- |
| Mesa    | Latest  | OpenGL, GLES, EGL implementation      |
| Vulkan  | Latest  | Modern graphics API with Vulkan tools |
| GLFW    | 3.x     | Window and input handling for OpenGL  |
| GLEW    | Latest  | OpenGL extension loading              |
| SDL2    | 2.x     | Cross-platform multimedia library     |

### GUI Toolkits

| Toolkit    | Version | Notes                                             |
| ---------- | ------- | ------------------------------------------------- |
| Qt5        | 5.x     | Widgets, GUI, Wayland compositor support          |
| GTK3       | 3.x     | GNOME toolkit with development headers            |
| Dear ImGui | Latest  | Immediate-mode GUI (cloned to `/usr/local/imgui`) |

### X11 Libraries

Full X11 development support including:

- `libx11`, `libxext`, `libxrender` - Core X11
- `libxinerama`, `libxi`, `libxrandr` - Multi-monitor and input
- `libxcursor`, `libxtst`, `libxss` - Cursor, testing, screensaver
- `libxcomposite`, `libxdamage`, `libxfixes` - Compositing extensions

### Remote Desktop

- **Xvfb** - Virtual framebuffer for headless GUI testing
- **x11vnc** - VNC server for remote access

## Prerequisites

| Tool   | Installation                                                                |
| ------ | --------------------------------------------------------------------------- |
| Docker | `curl -fsSL https://get.docker.com \| sh`                                   |
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

### Publishing to Docker Hub

After building, the script will prompt you to push images to Docker Hub.

**Manual push (if you skipped the prompt):**

**Docker:**

```bash
# 1. Login to Docker Hub
docker login

# 2. Tag and push base image
docker tag ubuntu-2404-gui:latest YOUR_USERNAME/ubuntu-2404-gui:latest
docker push YOUR_USERNAME/ubuntu-2404-gui:latest

# 3. Tag and push ROS2 image
docker tag ros2-jazzy-dev:latest YOUR_USERNAME/ros2-jazzy-dev:latest
docker push YOUR_USERNAME/ros2-jazzy-dev:latest
```

**Podman:**

```bash
# 1. Login to Docker Hub
podman login docker.io

# 2. Tag and push base image
podman tag localhost/ubuntu-2404-gui:latest docker.io/YOUR_USERNAME/ubuntu-2404-gui:latest
podman push docker.io/YOUR_USERNAME/ubuntu-2404-gui:latest

# 3. Tag and push ROS2 image
podman tag ros2-jazzy-dev:latest docker.io/YOUR_USERNAME/ros2-jazzy-dev:latest
podman push docker.io/YOUR_USERNAME/ros2-jazzy-dev:latest
```

Replace `YOUR_USERNAME` with your Docker Hub username.

### Using Local Base Images

Use the `-b/--base-image` flag to build from a locally cached image instead of pulling from Docker Hub:

```bash
# Podman with local image
./build_podman.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev -b localhost/ubuntu-2404-gui:latest

# Docker with local image
./build_docker.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev -b ubuntu-2404-gui:latest
```

This is useful when:

- You've already built the base image locally
- You want to avoid re-downloading from Docker Hub
- You're testing modifications to the base image

### Running Containers

```bash
# Docker
./run_docker_for_gui.sh ros2-jazzy-dev

# Podman
./run_podman_for_gui.sh ros2-jazzy-dev
```

### Environment Variables

| Variable        | Default | Description                        |
| --------------- | ------- | ---------------------------------- |
| `WORK_DIR`      | `$HOME` | Working directory inside container |
| `ROS_DOMAIN_ID` | `8`     | ROS2 DDS domain ID                 |

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

| File                                              | Description                                                                                                                                  |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `ubuntu-2404-gui-buildkit.dockerfile`             | BuildKit-optimized base image (default) with parallel stages                                                                                 |
| `ubuntu-2404-gui.dockerfile`                      | Traditional single-stage base image (fallback)                                                                                               |
| `ros2_jazzy_desktop_dev-buildkit.dockerfile`      | BuildKit-optimized ROS2 image (default) with cache mounts                                                                                    |
| `ros2_jazzy_desktop_dev.dockerfile`               | Traditional ROS2 image (fallback)                                                                                                            |
| `build_docker.sh` / `build_podman.sh`             | Build container images with BuildKit support (use `-b` for local base images)                                                                |
| `run_docker_for_gui.sh` / `run_podman_for_gui.sh` | Run containers with X11/Wayland passthrough                                                                                                  |
| `entrypoint.sh`                                   | Container entrypoint for user/GPU setup                                                                                                      |
| `ros2_entrypoint.sh`                              | Sources ROS2 environment on container start                                                                                                  |
| `.devcontainer/`                                  | VSCode Dev Container configuration                                                                                                           |
| `docs/`                                           | Documentation: [optimization](docs/optimization.md), [BuildKit](docs/buildkit_parallel.md), [disk management](docs/disk_space_management.md) |

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

Container images and data can consume significant disk space over time. For detailed information on monitoring disk usage, cleanup commands, and moving data directories, see [Disk Space Management Guide](docs/disk_space_management.md).

## License

MIT License
