resource "libvirt_pool" "mattermost" {
  name = "mattermost-dpl"
  type = "dir"
  target = {
    path = "/home/belamine/Desktop/Work/projects/mattermost-dpl/vm-images"
  }
}

resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-24.04-base.qcow2"
  pool = libvirt_pool.mattermost.name
  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    }
  }
  target = {
    format = {
      type = "qcow2"
    }
    permissions = {
      owner = "64055"
      group = "109"
      mode = "0640"
    }
  }
}

resource "libvirt_volume" "mattermost_vm_disk" {
    name = "mattermost-vm.qcow2"
    pool = libvirt_pool.mattermost.name
    capacity = 20*1024*1024*1024
    backing_store = {
      path = libvirt_volume.ubuntu_base.path  
      format = {
        type = "qcow2"
      }
    }
    target = {
      format = {
        type = "qcow2"
      }
      permissions = {
        owner = "64055"
        group = "109"
        mode = "0640"
      }
    }
}

resource "libvirt_cloudinit_disk" "mattermost_cloudinit" {
    name = "mattermost_cloudinit.iso"
    meta_data = yamlencode({
        instance-id = "mattermost-vm"
        local-hostname="mattermost-vm"
    })
    user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
        password_hash = var.vm_user_password_hash
        ssh_public_key = file("~/.ssh/id_ed25519.pub")
    })
}

resource "libvirt_volume" "cloudinit_vol" {
  name = "mattermost-cloudinit-vol.iso"
  pool = libvirt_pool.mattermost.name
  create = {
    content = {
      url = libvirt_cloudinit_disk.mattermost_cloudinit.path
    }
  }
  target = {
    permissions = {
      owner = "64055"
      group = "109"
      mode = "0640"
    }
  }
}

resource "libvirt_domain" "mattermost_vm" {
  name        = "mattermost-vm"
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 2
  type        = "kvm"

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "q35"
    boot_devices = [{ dev = "hd" }]
  }

  devices = {
    disks = [
      {
        driver = {
            name = "qemu"
            type = "qcow2"
        }
        source = {
          volume = {
            pool   = libvirt_pool.mattermost.name
            volume = libvirt_volume.mattermost_vm_disk.name
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        device = "cdrom"
        source = {
          volume = {
            pool   = libvirt_pool.mattermost.name
            volume = libvirt_volume.cloudinit_vol.name
          }
        }
        target = {
          dev = "sdb"
          bus = "sata"
        }
      }
    ]
    interfaces = [
      {
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "default"
          }
        }
      }
    ]
  }
  running = true
}