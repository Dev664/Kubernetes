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
kubectl create namespace test
```
### With YAML file 

Create an YAML file namespace.yaml
```
apiVersion: v1
kind: Namespace
metadata:
  name: dev
```

# LAB 3
## create a pod under dev namespace with commands
Assuming we have alredy two namespace (dev & test) from above practical : 
```
kubectl run nginx --image=nginx --namespace=<insert-namespace-name-here> 
kubectl run nginx --image=nginx -n test 
```
# LAB 4 
## create a pod under dev namespace with YAML

After creating depod.yaml execute the below comamnd to craete and validate the pod under dev namespace 
```
kubectl apply -f devpod.yaml 
kubectl get pods -n dev 
kubectl get pods -n dev -o wide 
```

Create an YAML file devpod.yaml (check under Namespace)

# LAB 5 
## delete Namespace that you have created . 
you can delete a namespace even if Pods or other resources are running inside it.When you delete a namespace, Kubernetes automatically deletes all resources inside that namespace. 
```
kubectl delete namespaces <Enter the namespace-name>
kubectl delete –f  namespace.yaml 
````



