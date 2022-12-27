#!/bin/bash
#
# Example script that executes automatically all the required steps to create the cluster
#

control_plane_ip="192.168.40.162"
worker_ips=(
    "192.168.40.163"
    "192.168.40.164"
    #    "192.168.40.165"
)

# Create the cluster nodes
sudo terraform apply -auto-approve
echo "Waiting for virtual machines restart ..."
sleep 20

# Initialize the Control Plane node
ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null" admin@$control_plane_ip "cd setup && ./init.sh"

# Get the join command from the Control Plane node
jc=$(ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null" admin@$control_plane_ip "kubeadm token create --print-join-command")

# Initialize the worker nodes
for i in "${worker_ips[@]}"; do
    ssh -o "StrictHostKeyChecking no" -o "UserKnownHostsFile=/dev/null" admin@$i "cd setup && ./init.sh && sudo ${jc}"
done

echo "Kubernetes cluster creation complete!"
