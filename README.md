Multi-node K8s cluster on a single Linux machine with Terraform, libvirt and Fedora CoreOS <!-- omit in toc -->
===

Using the files in this repository it is possibile to easily setup a multi-node Kubernetes cluster for development/testing/learning purposes on a single Linux machine.

They have been tested on Fedora 37, but should work also on other recent Linux distributions (the only difference is the installation of the required software).

- [Requirements](#requirements)
- [Configuration](#configuration)
  - [Terraform variables](#terraform-variables)
  - [Butane files](#butane-files)
- [Cluster creation](#cluster-creation)
- [Add/remove worker nodes](#addremove-worker-nodes)
  - [Remove worker nodes](#remove-worker-nodes)
  - [Add new worker nodes](#add-new-worker-nodes)
- [Nodes configuration updates](#nodes-configuration-updates)
- [Control the cluster from the host machine](#control-the-cluster-from-the-host-machine)
- [Deploy an NGINX Ingress Controller](#deploy-an-nginx-ingress-controller)
- [Deploy and access the Dashboard](#deploy-and-access-the-dashboard)
- [Destroy the cluster](#destroy-the-cluster)
- [References](#references)

Requirements
---

On the host Linux machine the following software must be installed:

* [**libvirt library**](https://libvirt.org/): on Fedora, the installation (mandatory and default packages) can be done using the following command (see: https://docs.fedoraproject.org/en-US/quick-docs/getting-started-with-virtualization/):

    ```bash
        sudo dnf install @virtualization
    ```
* [**Terraform**](https://www.terraform.io/): on Fedora, the installation can be done using the following command (see: https://developer.hashicorp.com/terraform/downloads?product_intent=terraform):
    ```bash
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
        sudo dnf -y install terraform
    ```
* [**Butane**](https://coreos.github.io/butane/): on Fedora, the installation can be done using the following command:
    ```bash
        sudo dnf install -y butane
    ```

With the above software installed, clone this repository:
```bash
git clone https://github.com/luigiqtt/dev-multinode-k8s.git
```
This will create a folder named ***dev-multinode-k8s*** containing the following files:

*   **k8s.tf**:  is the Terraform file describing the K8s cluster;
*   **variables.tf**: contains the declaration of the variables used;
*   **k8s.auto.tfvars**: contains the values of the variables used to create the cluster (see the [*Configuration*](#configuration) chapter);
*   **k8s.secret.auto.tfvars**: contains the password that will be used to access the nodes of the cluster via SSH (see the [*Configuration*](#configuration) chapter). Note that this file is included only as an example, but, since it contains potentially sensitive information, it should not be stored in version control systems;
*   **Butane** (.bu) files in the **config** folder (see the [*Configuration*](#configuration) chapter);
*   **create.sh**: simple example script to execute all the steps required for the creation of the cluster (see the [*Cluster creation*](#cluster-creation) chapter).

Another prerequisite is an extracted *qcow2* image of [**Fedora CoreOS**](https://getfedora.org/en/coreos?stream=stable), that can be downloaded from the [Fedora CoreOS official website](https://getfedora.org/en/coreos/download?tab=metal_virtualized&stream=stable&arch=x86_64). Download the QEMU version and uncompress the .xz file. The uncompressed file must be put in the **images** directory that is present in the cloned repository.

**Tip**: before creating a new cluster, download the latest version of Fedora CoreOS. This will speed up the deploy process (when Fedora CoreOS starts up searches for updates and, if some are available, it installs them).

Configuration
---

The files in the repository can be directly used updating only the name of the downloaded *Fedora CoreOS* image in the **k8s.auto.tfvars**. The created cluster will have one *Control Plane* node and two *worker* nodes. The [*Container Runtime Interface* (CRI)](https://kubernetes.io/docs/concepts/architecture/cri/) implementation is [cri-o](https://cri-o.io/) while the [*Container Network Interface* (CNI)](https://www.cni.dev/) provider is [Kube-Router](https://www.kube-router.io/). 

If you want to modify the example configuration you can act on the *Terraform variables* and/or the *Butane files*.

### Terraform variables
Most of the configuration parameters are containd in the **k8s.auto.tfvars** and **k8s.secret.auto.tfvars** files. Modify them according to your requirements (see the **variables.tf** file for a dscription of the declared variables).

The **k8s.secret.auto.tfvars** contains only the password of the admin user of all the nodes. It is used by Terraform to install the required software on the nodes and **must match** the ***password_hash*** configured in the Butane files of the nodes (see below).

If you want to change the number of worker nodes of the cluster see the [*Add/remove worker nodes*](#addremove-worker-nodes) chapter.

### Butane files
The configuration of the virtual machines (nodes of the cluster) that is applied at the first boot is defined using [**Butane**](https://docs.fedoraproject.org/en-US/fedora-coreos/producing-ign/) YAML-formatted files. For each VM there must be a Butane file in the ***config*** directory. Each file will be automatically converted by Terraform into an ***Ignition*** JSON file (.ign).

The main parameters in the Butane files that can be safely changed before applying the configuration with Terraform are the following:

* **hostname** of the node: if desired, change the content of the file **/etc/hostname**; 
* **password_hash**: hash of the password that can be used to access the cluster nodes via SSH. The content of this field can be computed using the following command (the password must be the one configured in the **k8s.secret.auto.tfvars file**):

    ```bash
        mkpasswd --method=yescrypt
    ```
* **ssh_authorized_keys** (optional): list of the SSH keys that can be used to access the cluster nodes via SSH. These parameter is optional, but it is advisable to set it in order to speed up the access to the nodes of the cluster (see: https://www.ssh.com/academy/ssh/authorized-key);
* **podSubnet** (only in the **clusterconfig.yml** file definition present in the **control-plane.bu** file): subnet used by pods. Modify it if another set of IP addresses is desired for the pods.

Of course, you can change also the rest of the files in order, for example, to add other useful files/scripts to the nodes, configure services, modify the initialization scripts, etc..

Cluster creation
---

To create a new multi-node K8s cluster on your Linux machine the required steps are the following:

1. **Initialize Terraform**:
    ```bash
        cd dev-multinode-k8s
        terraform init
    ```
2. **Modify the configuration** files if needed (see the [previous](#configuration) chapter);
3. **Apply the configuration** with Terraform:
    ```bash
        sudo terraform apply
    ```
4. **Wait** some seconds after the end of the apply command execution in order to give the virtual machines the time to restart;
5. **Initialize the *Control Plane* node**: log in to the *Control Plane* node as the admin user and execute the script **setup/init.sh**:
    ```bash
        ssh admin@192.168.40.162
        cd setup
        ./init.sh
    ```
6. **Copy the *join command*** from the script execution log on the Control Plane node. The following is an example of *join command*:
    ```bash
    kubeadm join 192.168.40.162:6443 --token dixcvq.c5l1ogpz2ttymfs2 \
        --discovery-token-ca-cert-hash sha256:ae1f5bdd5b8521f8ee842d3efc6796a83c755276d88dd340ab5f8f98a41fb968
    ```
7. **Initialize the *worker* nodes and add them to the cluster**: log in to each worker node as the admin user and execute the script **setup/init.sh**:
    ```bash
        ssh admin@192.168.40.xxx
        cd setup
        ./init.sh
    ```
    Then execute with sudo the *join command* copied at the previous step to add the worker to the cluster. For example:

    ```bash
    sudo kubeadm join 192.168.40.162:6443 --token dixcvq.c5l1ogpz2ttymfs2 \
        --discovery-token-ca-cert-hash sha256:ae1f5bdd5b8521f8ee842d3efc6796a83c755276d88dd340ab5f8f98a41fb968
    ```
8. **That's it!** Your multi-node K8s cluster is up and running! You can check the list of the nodes logging in to the *Control Plane* node and executing the command:
    ```bash
    kubectl get nodes

    NAME                STATUS   ROLES           AGE     VERSION
    k8s-control-plane   Ready    control-plane   2m23s   v1.26.0
    k8s-worker0         Ready    <none>          112s    v1.26.0
    k8s-worker1         Ready    <none>          81s     v1.26.0

    (or
        kubectl get nodes -o wide
     to get more details)
    ```

**Note 1**: if necessary, the *join command* required to add a node to the cluster can be obtained on the *Control Plane* node using the following command:
```bash
kubeadm token create --print-join-command
```

**Note 2**: the files in the repository include a simple example script named ***create.sh*** that executes all the steps described above automatically (except for the Terraform initialization command).

Add/remove worker nodes
---
To add or remove worker nodes is quite easy and can be done following the steps described below.

### Remove worker nodes

Modify the **worker_count** parameter in the **k8s.auto.tfvars** file, setting a smaller value, then run the Terraform apply command:
```bash
sudo terraform apply
```
Note that in this way the virtual machines corresponding to the removed nodes will be destroyed and this could have some unwanted impacts on the running pods. See [***Safely Drain a Node***](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-node/) for recommendations on how to properly remove a node from the cluster.

### Add new worker nodes

Modify the **worker_count** parameter in the **k8s.auto.tfvars** file, setting an higher value. If the value is greater than 3, you need to add the required **vms** configurations in the same file (e.g.: worker3, worker4, ecc.) and create the Butane files in the config folder for each worker with index greater than 2. In fact, in the repository there are only 3 Butane files for a maximum of 3 workers. If, for example, you want to create a cluster with 5 worker nodes, you will have to create the files **worker3.bu** and **worker4.bu** (note that the names of the files must have the format **workerN.bu**). Such files can have the same content as the others with only the Hostname changed.

Now you can run the Terraform *apply* command:
```bash
sudo terraform apply
```
When the command execution terminates, follow the same steps described in the [*Cluster creation*](#cluster-creation) chapter to initialize and add the new worker nodes. To get the *join command* required to add the new nodes to the cluster, execute the following command on the *Control Plane* node:
```bash
kubeadm token create --print-join-command
```
Nodes configuration updates
---
There are two ways to modify the nodes configuration parameters (e.g.: *vcpu* number, *memory*, etc.). The first is using Terraform and the second is using libvirt (using the **Virtual Machine Manager** or the **virsh** command).

The preferred way should be Terraform in order to keep the configuration files and the actual deployed infrastructure aligned and it is quite simple: modify the parameters in the configuration files, then execute the usual *apply* command (terraform apply ...).

Unfortunately, for some types of modifications, applying the new configuration with Terraform replaces the old virtual machines with new ones and this is not a good thing in that actually damages your cluster (you need to reinitialize one or more nodes). This is, at least in some cases, probably due to a limitation of the current [Terraform provider for libvirt](https://registry.terraform.io/providers/dmacvicar/libvirt/0.7.0) that may change in future versions.

That said, the advice is to try Terraform first checking the planned modifications with the command:
```bash
sudo terraform plan
```
If in the plan the number of destroyed resources is 0, it is safe to proceed and apply the new configuration. If such number is > 0, use libvirt.

For example, if you try to change the number of **vcpus** or the **memory** of a node (in the file **k8s.auto.tfvars**) you will see that the virtual machine associated to that node would be replaced, damaging your cluster. Then, for this kind of modifications, use the **Virtual Machine Manager** or the **virsh** command. You will probably need to restart the node, but your cluster will continue to work properly.

Another example is the **automatic startup** of the nodes. With the default configuration in the repository, the nodes of the cluster start automatically when the host machine boots up. If you want to change this behaviour you can modify the **autostart** parameter (in the file **k8s.auto.tfvars**) setting it to false. This update can be safely done with Terraform in that no resource will be destroyed. When the automatic startup of the nodes is disabled you can startup them simply with the usual Terraform *apply* command or using libvirt.

Control the cluster from the host machine
---
If you want to control the cluster from the host machine, you should install the command-line tool **kubectl** and then copy the **.kube/config** file of the *Control Plane* node in the **.kube** directory (create it if not already present) in your home directory. The installation of the **kubectl** tool can be easily done [using **snap**](https://snapcraft.io/kubectl).

Deploy an NGINX Ingress Controller
---

To deploy an [**NGINX Ingress Controller**](https://github.com/kubernetes/ingress-nginx) use the following command (see: https://kubernetes.github.io/ingress-nginx/deploy/):
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.5.1/deploy/static/provider/cloud/deploy.yaml
```
The status of the controller can be checked with the following command:
```bash
kubectl describe -n ingress-nginx deploy/ingress-nginx-controller
```
Of course, other *Ingress Controllers* can be installed as needed.

Deploy and access the Dashboard
---

To deploy and access the Kubernetes Dashboard see: https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/.

Destroy the cluster
---
To destroy the cluster removing all the created virtual machines, execute the following command:
```bash
sudo terraform destroy
```

References
---
-   [Creating a Kubernetes Cluster with Fedora CoreOS 36](https://dev.to/carminezacc/creating-a-kubernetes-cluster-with-fedora-coreos-36-j17);
-   [Fedora CoreOS - Basic Kubernetes Setup](https://www.matthiaspreu.com/posts/fedora-coreos-kubernetes-basic-setup/);
-   [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/).