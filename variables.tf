#
# Variable declarations
#
variable "workers_count" {
  description = "Number of worker nodes"
  type        = number
}
variable "admin_user" {
  description = "Nodes admin username"
  type        = string
}
variable "admin_password" {
  description = "Nodes admin password"
  type        = string
  sensitive   = true
}
variable "image_path" {
  description = "Fedora Core OS image file path (.qcow2)"
  type        = string
}
variable "k8s_network_name" {
  description = "Cluster network name used by libvirt"
  type        = string
}
variable "k8s_subnet" {
  description = "Cluster subnet in CIDR notation"
  type        = string
}
variable "nodes" {
  type = map(map(string))
}
variable "autostart" {
  description = "Start the node on host boot up"
  type        = bool
}
