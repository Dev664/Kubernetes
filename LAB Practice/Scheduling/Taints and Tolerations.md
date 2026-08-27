# LAB: Taints and Tolerations

A hands-on Kubernetes scheduling lab covering **Taints, Tolerations, Taint Effects, `tolerationSeconds`, and Taint + Toleration + Node Affinity** using an existing KIND cluster.

---

## Lab Objectives

In this lab, you will configure a dedicated Kubernetes Node and control which workloads are allowed to run on it.

You will practice:

- `NoSchedule`
- `PreferNoSchedule`
- `NoExecute`
- Tolerations
- `tolerationSeconds`
- Taint + Toleration
- Taint + Toleration + Node Affinity
- Production-style dedicated workload placement
- Troubleshooting `Pending` Pods

---

# 1. Lab Environment

This lab we will use the existing KIND cluster:

```text
multi-cluster-control-plane
multi-cluster-worker
multi-cluster-worker2
```

Check the cluster:

```bash
kubectl get nodes
```

Expected:

```text
NAME                          STATUS   ROLES
multi-cluster-control-plane   Ready    control-plane
multi-cluster-worker          Ready    <none>
multi-cluster-worker2         Ready    <none>
```

## Lab Design

```text
                 Kubernetes Cluster
                        |
             +----------+----------+
             |                     |
             v                     v
        Worker Node           Dedicated Node
        worker                worker2
             |                     |
       WebApp / Backend       Database
       General workloads     Critical workloads
```

For this lab:

```text
multi-cluster-worker2
        |
        +-- Dedicated for Database workloads
```

---

# 2. Understand Taints and Tolerations

A **Taint** is applied to a Node.

It tells the Kubernetes Scheduler:

> Do not schedule Pods on this Node unless they tolerate the taint.

A **Toleration** is defined in a Pod.

It tells Kubernetes:

> This Pod is allowed to run on a Node with this taint.

### Basic relationship

```text
Node
 |
 | Taint
 |
 v
"Keep unwanted Pods away"


Pod
 |
 | Toleration
 |
 v
"I am allowed to run there"
```

### Important

A toleration **does not force** a Pod onto a Node.

It only allows the Pod to run on a Node with the matching taint.

To specifically select a dedicated Node, combine:

```text
Taint
   +
Toleration
   +
Node Affinity
```

---

# 3. Apply a `NoSchedule` Taint

We will use `multi-cluster-worker2` as a dedicated database Node.

Run:

```bash
kubectl taint nodes multi-cluster-worker2 workload=database:NoSchedule
```

Verify:

```bash
kubectl describe node multi-cluster-worker2 | grep -i taint
```

Expected:

```text
Taints: workload=database:NoSchedule
```

---

# 4. Deploy a Normal WebApp Pod

Create:

```bash
vi webapp.yaml
```

Add:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: webapp
  labels:
    app: webapp
    tier: frontend

spec:
  containers:
    - name: nginx
      image: nginx:1.27
```

Apply:

```bash
kubectl apply -f webapp.yaml
```

Check:

```bash
kubectl get pod webapp -o wide
```

The Pod should run on:

```text
multi-cluster-worker
```

It should not be scheduled on:

```text
multi-cluster-worker2
```

because `worker2` has:

```text
workload=database:NoSchedule
```

and the WebApp Pod has no matching toleration.

---

# 5. Understand `NoSchedule`

Check the Node:

```bash
kubectl describe node multi-cluster-worker2
```

Look for:

```text
Taints:
  workload=database:NoSchedule
```

The scheduling behavior is:

```text
                  Pod
                   |
            Has toleration?
              /          \
            NO            YES
            |              |
            v              v
        Cannot use      Allowed to
         this Node       use Node
```

### `NoSchedule`

`NoSchedule` is a hard scheduling restriction.

```text
No matching toleration
        |
        v
Pod cannot be scheduled
on the tainted Node
```

---

# 6. Create a Database Pod with Toleration

The Database workload is allowed to use the dedicated Node.

Create:

```bash
vi database.yaml
```

Add:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: database
  labels:
    app: database
    tier: database

spec:
  tolerations:
    - key: workload
      operator: Equal
      value: database
      effect: NoSchedule

  containers:
    - name: database
      image: nginx:1.27
```

