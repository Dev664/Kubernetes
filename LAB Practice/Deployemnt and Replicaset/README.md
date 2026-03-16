# Deployment  & Replicaset 

A Deployment in Kubernetes is used to manage and update Pods. It allows you to define the desired state of your application, such as how many Pods should run and which container image to use. The Deployment controller automatically creates and manages ReplicaSets to ensure the desired number of Pods are running and updates them in a controlled way. Therefore, a Deployment manages Pods indirectly through ReplicaSets. 

A ReplicaSet ensures that a specified number of identical Pods are always running. 

## LAB1
# Create Deployment Using Command
Create Deployment
```
kubectl create deployment myapp --image=nginx 
```
Check Deployment 
```
kubectl get deployments 
```
Check Pods 
```
kubectl get pods 
```
Scale Deployment using replicaset
```
kubectl scale deployment myapp --replicas=3 
Check: 
kubectl get pods -o wide
```

## LAB 2 
# Create Deployment & replicas Using YAML

craete a defination file deployment.yaml

create :
```
kubectl apply -f deployment.yaml 
```
verify 
```
kubectl get deployments 
kubectl get pods 
kubectl get rs 
```
test the replicaset  deployemnt and behaviour by deleting 2 pods
```
kubectl get pods 

kubectl delete pod <Pod name from the above command>

kubectl get pods 
```

## LAB 3 
# Rolling update and Rollback 

# Rolling update With YAML

  we are going to perform :
  Deploying  nginx:1.20 
  Updating to nginx:1.25 
  Show rollout history and versions
  Perform rollback 
  verify the history and versions 

Craete a deploymnet first  with rollingupdate.yaml
```
kubectl apply -f nginx-deploy.yaml
```
verify the version and other details of the nginx . 
```
kubectl rollout status deployment rollingupdate.yaml
kubectl get pods 
kubectl get pods –w 
kubectl describe deployment nginx-deployment 
```
 Update Deployment defination file rollingupdate.yaml with New Version of nginx:1.25

 containers: 
- name: nginx 
  image: nginx:1.25  

Apply th eupdate 
```
kubectl apply -f rollingupdate.yaml
```
Check rollout status:
```
kubectl rollout status deployment nginx-deployment 
```
check rollout history :

```
kubectl rollout history deployment nginx-deployment 
```

# LAB 4 
## Perform Rollback


Rollback to the previous version:
```
kubectl rollout undo deployment nginx-deployment 

just for the knowledge :
Rollback to Specific Revision
kubectl rollout undo deployment nginx-deployment --to-revision=1
```
Check status:
```
kubectl rollout status deployment nginx-deployment 
```
Verify image:
```
kubectl describe deployment nginx-deployment 
```


