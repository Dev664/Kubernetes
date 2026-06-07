# Install Metrics Server

kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

**KIND/Local Clusters me Common Issue**
KIND (aur Minikube) jaise local clusters me Metrics Server default TLS settings ke wajah se API call reject kar deta hai.
Isko fix karne ke liye hume thoda modify karna hota hai.
Command chala kar edit kar Metrics Server deployment:

**kubectl edit deployment metrics-server -n kube-system**
Update these lines under "args:"
- --kubelet-insecure-tls
- --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP


# Patch for KIND/Minikube
kubectl apply -f metrics-server-patch.yml

# Verify
kubectl top nodes
kubectl top pods -A


