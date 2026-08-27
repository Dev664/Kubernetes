# LAB: Node Affinity & (Node Anti-Affinity)

Assuming Our existing KIND cluster is:



```
multi-cluster-control-plane
multi-cluster-worker
multi-cluster-worker2
```
we'll keep the same cluster.


## 1. Lets take a Production Scenario  Imagine we have a 3-tier application:

```
                  Users
                    ↓
               Load Balancer
                    ↓
              Frontend / Web
                    ↓
                Backend API
                    ↓
                 Database
```

In a larger production cluster, we may have dedicated Nodes:

```
                  Kubernetes Cluster
                         |
          +--------------+--------------+
          |                             |
      Worker-1                       Worker-2
      webapp                          backend
      frontend                        backend
          |                             |
       Web Pods                       API Pods

                         Worker-3
                           DB
                           |
                       Database Pods
```

Our KIND cluster has only **2 workers**, so we'll simulate this using:

```
multi-cluster-worker
        ↓
webapp / frontend

multi-cluster-worker2
        ↓
backend / db
```

---

# 2. Verify again your Current Cluster

```
kubectl get nodes
```

Expected:

```
NAME                          STATUS   ROLES
multi-cluster-control-plane   Ready    control-plane
multi-cluster-worker          Ready    <none>
multi-cluster-worker2         Ready    <none>
```

---

# 3. Add Production-Style Labels

We'll use:

```
role=webapp
role=backend
```

and additional application labels:
```
app-tier=frontend
app-tier=backend
app-tier=database
```

### Worker-1 → Web/Frontend


```
kubectl label node multi-cluster-worker role=webapp
kubectl label node multi-cluster-worker app-tier=frontend
```

### Worker-2 → Backend/Database

```
kubectl label node multi-cluster-worker2 role=backend
kubectl label node multi-cluster-worker2 app-tier=backend
```

Check:

```
kubectl get nodes -L role -L app-tier
```

Expected:

```
NAME                          role       app-tier
multi-cluster-control-plane
multi-cluster-worker          webapp     frontend
multi-cluster-worker2         backend    backend
```

---

# PART 1 — NODE AFFINITY REQUIRED

## Scenario

Your **Frontend/Web application** should run only on Nodes dedicated to web applications.

Requirement:

> `frontend` Pods MUST run on Nodes having `role=webapp`.

---

## 4. Create Frontend Pod


```
vi frontend-required.yaml
```

```
apiVersion: v1
kind: Pod

metadata:
  name: frontend-required

spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: role
            operator: In
            values:
            - webapp

  containers:
  - name: frontend
    image: nginx:1.27
```

Apply:

```
kubectl apply -f frontend-required.yaml
```

Check:

```
kubectl get pod frontend-required -o wide
```

Expected:

```
NAME                STATUS    NODE
frontend-required   Running   multi-cluster-worker
```

Because:

```
multi-cluster-worker
role=webapp
     ↓
    ✅

multi-cluster-worker2
role=backend
     ↓
    ❌
```

---

# 5. Now Change:

```
values:
- database
```

There is no:

```
role=database
```

Node.

Delete:

```
kubectl delete pod frontend-required
```

Apply again:

```
kubectl apply -f frontend-required.yaml
```

Check:

```
kubectl get pod frontend-required
```

Result:

```
```

```
NAME                READY   STATUS
frontend-required   0/1     Pending
```

Explanation :

> `requiredDuringSchedulingIgnoredDuringExecution` is a hard requirement. If no Node matches, the Pod remains Pending.

---

# PART 2 — PREFERRED NODE AFFINITY

Now let's say:

> Frontend should **prefer** webapp Nodes, but it doesn't absolutely require them.

Create:

```
```

```
vi frontend-preferred.yaml
```

```
```

```
apiVersion: v1
kind: Pod

metadata:
  name: frontend-preferred

spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:

      - weight: 100
        preference:
          matchExpressions:
          - key: role
            operator: In
            values:
            - webapp

  containers:
  - name: frontend
    image: nginx:1.27
```

