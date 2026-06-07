# Kubernetes HPA (Horizontal Pod Autoscaler) Lab

## Objective

In this lab, we will:

* Install Metrics Server
* Deploy a sample application
* Create a Service
* Configure Horizontal Pod Autoscaler (HPA)
* Generate load on the application
* Observe automatic Pod scaling
* Clean up resources

---

# Lab Architecture

```

```

---

# Prerequisites

Verify Kubernetes cluster access:

```bash
kubectl get nodes
```

Expected:

```text
NAME                        STATUS
kind-control-plane          Ready
```

Verify cluster information:

```bash
kubectl cluster-info
```

---

# Directory Structure

```text
hpa-lab/
├── namespaces/
│   ├── notes-namespace.yml
│   └── load-namespace.yml
├── notes-app/
│   ├── notes-app.yml
│   └── notes-service.yml
├── hpa/
│   └── hpa.yml
└── load-generator/
    └── load-generator.yml
```

---

# Step 1 - Install Metrics Server

Install Metrics Server:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify installation:

```bash
kubectl get pods -n kube-system
```

Wait until Metrics Server is running:

```text
metrics-server-xxxxx   1/1   Running
```

If running on Kind and metrics are not available, patch Metrics Server:

```bash
kubectl patch deployment metrics-server \
-n kube-system \
--type=json \
-p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

Restart deployment:

```bash
kubectl rollout restart deployment metrics-server -n kube-system
```

---

# Step 2 - Verify Metrics Server

Check node metrics:

```bash
kubectl top nodes
```

Example:

```text
NAME                  CPU(cores)   CPU%
kind-control-plane    150m         8%
```

Check pod metrics:

```bash
kubectl top pods -A
```

If metrics are displayed, Metrics Server is working.

---

# Step 3 - Create Namespaces

Create Notes namespace:

```bash
kubectl apply -f namespaces/notes-namespace.yml
```

Create Load namespace:

```bash
kubectl apply -f namespaces/load-namespace.yml
```

Verify:

```bash
kubectl get ns
```

Expected:

```text
notes-ns
load-ns
```

---

# Step 4 - Deploy Notes Application

Deploy application:

```bash
kubectl apply -f notes-app/notes-app.yml
```

Verify deployment:

```bash
kubectl get deployment -n notes-ns
```

Verify pod:

```bash
kubectl get pods -n notes-ns
```

Expected:

```text
notes-app-xxxxx   Running
```

---

# Step 5 - Create Service

Deploy service:

```bash
kubectl apply -f notes-app/notes-service.yml
```

Verify:

```bash
kubectl get svc -n notes-ns
```

Expected:

```text
NAME            TYPE        CLUSTER-IP
notes-service   ClusterIP   10.x.x.x
```

Check service details:

```bash
kubectl describe svc notes-service -n notes-ns
```

Verify Endpoints are populated:

```text
Endpoints: 10.x.x.x:80
```

If endpoints show "<none>", verify deployment labels and service selectors.

---

# Step 6 - Test Service Connectivity

Create temporary pod:

```bash
kubectl run test --rm -it --image=busybox -- sh
```

Inside the pod:

```bash
wget -qO- http://notes-service.notes-ns.svc.cluster.local
```

Expected:

Nginx welcome page HTML output.

Exit pod:

```bash
exit
```

---

# Step 7 - Create HPA

Deploy HPA:

```bash
kubectl apply -f hpa/hpa.yml
```

Verify:

```bash
kubectl get hpa -n notes-ns
```

Example:

```text
NAME        TARGETS   MINPODS   MAXPODS   REPLICAS
notes-hpa   0%/50%    1         5         1
```

---

# Step 8 - Verify HPA Configuration

Check detailed configuration:

```bash
kubectl describe hpa notes-hpa -n notes-ns
```

Verify:

```text
Min replicas: 1
Max replicas: 5
Target CPU: 50%
```

---

# Step 9 - Deploy Load Generator

Deploy traffic generator:

```bash
kubectl apply -f load-generator/load-generator.yml
```

Verify:

```bash
kubectl get pods -n load-ns
```

Expected:

```text
load-generator-xxxxx   Running
```

---

# Step 10 - Monitor HPA

Open Terminal 1:

```bash
watch -n 2 kubectl get hpa -n notes-ns
```

Open Terminal 2:

```bash
watch -n 2 kubectl get pods -n notes-ns
```

Open Terminal 3:

```bash
kubectl top pods -n notes-ns
```

Observe:

```text
CPU usage increases
      ↓
HPA detects load
      ↓
Replica count increases
      ↓
Additional Pods created
```

Expected scaling:

```text
1 Pod
↓
2 Pods
↓
3 Pods
```

---

# Step 11 - Verify HPA is Working

Check HPA events:

```bash
kubectl describe hpa notes-hpa -n notes-ns
```

Look for:

```text
SuccessfulRescale

New size: 2
New size: 3
```

This confirms HPA is functioning correctly.

---

# Step 12 - Verify Deployment Scaling

Check deployment:

```bash
kubectl get deployment -n notes-ns
```

Example:

```text
NAME        READY
notes-app   3/3
```

Verify pods:

```bash
kubectl get pods -n notes-ns
```

Multiple Pods should be running.

---

# Step 13 - Stop Load Generator

Delete load generator:

```bash
kubectl delete -f load-generator/load-generator.yml
```

Wait a few minutes.

Observe:

```text
CPU utilization decreases
      ↓
HPA scales down
      ↓
Pods removed automatically
```

Verify:

```bash
kubectl get hpa -n notes-ns
kubectl get pods -n notes-ns
```

---

# Troubleshooting

### Metrics not available

```bash
kubectl top nodes
```

Error:

```text
Metrics API not available
```

Verify Metrics Server:

```bash
kubectl get pods -n kube-system
```

---

### HPA shows Unknown

Check Metrics Server:

```bash
kubectl top pods -A
```

---

### Service has no endpoints

Verify labels:

```bash
kubectl get pods -n notes-ns --show-labels
```

Verify selector:

```bash
kubectl describe svc notes-service -n notes-ns
```

---

### HPA not scaling

Verify CPU requests exist:

```bash
kubectl describe deployment notes-app -n notes-ns
```

Look for:

```yaml
resources:
  requests:
    cpu: 100m
```

---

# Cleanup

Delete application namespace:

```bash
kubectl delete ns notes-ns
```

Delete load namespace:

```bash
kubectl delete ns load-ns
```

Verify cleanup:

```bash
kubectl get ns
```

---

# Interview Questions

### What is HPA?

Horizontal Pod Autoscaler automatically scales Pods based on metrics such as CPU or Memory.

### What component provides metrics?

Metrics Server.

### What does HPA scale?

Pods.

### What scales Nodes?

Cluster Autoscaler or Karpenter.

### What is required for HPA?

* Metrics Server
* Deployment
* CPU Requests
* HPA Object

### Command to check HPA?

```bash
kubectl get hpa
```

### Command to view HPA events?

```bash
kubectl describe hpa
```
