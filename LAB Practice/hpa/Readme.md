# Kubernetes HPA Demo – Commands

## 1. Install Metrics Server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f metrics-server/metrics-server-patch.yml
kubectl top nodes
kubectl top pods -A

## 2. Create Namespaces
kubectl apply -f namespaces/notes-namespace.yml
kubectl apply -f namespaces/load-namespace.yml

## 3. Deploy Notes App
kubectl apply -f notes-app/notes-app.yml
kubectl apply -f notes-app/notes-service.yml
kubectl get pods -n notes-ns

## 4. Apply HPA
kubectl apply -f hpa/hpa.yml
kubectl get hpa -n notes-ns

## 5. Deploy Load Generator
kubectl apply -f load-generator/load-generator.yml

## 6. Watch Scaling
watch -n 5 kubectl get hpa,pods -n notes-ns
kubectl top pods -n notes-ns

## 7. Cleanup
kubectl delete ns notes-ns
kubectl delete ns load-ns
