terraform {
  required_providers {

    proxmox = {
      source  = "bpg/proxmox"
      version = "0.78.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

provider "proxmox" {
  endpoint = "https://proxmox.cecyourtech.ch"
  insecure = true
  api_token = "terraform@pve!API-Token=947b424e-ed92-48a0-a302-da8f1f8c18e0"
}

################################# SSH Keys #################################

resource "tls_private_key" "pihole_private_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

################################# Output SSH Keys #################################

output "pihole_public_key" {
  value = tls_private_key.pihole_private_key.public_key_openssh
}

output "pihole_private_key" {
  value = tls_private_key.pihole_private_key.private_key_pem
  sensitive = true
}

################################# SSH Connections und Setup #################################

resource "null_resource" "install_pihole" {
  depends_on = [proxmox_virtual_environment_container.PI-Hole]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = "192.168.1.170"
      user        = "root"
      private_key = tls_private_key.pihole_private_key.private_key_openssh
      ##password    = "root1"
      timeout     = "5m"
    }

    inline = [
      "apt install curl -y",
      "mkdir /etc/pihole/",
      "echo 'server=192.168.1.1\nPIHOLE_INTERFACE=vmbr0\nIPV4_ADDRESS=192.168.1.170/24\nIPV6_ADDRESS=\nQUERY_LOGGING=true\nINSTALL_WEB=true\nDNSMASQ_LISTENING=single\nPIHOLE_DNS_1=8.8.8.8\nPIHOLE_DNS_2=8.8.1.1\nPIHOLE_DNS_3=\nPIHOLE_DNS_4=\nDNS_FQDN_REQUIRED=true\nDNS_BOGUS_PRIV=true\nDNSSEC=false\nTEMPERATUREUNIT=C\nWEBUIBOXEDLAYOUT=traditional\nAPI_EXCLUDE_DOMAINS=\nAPI_EXCLUDE_CLIENTS=\nAPI_QUERY_LOG_SHOW=all\nAPI_PRIVACY_MODE=false' >> /etc/pihole/setupVars.conf",
      "curl -L https://install.pi-hole.net | bash /dev/stdin --unattended",
      "pihole setpassword 'Password'"
    ]
  }
}

################################# ISO und LXC download #################################

resource "proxmox_virtual_environment_download_file" "PiHole-LXC" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "proxmox"
  url          = "http://download.proxmox.com/images/system/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
}

################################# Server VMs #################################

resource "proxmox_virtual_environment_vm" "WinServer1"{
  name = "WinClient1"
  node_name = "proxmox"
  vm_id = "801"

initialization {
}
  agent {
    enabled = false
  }
  cpu {
    cores = 4
    type = "host"
  }
  memory {
    dedicated = 4096
    floating = 4096
  }
  disk {
    datastore_id = "local-lvm"
    interface = "scsi0"
  }
  network_device {
    bridge = "vmbr0"
  }
  cdrom {
    file_id = "local:iso/Windows_C.iso"
  }
}

################################# Client VMs #################################

########## User 01 ##########

resource "proxmox_virtual_environment_vm" "WinClient01"{
  name = "WinClient01"
  node_name = "proxmox"
  vm_id = "901"

initialization {
}
  agent {
    enabled = false
  }
  cpu {
    cores = 4
    type = "host"
  }
  memory {
    dedicated = 4096
    floating = 4096
  }
  disk {
    datastore_id = "local-lvm"
    interface = "scsi0"
    size = 60
  }
  network_device {
    bridge = "vmbr0"
  }
  cdrom {
    file_id = "local:iso/Windows_C.iso"
  }
}

########## User 02 ##########

resource "proxmox_virtual_environment_vm" "WinClient02"{
  name = "WinClient02"
  node_name = "proxmox"
  vm_id = "902"

initialization {
}
  agent {
    enabled = false
  }
  cpu {
    cores = 4
    type = "host"
  }
  memory {
    dedicated = 4096
    floating = 4096
  }
  disk {
    datastore_id = "local-lvm"
    interface = "scsi0"
    size = 60
  }
  network_device {
    bridge = "vmbr0"
  }
  cdrom {
    file_id = "local:iso/Windows_C.iso"
  }
}

########## User 03 ##########

resource "proxmox_virtual_environment_vm" "WinClient01"{
  name = "WinClient03"
  node_name = "proxmox"
  vm_id = "903"

initialization {
}
  agent {
    enabled = false
  }
  cpu {
    cores = 4
    type = "host"
  }
  memory {
    dedicated = 4096
    floating = 4096
  }
  disk {
    datastore_id = "local-lvm"
    interface = "scsi0"
    size = 60
  }
  network_device {
    bridge = "vmbr0"
  }
  cdrom {
    file_id = "local:iso/Windows_C.iso"
  }
}

################################# LXC Container #################################

resource "proxmox_virtual_environment_container" "PI-Hole" {

  depends_on = [proxmox_virtual_environment_download_file.PiHole-LXC]
  node_name    = "proxmox"
  vm_id        = 601
  unprivileged = true
  network_interface {
    name = "vmbr0"
  }
  disk {
    datastore_id = "local-lvm"
    size         = 4
  }
  operating_system {
    template_file_id = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
    type             = "ubuntu"
  }
  initialization {
    user_account {
    keys = [trimspace(tls_private_key.pihole_private_key.public_key_openssh)]
    password = "root1"
    }
    ip_config {
      ipv4 {
        address = "192.168.1.170/24"
        gateway = "192.168.1.1"
      }
    }
  }
}


