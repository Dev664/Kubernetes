# LAB 1
## Let's Work with Namespaces
First Setup the K8s cluster First with KIND - ref LAB SETUP 

make sure you have deployed pods With
```
kubectl create deployment nginx --image=nginx 
kubectl scale deployment nginx --replicas=2
```
Viewing namespaces 
```
kubectl get namespace 
kubectl get ns
```
Setting the namespace for a request 
```
kubectl run nginx --image=nginx --namespace=<namespace-name> 
kubectl get pods --namespace=<namespace-name>
```
Now check the pods in default namespace 
```
kubectl get pods --namespace=default
```
Information about a namespace :  
```
kubectl get namespaces <name> 
kubectl describe namespaces <name>
```

# LAB 2
## create a New namespace : 

### With Commands 
```
kubectl create namespace <insert-namespace-name-here> 
kubectl create namespace dev
```
### With YAML file 

Create an YAML file