Apply:

```bash
kubectl apply -f database.yaml
```

Check:

```bash
kubectl get pod database -o wide
```

The Database Pod is now **allowed** to run on `worker2`.

> The exact Node selected can vary because a toleration allows a Node; it does not select one.

---

# 7. Important: Toleration Does NOT Select a Node

Adding:

```yaml
tolerations:
  - key: workload
    operator: Equal
    value: database
    effect: NoSchedule
```

does **not** mean:

> Run this Pod on `multi-cluster-worker2`.

It only means:

> The Pod is allowed to run on a Node with this taint.

The Scheduler can still choose another suitable Node.

To specifically select the dedicated Node, combine:

```text
Toleration
    +
Node Affinity
```

---

# 8. Add a Label to the Dedicated Node

Add a label:

```bash
kubectl label node multi-cluster-worker2 workload=database
```

Verify:

```bash
kubectl get nodes -L workload
```

Expected:

```text
NAME                          workload
multi-cluster-control-plane
multi-cluster-worker
multi-cluster-worker2         database
```

Now we can use Node Affinity to select the intended Node.

---

# 9. Create Production-Style Database Pod

Create:

```bash
vi database-production.yaml
```

Add:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: database-production
  labels:
    app: database
    tier: database

spec:
  tolerations:
    - key: workload
      operator: Equal
      value: database
      effect: NoSchedule

  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: workload
                operator: In
                values:
                  - database

  containers:
    - name: database
      image: nginx:1.27
```

Apply:

```bash
kubectl apply -f database-production.yaml
```

Check:

```bash
kubectl get pod database-production -o wide
```

Expected:

```text
NAME                  NODE
database-production   multi-cluster-worker2
```

---

# 10. Understand the Production Pattern

Now three mechanisms work together:

```text
                    Database Pod
                         |
             +-----------+-----------+
             |                       |
             v                       v
        Toleration              Node Affinity
             |                       |
          "Allowed"               "Select"
             |                       |
             +-----------+-----------+
                         |
                         v
                    worker2
                         |
                  workload=database
                         |
                      NoSchedule
```

### Taint

Protects the Node:

```text
workload=database:NoSchedule
```

### Toleration

Allows the Database Pod:

```text
workload=database
```

### Node Affinity

Selects the intended Node:

```text
workload=database
```

This creates a dedicated workload placement pattern.

---

# 11. `PreferNoSchedule`

Remove the existing taint:

```bash
kubectl taint nodes multi-cluster-worker2 workload=database:NoSchedule-
```

Apply:

```bash
kubectl taint nodes multi-cluster-worker2 workload=database:PreferNoSchedule
```

Verify:

```bash
kubectl describe node multi-cluster-worker2 | grep -i taint
```

Expected:

```text
Taints: workload=database:PreferNoSchedule
```

## Behavior

`PreferNoSchedule` is a **soft restriction**.

Kubernetes tries to avoid scheduling Pods onto this Node but does not strictly prevent it.

```text
NoSchedule
     |
     v
Hard restriction

PreferNoSchedule
     |
     v
Soft restriction
```

### Quick Comparison

```text
NoSchedule
    |
    +-- Do not schedule unless tolerated

PreferNoSchedule
    |
    +-- Prefer not to schedule
```

---

# 12. `NoExecute`

Remove the current taint:

```bash
kubectl taint nodes multi-cluster-worker2 workload=database:PreferNoSchedule-
```

Add:

```bash
kubectl taint nodes multi-cluster-worker2 workload=database:NoExecute
```

Verify:

```bash
kubectl describe node multi-cluster-worker2 | grep -i taint
```

Expected:

```text
Taints: workload=database:NoExecute
```

## Behavior

`NoExecute` affects:

- New Pods
- Existing Pods

```text
NoExecute
    |
    +---- New Pod
    |       |
    |       v
    |   Cannot schedule
    |
    +---- Existing Pod
            |
            v
        Can be evicted
```

This is different from `NoSchedule`.

---

# 13. Test a Pod Without a Toleration

Create:

```bash
vi test-noexecute.yaml
```

Add:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: test-noexecute

spec:
  containers:
    - name: nginx
      image: nginx:1.27
```

