# LAB: Pod Affinity & Pod Anti-Affinity


### Lab Environment KIND cluster
```text
multi-cluster-control-plane
multi-cluster-worker
multi-cluster-worker2
```

This lab covers:

- Pod Affinity
- Pod Anti-Affinity
- Required vs Preferred rules
- `topologyKey`
- `labelSelector`
- Scheduling failures and troubleshooting
- Production-style Frontend/Backend scenarios


---

### Production scenario

```
                    Application
                        |
                +-------+-------+
                |               |
             Frontend         Backend
                |               |
             Pod(s)           Pod(s)
                |               |
                +-------+-------+
                        |
                     Database
```

We will check :

```
Pod Affinity
Frontend → Backend

Pod Anti-Affinity
Backend replica 1 ↔ Backend replica 2
```

---

# PART 1 — Check Your KIND Cluster

## 1. Verify Nodes

```
```

```
kubectl get nodes
```

Expected:

```
```

```
NAME                          STATUS   ROLES
multi-cluster-control-plane   Ready    control-plane
multi-cluster-worker          Ready    <none>
multi-cluster-worker2         Ready    <none>
```

We don't need to add Node labels for this lab.

The important thing here is that **Pod Affinity/Anti-Affinity works based on Pod labels and topology domains**, rather than Node labels.

---

# PART 2 — Create a Backend Pod

First, create a Backend Pod.

```
vi backend-pod.yaml
```
```
apiVersion: v1
kind: Pod

metadata:
  name: backend
  labels:
    app: backend
    tier: backend

spec:
  containers:
  - name: backend
    image: nginx:1.27
```

Apply:

```
kubectl apply -f backend-pod.yaml
```

Check:

```
kubectl get pod backend -o wide
```

For example:

```
NAME       READY   STATUS    NODE
backend    1/1     Running   multi-cluster-worker
```

The exact Node can vary.

---

# PART 3 — Understand `topologyKey`

Before creating Pod Affinity, You need to understand this field:

```
topologyKey: kubernetes.io/hostname
```

This tells Kubernetes the **topology domain** that should be considered.

With:

```
topologyKey: kubernetes.io/hostname
```

we are essentially saying:

> Consider Nodes with the same hostname as the same topology domain.

In simple terms for this lab:

```
```

```
Worker-1 = one topology domain
Worker-2 = another topology domain
```

So when we say:

> Place this Pod in the same topology domain as the Backend Pod

we effectively mean:

> Place it on the same Node as the Backend Pod.

---

# PART 4 — POD AFFINITY REQUIRED

## Scenario

Our Backend is already running.
Now suppose we want the Frontend Pod to run **on the same Node as the Backend**.
This is Pod Affinity.

```
```

```
Backend Pod
     |
     ↓
Frontend Pod
     |
 SAME NODE
```

---

## 4. Create Frontend Pod

```
vi frontend-affinity-required.yaml
```

```
apiVersion: v1
kind: Pod

metadata:
  name: frontend-affinity-required
  labels:
    app: frontend
    tier: frontend

spec:
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:

      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - backend

        topologyKey: kubernetes.io/hostname

  containers:
  - name: frontend
    image: nginx:1.27
```

Apply:
```
kubectl apply -f frontend-affinity-required.yaml
```

Check:
```
kubectl get pods -o wide
```
You should see something like:

```
NAME                         NODE
backend                      multi-cluster-worker
frontend-affinity-required   multi-cluster-worker
```

Both Pods are on the same Node.

---

# 5. Understand What Happened

The Frontend has:

```
podAffinity:
```
and:

```
labelSelector:
  matchExpressions:
  - key: app
    operator: In
    values:
    - backend
```

This means:

> Find a Pod whose label is `app=backend`.

Then:

```
topologyKey: kubernetes.io/hostname
```

means:

> The Frontend should be in the same hostname topology domain.

In our lab:

```
                 Scheduler
                     |
                     ↓
              Find app=backend
                     |
                     ↓
              backend Pod
                     |
               Same hostname
                     |
                     ↓
             multi-cluster-worker
                     |
              +------+------+
              |             |
           Backend       Frontend
```

---

# PART 5 — REQUIRED POD AFFINITY FAILURE

This is an excellent demonstration of what **required** means.

Change:

```
values:
- backend
```
to:


```
values:
- database
```

But we don't have a Pod with:

```
app=database
```

Delete the Frontend:

```
kubectl delete pod frontend-affinity-required
```

