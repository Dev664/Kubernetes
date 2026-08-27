# Kubernetes NodeSelector Lab

This lab demonstrates how **Kubernetes `nodeSelector`** controls where a Pod can be scheduled based on **Node labels**.

---

## Lab Objective

By the end of this lab, you will understand:

- What `nodeSelector` is
- How to label Kubernetes Nodes
- How a Pod uses `nodeSelector`
- How Kubernetes selects a matching Node
- What happens when no Node matches the selector
- How to troubleshoot a `Pending` Pod
- How NodeSelector can be used for workload-specific scheduling

---

## Prerequisites

You need a Kubernetes cluster with at least **2 worker nodes**.

Example:

```text
Control Plane
     |
     +-------------------+
     |                   |
     v                   v
Worker              Worker2
```

Example node names used in this lab:

```text
multi-cluster-worker
multi-cluster-worker2
```

---

# 1. Check the Nodes

First, check your cluster:

```bash
kubectl get nodes
```

Example:

```text
NAME                          STATUS   ROLES           AGE   VERSION
multi-cluster-control-plane   Ready    control-plane   20d   v1.35.0
multi-cluster-worker          Ready    <none>          20d   v1.35.0
multi-cluster-worker2         Ready    <none>          20d   v1.35.0
```

---

# 2. Add Production-Style Labels to Worker Nodes

For this lab, assume that:

- `multi-cluster-worker` is intended to run **web applications**
- `multi-cluster-worker2` is intended for other workloads

We will add the following label:

| Node | Label |
|---|---|
| `multi-cluster-worker` | `workload=webapp` |
| `multi-cluster-worker2` | `workload=backend` |

Add the `webapp` label:

```bash
kubectl label node scheduling-lab-worker workload=webapp
```

Add a different workload label to the second worker:

```bash
kubectl label node scheduling-lab-worker2 workload=backend
```

Verify:

```bash
kubectl get nodes --show-labels
```

You can also check individually:

```bash
kubectl get node multi-cluster-worker --show-labels
```

```bash
kubectl get node multi-cluster-worker2 --show-labels
```

Expected:

```text
multi-cluster-worker   ...   workload=webapp
multi-cluster-worker2  ...   workload=backend
```

---

# 3. Understand the NodeSelector

Suppose we have a web application Pod that should run only on Nodes dedicated to web applications.

The Pod contains:

```yaml
nodeSelector:
  workload: webapp
```

Kubernetes checks the Node labels:

```text
                    Pod
                     |
                     | nodeSelector:
                     |   workload=webapp
                     |
                     v
              Kubernetes Scheduler
                     |
          +----------+----------+
          |                     |
          v                     v
      Worker                Worker2
 workload=webapp          workload=backend
      YES                      NO
          |
          v
     Pod scheduled
```

This is a simple example of workload-based scheduling.

---

# 4. Create NodeSelector Pod

Create the YAML file:

```bash
vi node-selector.yaml
```

Add:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: nginx-webapp

spec:
  nodeSelector:
    workload: webapp

  containers:
    - name: nginx
      image: nginx:1.27
```

Save and exit.

---

# 5. Create the Pod

Apply the YAML:

```bash
kubectl apply -f node-selector.yaml
```

Expected:

```text
pod/nginx-webapp created
```

Check the Pod:

```bash
kubectl get pod nginx-webapp -o wide
```

Expected:

```text
NAME           READY   STATUS    RESTARTS   AGE   IP          NODE
nginx-webapp   1/1     Running   0          10s   10.x.x.x    multi-cluster-worker
```

The important part is:

```text
NODE
multi-cluster-worker
```

Why did Kubernetes choose this Node?

Because:

```text
Worker
  workload=webapp  YES

Worker2
  workload=backend NO
```

The Pod has:

```yaml
nodeSelector:
  workload: webapp
```

Therefore Kubernetes schedules the Pod on the Node with:

```text
workload=webapp
```

---

# 6. Verify the Node Label

Verify that the Pod is running on the expected Node:

```bash
kubectl get pod nginx-webapp -o wide
```

Check the Node label:

```bash
kubectl get node multi-cluster-worker --show-labels
```

Expected:

```text
workload=webapp
```

You can also use:

```bash
kubectl get nodes -l workload=webapp
```

This returns only Nodes having the `workload=webapp` label.

Example:

```text
NAME                    STATUS   ROLES    AGE   VERSION
multi-cluster-worker   Ready    <none>   20m   v1.35.0
```

---

# 7. Demonstrate What Happens When No Matching Node Exists

Now let's intentionally create a situation where **no Node matches the Pod's `nodeSelector`**.

Edit the YAML:

```bash
vi node-selector.yaml
```

Change:

```yaml
nodeSelector:
  workload: webapp
```

to:

```yaml
nodeSelector:
  workload: frontend
```

The YAML should now contain:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: nginx-webapp

spec:
  nodeSelector:
    workload: frontend

  containers:
    - name: nginx
      image: nginx:1.27
```

