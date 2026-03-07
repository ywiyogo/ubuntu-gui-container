# Disk Space Management

Container images and data can consume significant disk space over time. The build scripts automatically detect and display your storage location. Here's how to monitor and clean up.

For optimization details, see [Dockerfile Optimization Guide](optimization.md).

## Docker

### Check Storage Location

```bash
docker info --format '{{.DockerRootDir}}'
```

### Check Disk Usage

```bash
docker system df       # Summary
docker system df -v    # Detailed
```

### Cleanup Commands

```bash
docker system prune           # Remove stopped containers, unused networks, dangling images
docker system prune -a        # Also remove unused images (use with caution)
docker volume prune           # Remove unused volumes
docker image prune -a         # Remove all unused images
docker container prune        # Remove all stopped containers
```

## Podman

### Check Storage Location

```bash
podman info --format '{{.Store.GraphRoot}}'
```

### Check Disk Usage

```bash
podman system df       # Summary
podman system df -v    # Detailed
```

### Cleanup Commands

```bash
podman system prune           # Remove stopped containers, unused images
podman system prune -a        # Remove all unused images
podman volume prune           # Remove unused volumes
podman image prune            # Remove unused images
podman container prune        # Remove all stopped containers
```

## Typical Disk Usage

| Component               | Size Range |
| ----------------------- | ---------- |
| Base Ubuntu 24.04 image | ~1-2 GB    |
| ROS2 Jazzy Desktop      | ~3-5 GB    |
| ROS2 + Gazebo + Nav2    | ~6-10 GB   |
| Full dev environment    | ~10-15 GB  |

## Moving Docker Data Directory

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

## Best Practices

1. **Regular Cleanup**: Run `docker system prune` or `podman system prune` weekly
2. **Monitor Usage**: Use `system df` commands to track disk usage
3. **Remove Unused Images**: Use `-a` flag to remove all unused images (be careful with CI/CD caches)
4. **Volume Management**: Regularly prune unused volumes
5. **Alternative Storage**: Consider moving data directory to larger partition

## Quick Reference

| Task | Docker | Podman |
|------|--------|--------|
| Check disk usage | `docker system df` | `podman system df` |
| Clean all unused | `docker system prune -a` | `podman system prune -a` |
| Remove volumes | `docker volume prune` | `podman volume prune` |
| Remove images | `docker image prune -a` | `podman image prune` |
| Storage location | `docker info --format '{{.DockerRootDir}}'` | `podman info --format '{{.Store.GraphRoot}}'` |
