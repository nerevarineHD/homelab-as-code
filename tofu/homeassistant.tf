# VM 113 - Home Assistant OS. The lab's first VM: HAOS is an appliance (its own OS,
# Supervisor and updates), so it can't be an LXC and there is no Ansible role for
# inside it. Tofu owns the VM's shape; HA's own config lives in HA (+ its backups).
#
# Two NICs so nothing has to cross the IoT -> LAN deny:
#   net0  LAN (VLAN 1)  - Google Cast (Nest Hubs, Chromecast, speaker), Nest cams
#   net1  IoT (VLAN 20) - Gosund/Tuya, ESPHome plugs, Nest thermostat, Rain Bird
# HAOS takes DHCP on both; set the static IPs inside HA (Settings -> System -> Network):
#   LAN 192.168.0.26/24 (gw .1, DNS .20)   IoT 192.168.20.10/24 (no gateway, DNS .20)
# Only net0 gets a default gateway, so IoT stays a side door, not a second route out.

locals {
  # HAOS updates itself after install; this only matters for a from-scratch rebuild.
  # A rebuild normally restores VM 113 from vzdump instead (that's where HA's state is).
  haos_version = "18.3"
  haos_image   = "haos_ova-${local.haos_version}.qcow2"
}

# The image ships as .qcow2.xz, which the provider's download_file can't decompress,
# so fetch + unpack it into the `local` storage's import/ folder (content type
# "import"). Runs on pve, where tofu runs. Idempotent: skips if the file is there.
resource "terraform_data" "haos_image" {
  triggers_replace = [local.haos_version]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      dir=/var/lib/vz/import
      out="$dir/${local.haos_image}"
      [ -s "$out" ] && { echo "already present: $out"; exit 0; }
      mkdir -p "$dir"
      url="https://github.com/home-assistant/operating-system/releases/download/${local.haos_version}/${local.haos_image}.xz"
      curl -fL --retry 3 -o "$out.xz.part" "$url"
      xz -t "$out.xz.part"
      xz -dc "$out.xz.part" > "$out.part"
      mv "$out.part" "$out"
      rm -f "$out.xz.part"
      qemu-img info "$out"
    EOT
  }
}

resource "proxmox_virtual_environment_vm" "homeassistant" {
  lifecycle {
    # The import only seeds the disk at creation; after that HAOS owns it.
    ignore_changes = [disk[0].import_from]
  }

  depends_on = [terraform_data.haos_image]

  node_name   = "pve"
  vm_id       = 113
  name        = "homeassistant"
  description = "Home Assistant OS. Managed by OpenTofu (tofu/homeassistant.tf)."
  tags        = ["homeassistant", "tofu"]

  on_boot         = true
  started         = true
  stop_on_destroy = true
  machine         = "q35"
  bios            = "ovmf" # HAOS is UEFI-only
  scsi_hardware   = "virtio-scsi-single"
  tablet_device   = false

  agent {
    enabled = true # HAOS ships the QEMU guest agent
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id      = "local-zfs"
    type              = "4m"
    pre_enrolled_keys = false # no Secure Boot; HAOS's bootloader isn't signed for it
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "scsi0"
    import_from  = "local:import/${local.haos_image}"
    size         = 32
    discard      = "on"
    ssd          = true
    iothread     = true
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = "BC:24:11:CA:DE:03"
    firewall    = true
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    vlan_id     = 20
    mac_address = "BC:24:11:5C:C7:26"
    firewall    = true
  }

  startup {
    order    = 11 # after Pi-hole (1) and everything else
    up_delay = 30
  }
}
