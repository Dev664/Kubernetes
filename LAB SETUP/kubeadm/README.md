# Kubeadm setup Real-World Scenario how organizations create k8s clusters 

We will create 2 Ec2 instance and configure one as Control Plane (Master)  another as Worker Node 

## Recommended EC2 Configuration

| Role          | Instance Type | CPU    | RAM  | EBS Storahe | OS           |
| ------------- | ------------- | ------ | ---- |-------------|-----------------
| Control Plane | t3.medium     | 2 vCPU | 4 GB |  20 GB      | Amazon Linux  |
| Worker Node   | t3.medium     | 2 vCPU | 4 GB |  20 GB      | Amazon Linux  |

** Create the Ec2 instance in same security group . 
create the  Control plane and take the SG name . While creating the Worker node use the same SG 

inbound roule :

| Port        | Source                       |  Reasons                      |
| ----------- | ---------------------------- | ----------------------------- |
| 22          | 0.0.0.0/0  (keep teh default)| Secure login   from anywhere  |
| 6443        | Same SG                      | Worker → Master communication |
| 10250       | Same SG                      | Master ↔ Worker (kubelet)     |
| 30000–32767 | 0.0.0.0/0                    | Access apps from browser      |

Outbound rouls :

Keep the default one no need to moddify 

Inserting image...
```

```

## SSH to both the Nodes :
```
# On master modify the hostname to identify 
hostnamectl set-hostname k8s-master
# On worker modify the hostname to identify 
hostnamectl set-hostname k8s-worker  

```
## Disable Swap
Kubernetes does not work properly with swap enabled.
```
swapoff -a
sed -i '/swap/d' /etc/fstab
```
## Enable Kernel Modules
```
modprobe overlay
modprobe br_netfilter
```
```
vi /etc/sysctl.d/k8s.conf
add
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
```
```
sysctl --system
```
## Install Container Runtime (containerd) in both the nodes 

```
yum install -y containerd
```
```
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
```
Enable systemd cgroup
```
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```
restart and enable 
```
 systemctl restart containerd
 systemctl enable containerd
```
## Install Kubernetes Components in master and worker both 

configure the repo 
```
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
```
install kubelet kubeadm kubectl
```
 yum install -y kubelet kubeadm kubectl
```
start and enable kubelet
```
 systemctl enable kubelet
 systemctl start kubelet
```

## Initialize Control Plane (in MASTER Node)

** Copy the join command  that you will get  at the end of the below command o/p 
keep it , it will be needed in the later staps 

```
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
```

## Setup kubectl(in MASTER Node)

```
mkdir -p $HOME/.kube
 cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
 chown $(id -u):$(id -g) $HOME/.kube/config
```
## Install CNI (to enable Networking)
```
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```
## Join Worker Node to Cluster ( Run in Worker Node)

```
Execute the command that you will get  as mentuion in Initialize Control Plane (in MASTER Node)

or , incase you missed it to copy 
generate again on master:
kubeadm token create --print-join-command

or manually 
sudo kubeadm join <MASTER-IP>:6443 --token <TOKEN> \
--discovery-token-ca-cert-hash sha256:<HASH>
```
## Verify Cluster
```
kubectl get nodes
```
































