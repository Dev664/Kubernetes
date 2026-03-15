# Kubernetes LAB -Setup in EC2 instance with KIND 

## STEP 1 — Launch EC2 

Basic Requirement :

  Minimum EC2 Requirements for KIND 
  Minimum (for testing) 
  Instance Type: t3.medium 
  vCPU: 2 
  RAM: 4 GB 
  Storage: 20 GB 

## STEP 2 — Install Docker 

````
 sudo dnf install docker -y 
 Enable Docker: 
   sudo systemctl enable docker 
   sudo systemctl start docker 
 ````
Verify: 
```
  docker ps 
  docker run hello-world
```

## STEP 3 — Install kubectl 

```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" 
chmod +x kubectl 
sudo mv kubectl /usr/local/bin/ 
Check: kubectl version --client 
```
## STEP 4 — Install KIND 
```
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 
chmod +x kind 
sudo mv kind /usr/local/bin/ 
```
Verify: 
```
kind --version 
```
## STEP 5 — Create Cluster to test 

Single-node cluster: 
```
kind create cluster

# if you want to specify a name of your cluster. If you dont speciify by default your cluster name will be KIND 

kind create cluster --name <cluster-name>
```
This will Create Docker containers that behave like Kubernetes nodes . in this example we have created a single container where both the control plane and the one worker node is running . 

## verify the Nodes (container) with below command from your terminal 
```
verify the Cluster : kind get clusters
Verify the nodes : kubectl get nodes
```

## clean up 
To delete the cluster you created . 
```
kind delete cluster
kind delete cluster --name KIND 
```