There is currently no Node with:

```text
workload=frontend
```

Our Nodes are:

```text
multi-cluster-worker
    workload=webapp

multi-cluster-worker2
    workload=backend
```

---

# 8. Delete and Recreate the Pod

Delete the existing Pod:

```bash
kubectl delete pod nginx-webapp
```

Create it again:

```bash
kubectl apply -f node-selector.yaml
```

Check:

```bash
kubectl get pod nginx-webapp
```

Expected:

```text
NAME           READY   STATUS
nginx-webapp   0/1     Pending
```

---

# 9. Why Is the Pod Pending?

The Pod requires:

```text
workload=frontend
```

But our Nodes have:

```text
multi-cluster-worker
    workload=webapp  NO

multi-cluster-worker2
    workload=backend NO
```

There is **no Node with `workload=frontend`**.

Therefore:

```text
Pod
 |
 | requires workload=frontend
 |
 v
Kubernetes Scheduler
 |
 +----------------------------+
 |                            |
 v                            v
Worker                     Worker2
webapp ❌                  backend ❌
 |
 v
No matching Node
 |
 v
Pod Pending
```

---

# 10. Troubleshoot the Pending Pod

Run:

```bash
kubectl describe pod nginx-webapp
```

Scroll down to the **Events** section.

The scheduler will report that the available Nodes do not satisfy the Pod's node selector.

You can also check recent events:

```bash
kubectl get events --sort-by=.lastTimestamp
```

---

# 11. Fix the Problem

Change the selector back to:

```yaml
nodeSelector:
  workload: webapp
```

The complete YAML:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: nginx-webapp

spec:
  nodeSelector:
    workload: webapp

  containers:
    - name: nginx
      image: nginx:1.27
```

Delete the Pending Pod:

```bash
kubectl delete pod nginx-webapp
```

Create it again:

```bash
kubectl apply -f node-selector.yaml
```

Check:

```bash
kubectl get pod nginx-webapp -o wide
```

Expected:

```text
NAME           READY   STATUS    NODE
nginx-webapp   1/1     Running   smulti-cluster-worker
```

---

# 12. Production-Style Example

In a real production environment, Nodes can be labeled according to the type of workload they are intended to run.

For example:

```text
Node 1
workload=webapp

Node 2
workload=webapp

Node 3
workload=backend

Node 4
workload=database
```

A web application Deployment could use:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        workload: webapp
```

Then Kubernetes will schedule those Pods only on Nodes with:

```text
workload=webapp
```

### Important Production Note

In production, teams often use more descriptive labels such as:

```text
workload=web
workload=backend
workload=database
environment=production
team=payments
tier=frontend
```

For more advanced scheduling requirements, Kubernetes generally uses **node affinity** instead of relying only on `nodeSelector`, because affinity provides more expressive rules.

---

# 13. Complete Lab Flow

```text
                    Node Labels
                         |
             +-----------+-----------+
             |                       |
             v                       v
         Worker                  Worker2
    workload=webapp          workload=backend
             |                       |
             +-----------+-----------+
                         |
                         v
                       Pod
                         |
                 nodeSelector:
                 workload=webapp
                         |
                         v
                 Kubernetes Scheduler
                         |
                         v
                  Worker selected
                         |
                         v
                    Pod Running
```

When there is no matching Node:

```text
Pod
 |
 | nodeSelector:
 |   workload=frontend
 |
 v
Scheduler
 |
 +----------------------+
 |                      |
 v                      v
webapp                 backend
 NO                      NO
 |
 v
No matching Node
 |
 v
Pod Pending
```

---

# 14. Cleanup

Delete the Pod:

```bash
kubectl delete pod nginx-webapp
```

Remove the labels if you want to return the Nodes to their original state:

```bash
kubectl label node multi-cluster-worker workload-
```

```bash
kubectl label node multi-cluster-worker2 workload-
```

Verify:

```bash
kubectl get nodes --show-labels
```

---

# Key Takeaways

## What is nodeSelector?

`nodeSelector` is a simple way to tell Kubernetes:

> **Schedule this Pod only on Nodes having these labels.**

Example:

```yaml
nodeSelector:
  workload: webapp
```

This means:

```text
Pod
 |
 v
Find Node
 |
 | workload=webapp
 |
 v
Schedule Pod
```

If no Node has the required label:

```text
No matching Node
       |
       v
Pod Pending
```

## Typical Production Use Cases

`nodeSelector` can be used for simple workload placement such as:

- Web application Nodes
- Backend application Nodes
- GPU workloads
- Application-specific Nodes
- Production workloads
- Development workloads
- Hardware-specific workloads
- Availability-zone-specific workloads

## Scheduling Flow

```text
Node Label
    |
    v
nodeSelector
    |
    v
Kubernetes Scheduler
    |
    v
Pod Placement
```

For more complex scheduling rules, Work on the  **Node Affinity** and **Pod Affinity/Anti-Affinity** LAB

