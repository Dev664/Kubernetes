# Kubernetes VPA (Vertical Pod Autoscaler) Lab

## Objective

In this lab we will:

* Install Metrics Server
* Install Vertical Pod Autoscaler (VPA)
* Deploy a sample application
* Generate CPU load
* Observe VPA recommendations
* Automatically adjust CPU and Memory requests
* Verify VPA functionality

---

# What is VPA?

VPA stands for Vertical Pod Autoscaler.

Unlike HPA:

```text
HPA -> Increases Pod Count

1 Pod -> 2 Pods -> 3 Pods
```

VPA:

```text
1 Pod
CPU: 100m

↓

1 Pod
CPU: 500m
```

VPA changes:

* CPU Requests
* Memory Requests

instead of creating additional Pods.

---

# Architecture

```text
Application
      |
      v
Metrics Server
      |
      v
VPA Recommender
      |
      v
CPU / Memory Recommendation
      |
      v
Pod Restart
      |
      v
New Resources Applied
```

---

# Lab Directory Structure

```text
vpa-lab/
├── namespace/
│   └── notes-namespace.yml
├── notes-app/
│   ├── notes-app.yml
│   └── notes-service.yml
├── vpa/
│   └── vpa.yml
└── load-generator/
    └── load-generator.yml
```

---

# Step 1 - Verify Cluster

```bash
kubectl get nodes
```

Expected:

```text
NAME                         STATUS
kind-control-plane           Ready
```

---

# Step 2 - Install Metrics Server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

Verify:

```bash
kubectl get pods -n kube-system
```

Wait until:

```text
metrics-server-xxxxx   1/1 Running
```

Test:

```bash
kubectl top nodes
```

---

# Step 3 - Install VPA

Clone autoscaler repository:

```bash
git clone https://github.com/kubernetes/autoscaler.git
```

Move to VPA directory:

```bash
cd autoscaler/vertical-pod-autoscaler
```

Install VPA:

```bash
./hack/vpa-up.sh
```

Verify:

```bash
kubectl get pods -n kube-system
```

Expected:

```text
vpa-admission-controller
vpa-recommender
vpa-updater
```

All should be Running.

---

# Step 4 - Create Namespace

File:

namespace/notes-namespace.yml

```yaml
apiVersion: v1
kind: Namespace

metadata:
  name: notes-ns
```

Apply:

```bash
kubectl apply -f namespace/notes-namespace.yml
```

Verify:

```bash
kubectl get ns
```

---

# Step 5 - Create Deployment

File:

notes-app/notes-app.yml

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: notes-app
  namespace: notes-ns

spec:
  replicas: 1

  selector:
    matchLabels:
      app: notes-app

  template:
    metadata:
      labels:
        app: notes-app

    spec:
      containers:
      - name: notes-app
        image: nginx

        ports:
        - containerPort: 80

        resources:
          requests:
            cpu: 50m
            memory: 50Mi

          limits:
            cpu: 200m
            memory: 200Mi
```

Apply:

```bash
kubectl apply -f notes-app/notes-app.yml
```

Verify:

```bash
kubectl get pods -n notes-ns
```

---

# Step 6 - Create Service

File:

notes-app/notes-service.yml

```yaml
apiVersion: v1
kind: Service

metadata:
  name: notes-service
  namespace: notes-ns

spec:
  selector:
    app: notes-app

  ports:
  - port: 80
    targetPort: 80

  type: ClusterIP
```

Apply:

```bash
kubectl apply -f notes-app/notes-service.yml
```

Verify:

```bash
kubectl get svc -n notes-ns
```

---

# Step 7 - Create VPA

File:

vpa/vpa.yml

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler

metadata:
  name: notes-vpa
  namespace: notes-ns

spec:
  targetRef:
    apiVersion: "apps/v1"
    kind: Deployment
    name: notes-app

  updatePolicy:
    updateMode: Auto

  resourcePolicy:
    containerPolicies:
    - containerName: "*"

      minAllowed:
        cpu: 50m
        memory: 50Mi

      maxAllowed:
        cpu: 1
        memory: 1Gi

      controlledResources:
      - cpu
      - memory
```