Apply:

```
```

```
kubectl apply -f frontend-preferred.yaml
```

Check:

```
```

```
kubectl get pod frontend-preferred -o wide
```

The Scheduler prefers:

```
```

```
role=webapp
```

but this is not mandatory.

---

# 6.  Required vs Preferred

** Please note - This is an important interview question.

### Required

```
```

```
requiredDuringSchedulingIgnoredDuringExecution:
```

Means:

```
```

```
MUST satisfy
```

Example:

```
```

```
Frontend
   |
   ↓
role=webapp
   |
   +---- Match → Running
   |
   +---- No match → Pending
```

### Preferred

```
```

```
preferredDuringSchedulingIgnoredDuringExecution:
```

Means:

```
```

```
TRY to satisfy
```

Example:

```
```

```
Frontend
   |
   ↓
Prefer role=webapp
   |
   +---- Available → Prefer it
   |
   +---- Not available → Other suitable Node
```

---

# PART 3 — NODE ANTI-AFFINITY !!!

Now we'll review **Node Anti-Affinity / Node Avoidance**. Though we dont have anything directly to say Node-Anti-Affinity

Production scenario:

> Database workloads should NOT run on WebApp Nodes.

Our Web Node has:

```
```

```
role=webapp
```

We can tell the Database Pod:

```
```

```
Do NOT schedule me on role=webapp
```

---

# 7. Create Database Pod

```
```

```
vi database-anti-affinity.yaml
```

```
```

```
apiVersion: v1
kind: Pod

metadata:
  name: database-anti-affinity

spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:

        nodeSelectorTerms:
        - matchExpressions:
          - key: role
            operator: NotIn
            values:
            - webapp

  containers:
  - name: database
    image: nginx:1.27
```

Apply:

```
```

```
kubectl apply -f database-anti-affinity.yaml
```

Check:

```
```

```
kubectl get pod database-anti-affinity -o wide
```

It should use:

```
```

```
multi-cluster-worker2
role=backend
```

and avoid:

```
```

```
multi-cluster-worker
role=webapp
```

---

# 8. Understand `NotIn`

This:

```
```

```
operator: NotIn
values:
- webapp
```

means:

```
```

```
role=webapp       → ❌
role=backend      → ✅
role=database     → ✅
role=monitoring   → ✅
```

So we are effectively saying:

> Don't schedule this Pod on WebApp Nodes.

---
.............................................................................................................
.............................................................................................................

# PART 4 — PRODUCTION WEBAPP EXAMPLE

Let's make the scenario more realistic.

We want:

```
```

```
Frontend
    |
    ↓
Only WebApp Nodes
```

Use:

```
```

```
requiredDuringSchedulingIgnoredDuringExecution:
```

with:

```
```

```
role=webapp
```

---

# 9. Frontend Deployment

In production we normally have a **Deployment**, not a standalone Pod.

Create:

```
```

```
vi frontend-deployment.yaml
```

```
```

```
apiVersion: apps/v1
kind: Deployment

metadata:
  name: frontend

spec:
  replicas: 3

  selector:
    matchLabels:
      app: frontend

  template:
    metadata:
      labels:
        app: frontend

    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: role
                operator: In
                values:
                - webapp

      containers:
      - name: frontend
        image: nginx:1.27
        ports:
        - containerPort: 80
```

Apply:

```
```

```
kubectl apply -f frontend-deployment.yaml
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
frontend-xxxxx   Running   multi-cluster-worker
frontend-xxxxx   Running   multi-cluster-worker
frontend-xxxxx   Running   multi-cluster-worker
```

All replicas are placed on:

```
```

```
role=webapp
```

---

# PART 5 — BACKEND EXAMPLE

Now create a Backend Deployment.

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

    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: role
                operator: In
                values:
                - backend

      containers:
      - name: backend
        image: nginx:1.27
        ports:
        - containerPort: 8080
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

You should get:

```
```