Apply:

```bash
kubectl apply -f test-noexecute.yaml
```

Check:

```bash
kubectl get pod test-noexecute -o wide
```

The Pod cannot use the Node with:

```text
workload=database:NoExecute
```

Troubleshoot:

```bash
kubectl describe pod test-noexecute
```

Check the **Events** section.

---

# 14. Toleration for `NoExecute`

Create:

```bash
vi database-noexecute.yaml
```

Add:

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: database-noexecute

spec:
  tolerations:
    - key: workload
      operator: Equal
      value: database
      effect: NoExecute

  containers:
    - name: database
      image: nginx:1.27
```

Apply:

```bash
kubectl apply -f database-noexecute.yaml
```

The Pod can tolerate:

```text
workload=database:NoExecute
```

Check:

```bash
kubectl get pod database-noexecute -o wide
```

---

# 15. `tolerationSeconds`

A `NoExecute` toleration can include a time period.

Example:

```yaml
tolerations:
  - key: workload
    operator: Equal
    value: database
    effect: NoExecute
    tolerationSeconds: 60
```

This means:

```text
NoExecute taint appears
        |
        v
Pod can remain temporarily
        |
      60 sec
        |
        v
Taint still exists
        |
        v
Pod can be evicted
```

### Key Point

`tolerationSeconds` applies to `NoExecute` tolerations.

---

# 16. Taint Effects

| Effect | New Pod | Existing Pod |
|---|---|---|
| `NoSchedule` | Blocked without toleration | Stays |
| `PreferNoSchedule` | Avoid if possible | Stays |
| `NoExecute` | Blocked without toleration | Can be evicted |

### Quick Memory Trick

```text
NoSchedule
    |
    v
Don't schedule

PreferNoSchedule
    |
    v
Prefer not to schedule

NoExecute
    |
    v
Don't schedule
+
Remove existing Pods
```

---

# 17. Production Use Cases

## Database Nodes

```text
workload=database:NoSchedule
```

Only database workloads have the appropriate toleration.

---

## GPU Nodes

```text
workload=gpu:NoSchedule
```

GPU workloads tolerate the taint.

---

## Critical Workloads

```text
workload=critical:NoSchedule
```

Critical applications can be isolated from normal workloads.

---

## Maintenance

A taint can prevent new workloads from being placed on a Node.

For planned maintenance, use:

```bash
kubectl cordon <node>
kubectl drain <node>
```

Do not treat a taint as a replacement for the normal drain workflow.

---

# 18. Production Architecture

```text
                         Kubernetes Cluster
                                |
               +----------------+----------------+
               |                                 |
               v                                 v
        General Worker                    Dedicated Worker
        worker                           worker2
               |                                 |
        +------+------+                    +-----+-----+
        |             |                    |           |
      WebApp        Backend             Database    Critical
        |             |                    |           |
        +-------------+                    |           |
                                          |
                              workload=database
                              :NoSchedule
```

The dedicated Node is protected by:

```text
workload=database:NoSchedule
```

The Database workload has:

```text
Toleration
    +
Node Affinity
```

Therefore:

```text
             Database Pod
                  |
        +---------+---------+
        |                   |
    Toleration          Node Affinity
        |                   |
      Allowed              Select
        |                   |
        +---------+---------+
                  |
                  v
              worker2
```

---

# 19. Cleanup

Since this lab uses the existing KIND cluster, the cleanup should **not delete the cluster**.

Create:

```bash
vi cleanup-taint-lab.sh
```

Add:

```bash
#!/bin/bash

echo "=========================================="
echo " Cleaning Taints & Tolerations LAB"
echo "=========================================="

echo
echo "Deleting LAB Pods..."

kubectl delete pod webapp --ignore-not-found
kubectl delete pod database --ignore-not-found
kubectl delete pod database-production --ignore-not-found
kubectl delete pod database-noexecute --ignore-not-found
kubectl delete pod test-noexecute --ignore-not-found

echo
echo "Removing Taints..."

kubectl taint nodes multi-cluster-worker2 workload=database:NoSchedule- 2>/dev/null
kubectl taint nodes multi-cluster-worker2 workload=database:NoExecute- 2>/dev/null
kubectl taint nodes multi-cluster-worker2 workload=database:PreferNoSchedule- 2>/dev/null

