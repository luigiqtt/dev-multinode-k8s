terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    random = {
      source  = "hashicorp/random"
    }
  }
}

# Configure the Libvirt provider
provider "libvirt" {
  uri = "qemu:///system"
}

# Base OS image to use to create the cluster
resource "libvirt_volume" "fcos-qcow2" {
  name   = "FCOS.qcow2"
  pool   = "default"
  source = var.image_path
  format = "qcow2"
}

# Volume to attach to the Control Plane domain as main disk
resource "libvirt_volume" "control-plane" {
  name           = "control-plane.qcow2"
  size           = var.nodes["control-plane"]["disk_size"]
  base_volume_id = libvirt_volume.fcos-qcow2.id
}

# Volumes to attach to the workers domains as main disk
resource "libvirt_volume" "worker" {
  count          = var.workers_count
  name           = "worker${count.index}.qcow2"
  size           = var.nodes["worker${count.index}"]["disk_size"]
  base_volume_id = libvirt_volume.fcos-qcow2.id
}
# Generate random wwns for the workers disks
resource "random_id" "wwn" {
  count       = var.workers_count
  byte_length = 8
}

# Cluster network definition
resource "libvirt_network" "k8s_network" {
  name      = var.k8s_network_name
  mode      = "nat"
  addresses = [var.k8s_subnet]
  # Start the network on host boot up
  autostart = true
}

# Convert YAML Butane (.bu) files into JSON Ignition (.ign) config files
resource "null_resource" "ignition_config" {
  for_each = var.nodes
  provisioner "local-exec" {
    command = "butane --pretty --strict ./config/${each.key}.bu > ./config/${each.key}.ign"
  }
}

#
# Control Plane node
#
resource "libvirt_ignition" "control-plane" {
  depends_on = [null_resource.ignition_config]
  name       = "control-plane.ign"
  content    = "./config/control-plane.ign"
}
resource "libvirt_domain" "control-plane_node" {
  name            = var.nodes["control-plane"]["name"]
  vcpu            = var.nodes["control-plane"]["vcpu"]
  memory          = var.nodes["control-plane"]["memory"]
  autostart       = var.autostart
  coreos_ignition = libvirt_ignition.control-plane.id
  disk {
    volume_id = libvirt_volume.control-plane.id
    scsi      = "true"
    wwn       = "05abcd8903c17091"
  }
  network_interface {
    network_id = libvirt_network.k8s_network.id
    addresses  = [var.nodes["control-plane"]["ip_address"]]
  }
  provisioner "remote-exec" {
    inline = [
      "while pgrep -f 'rpm-ostree deploy' > /dev/null; do sleep 1; done",
      "sudo rpm-ostree install kubelet kubeadm kubectl cri-o",
      "sudo systemctl reboot"
    ]
    on_failure = continue
    connection {
      type     = "ssh"
      user     = var.admin_user
      password = var.admin_password
      host     = var.nodes["control-plane"]["ip_address"]
    }
  }
}

#
# Worker nodes
#
resource "libvirt_ignition" "worker" {
  count      = var.workers_count
  depends_on = [null_resource.ignition_config]
  name       = "worker${count.index}.ign"
  content    = "./config/worker${count.index}.ign"
}
resource "libvirt_domain" "worker_node" {
  count           = var.workers_count
  name            = var.nodes["worker${count.index}"]["name"]
  vcpu            = var.nodes["worker${count.index}"]["vcpu"]
  memory          = var.nodes["worker${count.index}"]["memory"]
  autostart       = var.autostart
  coreos_ignition = libvirt_ignition.worker[count.index].id
  disk {
    volume_id = libvirt_volume.worker[count.index].id
    scsi      = "true"
    wwn       = random_id.wwn[count.index].hex
  }
  network_interface {
    network_id = libvirt_network.k8s_network.id
    addresses  = [var.nodes["worker${count.index}"]["ip_address"]]
  }
  provisioner "remote-exec" {
    inline = [
      "while pgrep -f 'rpm-ostree deploy' > /dev/null; do sleep 1; done",
      "sudo rpm-ostree install kubelet kubeadm cri-o",
      "sudo systemctl reboot"
    ]
    on_failure = continue
    connection {
      type     = "ssh"
      user     = var.admin_user
      password = var.admin_password
      host     = var.nodes["worker${count.index}"]["ip_address"]
    }
  }
}