```
NAME                        NODE
frontend-xxxxx              multi-cluster-worker
frontend-xxxxx              multi-cluster-worker
frontend-xxxxx              multi-cluster-worker

backend-xxxxx               multi-cluster-worker2
backend-xxxxx               multi-cluster-worker2
```

Now You can visually see **Node Affinity controlling workload placement**.

---

# PART 6 — PREFERRED + REQUIRED TOGETHER

This is a very useful production example.

Suppose you have:

```
```

```
role=webapp
zone=az1
```

and:

```
```

```
role=webapp
zone=az2
```

Your requirement could be:

> MUST run on WebApp Nodes, but preferably run in AZ1.

Then:

```
```

```
affinity:

  nodeAffinity:

    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: role
          operator: In
          values:
          - webapp

    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      preference:
        matchExpressions:
        - key: zone
          operator: In
          values:
          - az1
```

This is an excellent production explanation:

```
```

```
                Frontend Pod
                     |
               Node Affinity
                     |
             +-------+-------+
             |               |
          REQUIRED        PREFERRED
             |               |
        role=webapp        zone=az1
             |               |
          MUST be          Prefer it
             |               |
             +-------+-------+
                     |
                     ↓
                WebApp Node
```

---

# PART 7 — IMPORTANT: POD ANTI-AFFINITY

Now lets see something different.

Suppose you have:

```
```

```
Frontend Deployment
replicas: 3
```

You don't want all 3 replicas on the same Node.

That's **Pod Anti-Affinity**, not Node Anti-Affinity.

Example:

```
```

```
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:

    - weight: 100
      podAffinityTerm:
        topologyKey: kubernetes.io/hostname

        labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
            - frontend
```

Meaning:

> Prefer not to place another `frontend` Pod on the same Node.

Conceptually:

```
```

```
                 Frontend replicas

              +-------------------+
              |                   |
              ↓                   ↓

          Worker-1            Worker-2
             |                    |
         Frontend-1           Frontend-2
                                  |
                              Frontend-3
```

This improves availability.

In a real production cluster with many Nodes, you can spread replicas across different Nodes/AZs.

---



# 11. Cleanup Script

Create:

```
```

```
vi cleanup-affinity-lab.sh
```

```
```

```
#!/bin/bash

echo "========================================"
echo " Cleaning Node Affinity LAB"
echo "========================================"

echo
echo "Deleting LAB resources..."

kubectl delete pod frontend-required --ignore-not-found
kubectl delete pod frontend-preferred --ignore-not-found
kubectl delete pod database-anti-affinity --ignore-not-found

kubectl delete deployment frontend --ignore-not-found
kubectl delete deployment backend --ignore-not-found

echo
echo "Removing Node Labels..."

kubectl label node multi-cluster-worker role- --ignore-not-found
kubectl label node multi-cluster-worker app-tier- --ignore-not-found

kubectl label node multi-cluster-worker2 role- --ignore-not-found
kubectl label node multi-cluster-worker2 app-tier- --ignore-not-found

echo
echo "Checking Pods..."

kubectl get pods -o wide

echo
echo "Checking Nodes..."

kubectl get nodes -L role -L app-tier

echo
echo "========================================"
echo " Cleanup Completed"
echo "========================================"
```

Make executable:

```
```

```
chmod +x cleanup-affinity-lab.sh
```

Run:

```
```

```
./cleanup-affinity-lab.sh
```

**This script does NOT delete your KIND cluster.** It only removes the resources and labels created for this lab.

---

# Final Workflow Flow

```
```

```
                Kubernetes Scheduler
                        |
                        ↓
                  Node Labels
                        |
             +----------+----------+
             |                     |
             ↓                     ↓
       Node Affinity          Node Avoidance
             |                     |
        +----+----+                |
        |         |                |
        ↓         ↓                ↓
    REQUIRED  PREFERRED          NotIn
        |         |          DoesNotExist
        ↓         ↓                ↓
      MUST       TRY            AVOID
```
