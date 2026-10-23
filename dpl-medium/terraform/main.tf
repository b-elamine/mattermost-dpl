resource "libvirt_pool" "dpl-medium" {
  name = "dpl-medium"
  type = "dir"
  target = {
    path = "/home/belamine/Desktop/Work/projects/mattermost-dpl/vm-images-medium"
  }
}

resource "libvirt_volume" "ubuntu_base" {
  name = "ubuntu-24.04-base.qcow2"
  pool = libvirt_pool.dpl-medium.name
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

resource "libvirt_volume" "controlplane_disk" {
  count = 3
  name = "controlplane-${count.index}.qcow2"
  pool = libvirt_pool.dpl-medium.name
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

resource "libvirt_cloudinit_disk" "controlplane_cloudinit" {
  count = 3
  name = "controlplane-${count.index}-cloudinit.iso"
  meta_data = yamlencode({
    instance-id = "controlplane-${count.index}"
    local-host = "controlplane-${count.index}"
  })
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    password_hash = var.vm_user_password_hash
    ssh_public_key = file("~/.ssh/id_ed25519.pub")
  })
}

resource "libvirt_volume" "controlplane_cloudinit_vol" {
  count = 3
  name  = "controlplane-${count.index}-cloudinit-vol.iso"
  pool  = libvirt_pool.dpl-medium.name
  create = {
    content = {
      url = libvirt_cloudinit_disk.controlplane_cloudinit[count.index].path
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

resource "libvirt_domain" "controlplane" {
  count       = 3
  name        = "controlplane-${count.index}"
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 2
  type        = "kvm"
  running     = true

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
            pool   = libvirt_pool.dpl-medium.name
            volume = libvirt_volume.controlplane_disk[count.index].name
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
            pool   = libvirt_pool.dpl-medium.name
            volume = libvirt_volume.controlplane_cloudinit_vol[count.index].name
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
}


resource "libvirt_volume" "worker_disk" {
  count = 6
  name = "worker-${count.index}.qcow2"
  pool = libvirt_pool.dpl-medium.name
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

resource "libvirt_cloudinit_disk" "worker_cloudinit" {
  count = 6
  name = "worker-${count.index}-cloudinit.iso"
  meta_data = yamlencode({
    instance_id = "worker-${count.index}"
    local-hostname = "worker-${count.index}"
  })
  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    password_hash = var.vm_user_password_hash
    ssh_public_key = file("~/.ssh/id_ed25519.pub")
  })
}

resource "libvirt_volume" "worker_cloudinit_vol" {
  count = 6
  name  = "worker-${count.index}-cloudinit-vol.iso"
  pool  = libvirt_pool.dpl-medium.name
  create = {
    content = {
      url = libvirt_cloudinit_disk.worker_cloudinit[count.index].path
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

resource "libvirt_domain" "worker" {
  count       = 6
  name        = "worker-${count.index}"
  memory      = 2048
  memory_unit = "MiB"
  vcpu        = 2
  type        = "kvm"
  running     = true

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
            pool   = libvirt_pool.dpl-medium.name
            volume = libvirt_volume.worker_disk[count.index].name
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
            pool   = libvirt_pool.dpl-medium.name
            volume = libvirt_volume.worker_cloudinit_vol[count.index].name
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
}