echo
echo "Removing LAB Label..."

kubectl label node multi-cluster-worker2 workload- 2>/dev/null

echo
echo "Verifying Nodes..."

kubectl get nodes

echo
echo "Checking Taints..."

kubectl describe node multi-cluster-worker2 | grep -i taint

echo
echo "=========================================="
echo " Cleanup Completed"
echo "=========================================="
```

Make it executable:

```bash
chmod +x cleanup-taint-lab.sh
```

Run:

```bash
./cleanup-taint-lab.sh
```

Verify:

```bash
kubectl get nodes -L workload
```

The `workload` label should be removed.

---

# 20. Troubleshooting Commands

Check Node taints:

```bash
kubectl describe node <node-name> | grep -i taint
```

Check Pod:

```bash
kubectl get pod <pod-name> -o wide
```

Check Pod details and scheduling events:

```bash
kubectl describe pod <pod-name>
```

Check all events:

```bash
kubectl get events --sort-by=.lastTimestamp
```

Check Node labels:

```bash
kubectl get nodes --show-labels
```

Check the specific workload label:

```bash
kubectl get nodes -L workload
```

Check Pod tolerations:

```bash
kubectl get pod <pod-name> -o yaml
```

---

# 21. Practice Exercises

After completing the guided lab, practice the following scenarios.

### Exercise 1 — NoSchedule

Create a taint:

```text
workload=production:NoSchedule
```

Create a normal Pod without a toleration.

**Question:** Where will the Pod be scheduled?

---

### Exercise 2 — Toleration

Create a Pod that tolerates:

```text
workload=production:NoSchedule
```

Check whether the Pod can use the tainted Node.

**Question:** Does the toleration guarantee that the Pod will run on that Node?

---

### Exercise 3 — Dedicated Production Node

Create:

```text
Taint:
workload=production:NoSchedule

Label:
workload=production
```

Then create a Pod with:

```text
Toleration
+
Node Affinity
```

Verify that it runs on the intended Node.

---

### Exercise 4 — PreferNoSchedule

Change the effect to:

```text
PreferNoSchedule
```

Create a normal Pod.

Observe where the Scheduler places it.

**Question:** Why is `PreferNoSchedule` considered a soft restriction?

---

### Exercise 5 — NoExecute

Apply:

```text
workload=critical:NoExecute
```

Create a Pod without a matching toleration.

Observe the behavior.

Then create a Pod with:

```yaml
tolerationSeconds: 30
```

Observe what happens when the taint remains.

---

# 22. Key Concepts

```text
                 TAINTS & TOLERATIONS
                          |
             +------------+------------+
             |                         |
          Taint                    Toleration
             |                         |
           Node                        Pod
             |                         |
        "Keep away"                "Allow me"
             |                         |
             +------------+------------+
                          |
                          v
                    Scheduler
                          |
                          v
                   Pod Placement
```

### Production Pattern

```text
Taint
  |
  v
Protect dedicated Node

Toleration
  |
  v
Allow specific workload

Node Affinity
  |
  v
Select the intended Node
```

## Final Rule

> **Taint controls what can enter a Node. Toleration gives a Pod permission to enter. Node Affinity determines which Node the Pod should actually use.**

---

# Quick Revision

```text
TAINT
  ↓
Applied to Node
  ↓
Repels Pods


TOLERATION
  ↓
Applied to Pod
  ↓
Allows Pod to tolerate the taint


NODE AFFINITY
  ↓
Applied to Pod
  ↓
Selects the intended Node
```

### Taint Effects

```text
NoSchedule
    ↓
Hard block for new Pods

PreferNoSchedule
    ↓
Soft preference to avoid Node

NoExecute
    ↓
Block new Pods
+
Evict existing Pods
```

### Most Important Production Pattern

```text
Dedicated Node
      |
      | Taint
      | workload=database:NoSchedule
      |
      v
Protect Node
      |
      v
Database Pod
      |
      +---- Toleration ----> Allowed
      |
      +---- Node Affinity -> Selected
      |
      v
Dedicated Database Node
```
