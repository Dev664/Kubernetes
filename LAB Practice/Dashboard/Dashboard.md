# Kubernetes Dashboard Setup on AWS EC2 (kubeadm Cluster)

## Environment

This setup assumes the following environment:

```text
AWS EC2 Instances
├── k8s-master
├── k8s-worker1

Kubernetes Installation
├── kubeadm
├── containerd/docker
```

---

# Step 1: Verify Cluster Health

Login to the Kubernetes Master Node.

```bash
kubectl get nodes
```

Expected Output:

```text
NAME         STATUS
k8s-master   Ready
k8s-worker1  Ready
```

---

# Step 2: Install Kubernetes Dashboard

Deploy the Kubernetes Dashboard.

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
```

Verify Dashboard Pods:

```bash
kubectl get pods -n kubernetes-dashboard
```

Expected Output:

```text
NAME                                         READY
dashboard-metrics-scraper                    1/1
kubernetes-dashboard                         1/1
```

---

# Step 3: Verify Dashboard Service

```bash
kubectl get svc -n kubernetes-dashboard
```

Expected Output:

```text
NAME                   TYPE        CLUSTER-IP
kubernetes-dashboard   ClusterIP   10.x.x.x
```

---

# Step 4: Create Dashboard Admin User

Create a file named:

```bash
vi dashboard-admin.yaml
```

Paste the following content:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user

roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin

subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
```

Apply the configuration:

```bash
kubectl apply -f dashboard-admin.yaml
```

Expected Output:

```text
serviceaccount/admin-user created
clusterrolebinding/admin-user created
```

---

# Step 5: Generate Login Token

Generate a Dashboard authentication token.

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

Example Output:

```text
eyJhbGciOiJSUzI1NiIsImtpZCI6...
```

Save this token.

You will need it to log in to the Dashboard.

---

# Step 6: Expose Dashboard via NodePort

Edit the Dashboard Service.

```bash
kubectl edit svc kubernetes-dashboard -n kubernetes-dashboard
```

Find:

```yaml
type: ClusterIP
```

Replace with:

```yaml
type: NodePort
```

Save and exit.

---

# Step 7: Find Dashboard NodePort

```bash
kubectl get svc -n kubernetes-dashboard
```

Example Output:

```text
NAME                   TYPE       PORT(S)
kubernetes-dashboard   NodePort   443:32443/TCP
```

Note the NodePort value.

Example:

```text
32443
```

---

# Step 8: Configure AWS Security Group

Open the Security Group attached to the Kubernetes Master Node.

Add the following inbound rule:

| Type       | Protocol | Port  | Source         |
| ---------- | -------- | ----- | -------------- |
| Custom TCP | TCP      | 32443 | Your Public IP |

Example:

```text
203.110.xx.xx/32
```

For lab environments only:

```text
0.0.0.0/0
```

---

# Step 9: Obtain Master Public IP

```bash
curl ifconfig.me
```

Or check the EC2 Console.

Example:

```text
13.233.xx.xx
```

---

# Step 10: Access Dashboard

Open your browser and navigate to:

```text
https://<MASTER_PUBLIC_IP>:32443
```

Example:

```text
https://13.233.xx.xx:32443
```

You will receive a certificate warning because Kubernetes Dashboard uses a self-signed certificate.

Proceed to the website.

---

# Step 11: Login to Dashboard

Select:

```text
Token
```

Paste the token generated earlier.

Click:

```text
Sign In
```

---

# Step 12: Install Metrics Server

Metrics Server enables CPU and Memory monitoring.

Install:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

---

# Step 13: Fix Metrics Server for kubeadm Clusters

Edit the deployment:

```bash
kubectl edit deployment metrics-server -n kube-system
```

Locate:

```yaml
args:
```

Add:

```yaml
- --kubelet-insecure-tls
```

Example:

```yaml
args:
- --cert-dir=/tmp
- --secure-port=10250
- --kubelet-insecure-tls
```

Save and exit.

---

# Step 14: Verify Metrics

Wait approximately 1-2 minutes.

Check node metrics:

```bash
kubectl top nodes
```

Expected Output:

```text
NAME         CPU(cores)   MEMORY(bytes)
k8s-master   100m         800Mi
k8s-worker1  150m         1Gi
```

Check pod metrics:

```bash
kubectl top pods -A
```

---

# Useful Commands

### Dashboard Pods

```bash
kubectl get pods -n kubernetes-dashboard
```

### Dashboard Service

```bash
kubectl get svc -n kubernetes-dashboard
```

### Generate Dashboard Token

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

### View Node Metrics

```bash
kubectl top nodes
```

### View Pod Metrics

```bash
kubectl top pods -A
```

---

# Components Installed

```text
Kubernetes Dashboard
├── Dashboard UI
├── Dashboard Metrics Scraper
├── Admin Service Account
├── ClusterRoleBinding
└── NodePort Service

Metrics Server
├── CPU Monitoring
└── Memory Monitoring
```

---

# Result

After completing all steps, you will be able to:

* View Nodes
* View Pods
* View Deployments
* View ReplicaSets
* View Services
* View Namespaces
* View ConfigMaps
* View Secrets
* Monitor CPU Usage
* Monitor Memory Usage
* View Pod Logs

using the Kubernetes Dashboard from your laptop browser.
