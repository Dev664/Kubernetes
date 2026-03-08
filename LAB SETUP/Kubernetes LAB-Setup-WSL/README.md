# Kubernetes LAB -Setup in WSL with KIND 

## KIND (Kubernetes IN Docker)
KIND (Kubernetes IN Docker) is a tool that allows you to run a local Kubernetes cluster using Docker containers instead of real servers. It is mainly used for learning, testing, and development.
KIND creates Kubernetes nodes as Docker containers on your laptop. This allows you to quickly create and destroy Kubernetes clusters without needing multiple machines.

# Step 1 : Configure WSL in your laptop
  

# Step 2: Setup WSL for Docker Desktop in your Laptop 

### Install Docker Desktop in your laptop

Download from: https://www.docker.com/products/docker-desktop

During installation: Select Use WSL 2 instead of Hyper-V 

Restart system if prompted. 

Enable WSL Integration :  Open Docker Desktop → Settings → Resources → WSL Integration 

Verify Installation  : WSL terminal
docker --version 
Then test:  docker run hello-world 

Once WSL and OL  setup is done . SETUP KIND  

# Step 2: SETUP KIND
## Install kubectl 
Inside WSL terminal Oracle Linux: 
```
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" 
  chmod +x kubectl 
  sudo mv kubectl /usr/local/bin/ 
  Verify: kubectl version --client
```

## Install KIND 
```
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 
  chmod +x kind 
  sudo mv kind /usr/local/bin/kind
```

## Create Cluster to test 

Single-node cluster: 
```
kind create cluster 
```
Verify : 
```
kubectl get nodes 
```
This will Create Docker containers that behave like Kubernetes nodes . in this example we have created a single container where both the control plane and the one worker node is running .

## verify the Nodes (container) with below command from your terminal 
```
  Verify: kubectl get nodes
```

