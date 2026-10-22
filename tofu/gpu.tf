# NVIDIA device files on the host (driver 595.91.07, nvidia-persistenced + udev create them at boot).
# Containers that use the GPU pass these through by path (Proxmox device passthrough), not by major number:
# nvidia-uvm's major number is dynamic and can change between boots.
locals {
  nvidia_devices = [
    "/dev/nvidia0",
    "/dev/nvidiactl",
    "/dev/nvidia-uvm",
    "/dev/nvidia-uvm-tools",
    "/dev/nvidia-modeset",
  ]
}