Apply again:

```
kubectl apply -f frontend-affinity-required.yaml
```

Check:

```
kubectl get pod frontend-affinity-required -o wide
```

It should be:


```
NAME                         READY   STATUS
frontend-affinity-required   0/1     Pending
```

Check why:

```
kubectl describe pod frontend-affinity-required
```

Look at:

```
Events:
```

### Teaching point

```
Required Pod Affinity
        |
        ↓
Matching Pod must exist
        |
    +---+---+
    |       |
   YES      NO
    |       |
Schedule   Pending
```

---

# PART 6 — POD AFFINITY PREFERRED

Now let's make the relationship **optional/preferred**.

Scenario:

> Prefer the Frontend to run on the same Node as Backend, but don't make it mandatory.

Create:

```
vi frontend-affinity-preferred.yaml
```

```
```

```
apiVersion: v1
kind: Pod

metadata:
  name: frontend-affinity-preferred
  labels:
    app: frontend-preferred
    tier: frontend

spec:
  affinity:
    podAffinity:

      preferredDuringSchedulingIgnoredDuringExecution:

      - weight: 100

        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - backend

          topologyKey: kubernetes.io/hostname

  containers:
  - name: frontend
    image: nginx:1.27
```

Apply:

```
```

```
kubectl apply -f frontend-affinity-preferred.yaml
```

Check:

```
```

```
kubectl get pods -o wide
```

The Scheduler will **prefer** the Node where the Backend is running.

But unlike `required`, it can choose another suitable Node if necessary.

---

# PART 7 — REQUIRED vs PREFERRED

Make students remember this:

### Required

```
```

```
requiredDuringSchedulingIgnoredDuringExecution:
```

Means:

> **MUST satisfy the condition.**

```
```

```
Backend exists on suitable Node
        ↓
Frontend can schedule

Backend doesn't exist
        ↓
Frontend Pending
```

### Preferred

```
```

```
preferredDuringSchedulingIgnoredDuringExecution:
```

Means:

> **TRY to satisfy the condition.**

```
```

```
Backend exists
      ↓
Prefer same topology

No suitable Backend relationship
      ↓
Can use another suitable Node
```

---

# PART 8 — POD ANTI-AFFINITY

Now we move to one of the most important production use cases.

Suppose we have:

```
```

```
Backend Deployment
replicas: 2
```

We don't want both replicas on the same Node.

Why?

Because if that Node fails:

```
```

```
Worker-1
   |
   +-- Backend-1
   +-- Backend-2
          ↓
       Node fails
          ↓
    Both replicas lost
```

Instead:

```
```

```
Worker-1              Worker-2
   |                     |
Backend-1             Backend-2
```

This is **Pod Anti-Affinity**.

---

# PART 9 — Create Backend Deployment

First clean up the single Backend Pod:

```
```

```
kubectl delete pod backend
```

Create:

```
```

```
vi backend-deployment.yaml
```

```
```

```
apiVersion: apps/v1
kind: Deployment

metadata:
  name: backend

spec:
  replicas: 2

  selector:
    matchLabels:
      app: backend

  template:
    metadata:
      labels:
        app: backend
        tier: backend

    spec:
      affinity:
        podAntiAffinity:

          requiredDuringSchedulingIgnoredDuringExecution:

          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - backend

            topologyKey: kubernetes.io/hostname

      containers:
      - name: backend
        image: nginx:1.27
```

Apply:

```
```

```
kubectl apply -f backend-deployment.yaml
```

Check:

```
```

```
kubectl get pods -o wide
```

You should see:

```
```

```
NAME                       NODE
backend-xxxxx              multi-cluster-worker
backend-yyyyy              multi-cluster-worker2
```

The two replicas are spread across the two worker Nodes.

---

# PART 10 — Understand Pod Anti-Affinity

The important part is:

```
```

```
podAntiAffinity:
```

and:

```
```

```
operator: In
values:
- backend
```

combined with:

```
```

```
topologyKey: kubernetes.io/hostname
```

It means:

> Don't place another `app=backend` Pod in the same hostname topology domain.

In our KIND cluster:

```
```

```
              Backend Deployment
                     |
                 replicas: 2
                     |
             Pod Anti-Affinity
                     |
             +-------+-------+
             |               |
             ↓               ↓
         Worker-1         Worker-2
             |               |
         Backend-1       Backend-2
```

---

# PART 11 — What Happens If There Aren't Enough Nodes

