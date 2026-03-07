# VSCode Dev Container Setup

This folder contains the configuration for using this project with VSCode's Dev Container extension. This provides an alternative to the standalone scripts for users who prefer VSCode integration.

## Prerequisites

1. **VSCode** - [Download](https://code.visualstudio.com/)
2. **Dev Container Extension** - Install from VSCode marketplace (`ms-vscode-remote.remote-containers`)
3. **Docker** - [Installation guide](https://docs.docker.com/engine/install/)
4. **Pre-built ROS2 image** - Run this first:
   ```bash
   # Build the base image
   ./build_docker.sh
   
   # Build the ROS2 image
   ./build_docker.sh -d ros2_jazzy_desktop_dev.dockerfile -n ros2-jazzy-dev
   ```

## Quick Start

1. **Open in Dev Container:**
   - Open VSCode in this repository
   - Press `F1` → "Dev Containers: Reopen in Container"
   - Or click the "Reopen in Container" prompt

2. **Wait for Setup:**
   - VSCode will build the container (if needed)
   - The `post-create.sh` script will run automatically
   - This sets up rosdep and builds any existing workspace

3. **Start Developing:**
   - Terminal automatically sources ROS2 environment
   - Add packages to `/workspace/src`
   - Build with `colcon build --symlink-install`

## GPU Support

### NVIDIA GPU

1. Install NVIDIA Container Toolkit:
   ```bash
   # Arch Linux
   sudo pacman -S nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   
   # Ubuntu
   sudo apt install nvidia-container-toolkit
   sudo nvidia-ctk runtime configure --runtime=docker
   sudo systemctl restart docker
   ```

2. Create `/etc/docker/daemon.json` (if you experience crashes):
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
   
3. Restart Docker:
   ```bash
   sudo systemctl restart docker
   ```

### AMD/Intel GPU

No additional setup required. The container automatically mounts `/dev/dri` for GPU access.

## GPU Detection

Run the detection script to check your GPU configuration:

```bash
./.devcontainer/detect-gpu.sh
```

This will output the appropriate Docker arguments for your system.

## File Structure

```
.devcontainer/
├── devcontainer.json    # Main Dev Container configuration
├── Dockerfile           # Builds from pre-built ROS2 image
├── post-create.sh       # Runs after container creation
├── detect-gpu.sh        # Detects GPU and outputs Docker args
└── README.md            # This file
```

## Configuration Options

### Change Base Image

Edit `.devcontainer/devcontainer.json`:

```json
"build": {
  "args": {
    "BASE_IMAGE": "your-image-name:tag"
  }
}
```

### Add Custom Extensions

Add to the `extensions` array in `devcontainer.json`:

```json
"extensions": [
  "ms-vscode.cpptools",
  // Add your extensions here
  "your.extension-id"
]
```

### Change ROS_DOMAIN_ID

Set in `devcontainer.json`:

```json
"containerEnv": {
  "ROS_DOMAIN_ID": "your-domain-id"
}
```

Or set in your host environment before opening the container:

```bash
export ROS_DOMAIN_ID=10
code .
```

## Troubleshooting

### Container fails to start

- Ensure Docker is running: `sudo systemctl status docker`
- Check image exists: `docker images | grep ros2-jazzy-dev`
- Rebuild: `F1` → "Dev Containers: Rebuild Container"

### GUI applications don't display

- On X11: Run `xhost +local:` on the host
- On Wayland: Ensure `WAYLAND_DISPLAY` is set
- Check `DISPLAY` environment variable: `echo $DISPLAY`

### GPU not detected

- NVIDIA: Verify `nvidia-smi` works on host
- Check Docker daemon.json configuration
- Run `./detect-gpu.sh` to diagnose

### Permission errors

The container runs as root by default. If you encounter permission issues:

1. Files created in `/workspace` may be owned by root
2. Fix with: `sudo chown -R $USER:$USER /workspace`

## Comparison with Standalone Scripts

| Feature | Dev Container | Standalone Scripts |
|---------|--------------|-------------------|
| IDE Integration | ✅ Automatic | Manual |
| Workspace Setup | ✅ Automatic | Manual |
| Team Sharing | ✅ Easy | Share scripts |
| Editor Choice | ❌ VSCode only | ✅ Any editor |
| Podman Support | ❌ Docker only | ✅ Both |
| Flexibility | Project-based | Ad-hoc containers |

## Resources

- [VSCode Dev Containers Documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [ROS2 Dev Container Guide](https://docs.ros.org/en/jazzy/How-To-Guides/Setup-ROS-2-with-VSCode-and-Docker-Container.html)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
