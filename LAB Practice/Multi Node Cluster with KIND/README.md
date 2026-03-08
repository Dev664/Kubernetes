# Now we want to create a cluster as we have seen in the Architectural digrame  with 2 worker node  and 1 control plane .
# This will be done with KIND 

![Uploading image.png…]()


## If you are doing the LAB on the same node  where you have craeted the single node cluster earlier clean up first :

 Check Existing Cluster  :  
 ```
 kind get clusters
```
 Delete Existing Cluster : 
 ```
 kind delete cluster  
 or  
 kind delete cluster --name kind 
```

## Create Multi-Node Config File: 
vi kind-multi.yaml 
```
kind: Cluster 
apiVersion: kind.x-k8s.io/v1alpha4 
name: multi-cluster 
nodes: 
- role: control-plane 
- role: worker 
- role: worker 
```
## Create the Multi-Node Cluster 
```
kind create cluster --config kind-multi.yaml 
```
## Verify Nodes 
```
kubectl get nodes 
```
## heck Docker Containers  
```
docker ps  
```

##  This will create the below things 

KIND created: 
3 Docker containers 
Installed Kubernetes components inside them 
Connected them via a virtual network 
Installed CNI plugin 
Installed default storage class 

## You now have a real 3-node cluster running inside Docker. 

 

 For Lab Practice You Can Now Test 

Check node roles 

kubectl get nodes -o wide 

Deploy a test app 

kubectl create deployment nginx --image=nginx 
kubectl scale deployment nginx --replicas=2 

Check pod distribution 

kubectl get pods -o wide 

 