This is an important production scenario.

You have:

```
```

```
2 worker Nodes
2 backend replicas
```

Perfect:

```
```

```
Worker-1 → Backend-1
Worker-2 → Backend-2
```

Now scale to 3:

```
```

```
kubectl scale deployment backend --replicas=3
```

Check:

```
```

```
kubectl get pods -o wide
```

Because we used:

```
```

```
requiredDuringSchedulingIgnoredDuringExecution:
```

and there are only **2 worker Nodes**, the third Pod cannot satisfy the anti-affinity rule.

You should see:

```
```

```
backend-xxxxx    Running    worker
backend-yyyyy    Running    worker2
backend-zzzzz    Pending    <none>
```

Check:

```
```

```
kubectl describe pod <pending-pod-name>
```

This demonstrates a very important production concept:

> **Hard Pod Anti-Affinity can prevent a Pod from scheduling when there aren't enough topology domains.**

---

# PART 12 — Change Anti-Affinity to PREFERRED

Now make the anti-affinity a soft rule.

Change:

```
```

```
requiredDuringSchedulingIgnoredDuringExecution:
```

to:

```
```

```
preferredDuringSchedulingIgnoredDuringExecution:
```

The structure becomes:

```
```

```
podAntiAffinity:

  preferredDuringSchedulingIgnoredDuringExecution:

  - weight: 100

    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - backend

      topologyKey: kubernetes.io/hostname
```

Now Kubernetes says:

> Prefer different Nodes, but if there aren't enough Nodes, allow the Pod to be scheduled on a Node that already has a Backend Pod.

This is often more flexible for production workloads.

---

# PART 13 — Required vs Preferred Anti-Affinity

### Required

```
```

```
Backend-1 → Worker-1
Backend-2 → Worker-2

Third replica?
      ↓
No third Node
      ↓
Pending
```

### Preferred

```
```

```
Backend-1 → Worker-1
Backend-2 → Worker-2

Third replica?
      ↓
No free Node
      ↓
Can share a Node
```

---

# PART 14 — Production Architecture Example

Now connect everything to a real application.

```
```

```
                         USERS
                           |
                           ↓
                      Load Balancer
                           |
                           ↓
                  +----------------+
                  |   Frontend     |
                  |   Deployment   |
                  +----------------+
                           |
                           ↓
                  +----------------+
                  |    Backend     |
                  |   Deployment   |
                  +----------------+
                           |
                           ↓
                       Database
```

### Pod Affinity

You might say:

> Place Backend Pods close to Frontend Pods.

```
```

```
Worker-1
+------------------+
| Frontend-1       |
| Backend-1        |
+------------------+

Worker-2
+------------------+
| Frontend-2       |
| Backend-2        |
+------------------+
```

### Pod Anti-Affinity

You might say:

> Don't put Backend replicas on the same Node.

```
```

```
Worker-1              Worker-2
+-----------+         +-----------+
| Backend-1 |         | Backend-2 |
+-----------+         +-----------+
```

This improves **high availability**.

---

# PART 15 — Important Difference for Students

This is worth putting on the board:

```
```

```
NODE AFFINITY
      |
      ↓
Pod → Node
"Which type of Node should I use?"
```

```
```

```
POD AFFINITY
      |
      ↓
Pod → Pod
"Which Pods should I stay close to?"
```

```
```

```
POD ANTI-AFFINITY
      |
      ↓
Pod → Pod
"Which Pods should I stay away from?"
```

---

# PART 16 — Cleanup Script

Since you're using the existing KIND cluster, the cleanup should **not delete the cluster**.

Create:

```
```

```
vi cleanup-pod-affinity-lab.sh
```

```
```

```
#!/bin/bash

echo "=========================================="
echo " Cleaning Pod Affinity LAB"
echo "=========================================="

echo
echo "Deleting Deployments..."

kubectl delete deployment backend --ignore-not-found

echo
echo "Deleting LAB Pods..."

kubectl delete pod frontend-affinity-required --ignore-not-found
kubectl delete pod frontend-affinity-preferred --ignore-not-found

echo
echo "Checking remaining resources..."

kubectl get pods -o wide

echo
echo "=========================================="
echo " Pod Affinity LAB Cleanup Completed"
echo "=========================================="
```

Make executable:

```
```

```
chmod +x cleanup-pod-affinity-lab.sh
```

Run:

```
```

```
./cleanup-pod-affinity-lab.sh
```