Apply:

```bash
kubectl apply -f vpa/vpa.yml
```

Verify:

```bash
kubectl get vpa -n notes-ns
```

---

# Step 8 - Create Load Generator

File:

load-generator/load-generator.yml

```yaml
apiVersion: apps/v1
kind: Deployment

metadata:
  name: load-generator
  namespace: notes-ns

spec:
  replicas: 1

  selector:
    matchLabels:
      app: load-generator

  template:
    metadata:
      labels:
        app: load-generator

    spec:
      containers:
      - name: load-generator
        image: busybox

        command:
        - /bin/sh
        - -c

        - |
          while true
          do
            wget -q -O- http://notes-service
          done
```

Apply:

```bash
kubectl apply -f load-generator/load-generator.yml
```

---

# Step 9 - Verify VPA

Check VPA:

```bash
kubectl get vpa -n notes-ns
```

Initially:

```text
No recommendation available
```

Wait a few minutes.

---

# Step 10 - Check Recommendations

```bash
kubectl describe vpa notes-vpa -n notes-ns
```

Example:

```text
Recommendation:

Container Name: notes-app

Target:
  CPU:     300m
  Memory:  150Mi

Lower Bound:
  CPU:     150m

Upper Bound:
  CPU:     600m
```

This proves VPA is collecting metrics.

---

# Step 11 - Verify Pod Resources

Check current resources:

```bash
kubectl describe pod -n notes-ns
```

Look for:

```text
Requests:
  cpu: 50m
```

After VPA update:

```text
Requests:
  cpu: 300m
```

---

# Step 12 - Verify Pod Restart

VPA Auto Mode updates resources by:

```text
Evict Pod
Create New Pod
Apply Recommended Resources
```

Check:

```bash
kubectl get pods -n notes-ns -w
```

You will see:

```text
Old Pod Terminating

New Pod Starting
```

---

# Step 13 - Monitor Resources

CPU:

```bash
kubectl top pods -n notes-ns
```

VPA:

```bash
kubectl get vpa -n notes-ns
```

Deployment:

```bash
kubectl describe deployment notes-app -n notes-ns
```

---

# Verification Commands

View VPA:

```bash
kubectl get vpa -n notes-ns
```

Describe VPA:

```bash
kubectl describe vpa notes-vpa -n notes-ns
```

View Recommendations:

```bash
kubectl describe vpa notes-vpa -n notes-ns
```

View Metrics:

```bash
kubectl top pods -n notes-ns
```

View Resources:

```bash
kubectl describe pod -n notes-ns
```

---

# Difference Between HPA and VPA

| HPA               | VPA                    |
| ----------------- | ---------------------- |
| Scales Pod Count  | Scales CPU/Memory      |
| 1 Pod → 5 Pods    | 100m → 500m CPU        |
| No Restart        | Pod Restart Required   |
| Best for Web Apps | Best for Stateful Apps |

---

# Cleanup

Delete VPA:

```bash
kubectl delete -f vpa/vpa.yml
```

Delete application:

```bash
kubectl delete ns notes-ns
```

Remove VPA components:

```bash
cd autoscaler/vertical-pod-autoscaler

./hack/vpa-down.sh
```

---

# Interview Questions

### What is VPA?

Vertical Pod Autoscaler automatically adjusts CPU and Memory requests based on actual usage.

### What components does VPA install?

* vpa-recommender
* vpa-updater
* vpa-admission-controller

### What does VPA scale?

CPU and Memory Requests.

### Does VPA create more Pods?

No.

### Does VPA restart Pods?

Yes.

### Can HPA and VPA be used together?

Generally not on the same CPU metric because they can conflict.
