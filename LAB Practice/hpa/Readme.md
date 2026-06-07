# Kubernetes HPA Demo – Commands

## 1. Install Metrics Server
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

```

kubectl edit deployment metrics-server -n kube-system Update these lines under "args:"

```
kubectl patch deployment metrics-server \
-n kube-system \
--type=json \
-p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

```
restart:
kubectl rollout restart deployment metrics-server -n kube-system

Check pod status
kubectl get pods -n kube-system -w

Wait until:
metrics-server-xxxxx   1/1   Running
```

kubectl top nodes

kubectl top pods -A
```

## 2. Create Namespaces
kubectl apply -f notes-namespace.yml

kubectl apply -f load-namespace.yml

## 3. Deploy Notes App
kubectl apply -f notes-app.yml

kubectl apply -f notes-service.yml

kubectl get pods -n notes-ns

## 4. Apply HPA
kubectl apply -f hpa.yml

kubectl get hpa -n notes-ns

## 5. Deploy Load Generator
kubectl apply -f load-generator.yml

## 6. Watch Scaling
watch -n 5 kubectl get hpa,pods -n notes-ns
kubectl top pods -n notes-ns

## 7. Cleanup
kubectl delete ns notes-ns

kubectl delete ns load-ns
