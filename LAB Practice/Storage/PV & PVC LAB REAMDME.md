# LAB K8s Storage - PV & PVC 

## lets setup the PV, PVS, and craete a Pod 

### FIrst create the below defination yaml files .
1. pv.yaml
2. pvs.yaml
3. pod.yaml

### now create the  PV, PVS
```
kubectl apply -f pv.yaml
kubectl apply -f pvs.yaml


```
### verify the pv, pvs

```
kubectl get pv
kubectl get pvs

or

kubectl get pv,pvs

```
you  should see the status bound . 

### craete pod and verify 

```
kubectl apply -f pod.yaml
kubectl get pods
```

## Now you PV , PVS, Pod are ready , lets perform the testing 

### check the data from pod 
```
kubectl exec -it storage-pod -- cat /data/output.txt
```
 you can see one time a timestamps getting appended every 5 sec to output file 


 ### Check the data in local of your worker node 
 
SSH into worker node:
 ```
cd /data
ls
cat output.txt
```

### now lets test the persistance storage featuers 

Delet the running pod 

```
kubectl delete pod storage-pod
```

verify the data in worker node -  you can see the data write is stopped . but the data wwritten to the output file still 
present and not deleted  with pod . 
```
cat /data/output.txt
```

now start a new pod 
```
kubectl apply -f pod.yaml
```
once the pod i s start ed 

verify the data in worker node -  you can see the data write is again satrted ... 

so it will start the data write where it stopped after deleting the file .

you can also verify the data from pod it self 
```
kubectl exec -it storage-pod -- cat /data/output.txt
```




