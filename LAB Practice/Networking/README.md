# LAB : Netwroking - NodePort 

Perform this LAB after setting up the Cluster with kubeadm , in kind cluster this lab will not work . 
To make it work you need to perform additional setup , This lab will shwo you the real world seanerio . 

### step1:
Create a defination file for httpd pod deployemnt with the yaml given - httpdappdeployemnt.yaml

create the deployment 
````
kubectl apply -f httpdappdeployment.yaml

````
verify the pod and deployemnt :
```
kubectl get pods
kubectl get deployment
```
### step2

Now craete yaml file for svc , This will crate a service for nodeport 
cretae svc.yaml
```
kubectl apply -f svc.yaml
```
verify
```
kubectl get svc
kubectl get svc demoservice
````

Access the application from you rlaptop browser : 

````
http://Public Ip of your worker node:30007

````
