workers_count    = 2
admin_user       = "admin"
image_path       = "./images/fedora-coreos-41.20241122.3.0-qemu.x86_64.qcow2"
k8s_network_name = "k8snet"
k8s_subnet       = "192.168.40.160/27"
autostart        = true
nodes = {
  control-plane = {
    name       = "k8s-control-plane",
    ip_address = "192.168.40.162",
    vcpu       = 2,
    memory     = 2048,
    disk_size  = 10737418240
  },
  worker0 = {
    name       = "k8s-worker0",
    ip_address = "192.168.40.163",
    vcpu       = 4,
    memory     = 4096,
    disk_size  = 21474836480
  },
  worker1 = {
    name       = "k8s-worker1",
    ip_address = "192.168.40.164",
    vcpu       = 4,
    memory     = 4096,
    disk_size  = 21474836480
  },
  worker2 = {
    name       = "k8s-worker2",
    ip_address = "192.168.40.165",
    vcpu       = 4,
    memory     = 4096,
    disk_size  = 21474836480
  }
}
