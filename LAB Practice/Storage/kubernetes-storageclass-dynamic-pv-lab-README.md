# Kubernetes StorageClass & Dynamic PV Provisioning Lab on AWS EC2

This lab demonstrates production-style **dynamic storage provisioning** on a Kubernetes cluster created with `kubeadm` on AWS EC2.

## Lab Environment

```text
AWS
├── EC2 - Control Plane
└── EC2 - Worker Node
       └── Kubernetes Pod
              └── PVC
                    ↓
              StorageClass
                    ↓
             EBS CSI Driver
                    ↓
             Amazon EBS Volume
                    ↓
             PersistentVolume
```

### What this lab demonstrates

- StorageClass
- PersistentVolumeClaim (PVC)
- Dynamic PersistentVolume (PV) provisioning
- AWS EBS CSI Driver
- `WaitForFirstConsumer`
- EBS volume creation in AWS
- Pod mounting persistent storage
- Data persistence after Pod recreation
- PVC/PV lifecycle
- Reclaim policy
- Optional volume expansion

> **Important:** This is a kubeadm cluster, not EKS. Therefore, AWS does not automatically install/manage the EBS CSI driver for this cluster. We install the CSI driver ourselves.

---

# 1. Static vs Dynamic Provisioning

## Static provisioning

The administrator creates the storage first:

```text
Admin
  ↓
Create EBS volume
  ↓
Create PV
  ↓
User creates PVC
  ↓
PVC binds to PV
```

This becomes difficult to manage at scale.

## Dynamic provisioning

With dynamic provisioning:

```text
Developer
    ↓
PersistentVolumeClaim
    ↓
StorageClass
    ↓
EBS CSI Driver
    ↓
AWS API
    ↓
Amazon EBS Volume
    ↓
PersistentVolume
    ↓
PVC becomes Bound
    ↓
Pod mounts volume
```

Kubernetes dynamically provisions a volume when a PVC requests a StorageClass that supports dynamic provisioning.


---

# 2. Production Architecture

For AWS, use the **Amazon EBS CSI Driver**.

```text
                     Kubernetes
                         │
                     StorageClass
                         │
                    ebs.csi.aws.com
                         │
                         ↓
                 EBS CSI Controller
                         │
                    AWS API calls
                         │
                         ↓
                  Amazon EBS Volume
                         │
                         ↓
                    CSI Node Plugin
                         │
                         ↓
                       Node
                         │
                         ↓
                       Pod
```

The old in-tree AWS EBS plugin should not be used for modern Kubernetes. Kubernetes removed the in-tree `awsElasticBlockStore` plugin in v1.27; use the EBS CSI driver instead.

---

# 3. Prerequisites

You should already have:

- AWS account
- 1 EC2 control-plane node
- 1 EC2 worker node
- kubeadm cluster working
- `kubectl` working
- Container runtime working
- CNI installed
- AWS CLI configured
- Helm installed
- An AWS IAM identity/role with the permissions required by the EBS CSI controller

Check the cluster:

```bash
kubectl get nodes -o wide
```

Expected:

```text
NAME            STATUS   ROLES           AGE
k8s-master      Ready    control-plane   ...
k8s-worker      Ready    <none>          ...
```

---

# 4. Check the Worker Availability Zone

EBS volumes are Availability-Zone-specific.

Find the worker's AZ:

```bash
kubectl get node k8s-worker   -o jsonpath='{.metadata.labels.topology.kubernetes.io/zone}{"\n"}'
```

Also check:

```bash
kubectl get nodes --show-labels
```

You should see labels such as:

```text
topology.kubernetes.io/zone=ap-south-1a
topology.kubernetes.io/region=ap-south-1
```

If the zone label is missing, inspect:

```bash
kubectl describe node k8s-worker
```

> `WaitForFirstConsumer` is particularly useful with topology-constrained storage such as EBS because provisioning can wait until Kubernetes knows where the consuming Pod will run.

Reference: https://kubernetes.io/docs/concepts/storage/storage-classes/

---

# 5. Install the AWS EBS CSI Driver

## Why do we need it?

Kubernetes needs a CSI driver to integrate with the external AWS EBS storage system.

AWS recommends the EBS CSI driver for EBS-backed Kubernetes storage.

For a kubeadm cluster, you install and manage the driver yourself.

# 6. IAM Permissions

The EBS CSI controller needs AWS permissions to perform operations such as:

- CreateVolume
- DeleteVolume
- AttachVolume
- DetachVolume
- DescribeVolume
- CreateSnapshot

For production, use a dedicated IAM identity mechanism for the CSI controller rather than putting long-lived AWS access keys in Kubernetes YAML.

For this lab, use an appropriate AWS IAM role/credential mechanism that your CSI controller can access.

If provisioning fails with:

```text
UnauthorizedOperation
AccessDenied
```

check the AWS permissions first.


---

# 7. Install EBS CSI Driver with Helm

Add the Helm repository:

```bash
helm repo add aws-ebs-csi-driver   https://kubernetes-sigs.github.io/aws-ebs-csi-driver
```

Update:

```bash
helm repo update
```

Install:

```bash
helm upgrade --install aws-ebs-csi-driver   aws-ebs-csi-driver/aws-ebs-csi-driver   -n kube-system
```

Check:

```bash
kubectl get pods -n kube-system | grep ebs-csi
```

You should see components similar to:

```text
ebs-csi-controller-xxxxx
ebs-csi-node-xxxxx
```

Check the CSI driver:

```bash
kubectl get csidriver
```

Expected:

```text
ebs.csi.aws.com
```

---

# 8. Troubleshoot the CSI Driver

If the controller is not running:

```bash
kubectl get pods -n kube-system
```

Describe it:

```bash
kubectl describe pod <ebs-csi-controller-pod> -n kube-system
```

Check logs:

```bash
kubectl logs <ebs-csi-controller-pod> -n kube-system
```

Check the node plugin:

```bash
kubectl get pods -n kube-system -o wide | grep ebs-csi-node
```

---

# 9. Create the StorageClass

Create:

`storageclass-ebs.yaml`

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass

metadata:
  name: ebs-gp3

provisioner: ebs.csi.aws.com

parameters:
  type: gp3
  fsType: ext4
  encrypted: "true"

reclaimPolicy: Delete

volumeBindingMode: WaitForFirstConsumer

allowVolumeExpansion: true
```

Apply:

```bash
kubectl apply -f storageclass-ebs.yaml
```

Check:

```bash
kubectl get storageclass
```

Detailed:

```bash
kubectl describe storageclass ebs-gp3
```

---

# 10. Understand the StorageClass

## provisioner

```yaml
provisioner: ebs.csi.aws.com
```

Tells Kubernetes to use the AWS EBS CSI driver.

## type

```yaml
type: gp3
```

Requests an AWS EBS gp3 volume.

## encrypted

```yaml
encrypted: "true"
```

Requests an encrypted EBS volume.

## reclaimPolicy

```yaml
reclaimPolicy: Delete
```

For this lab, dynamically provisioned storage is configured to be deleted when the claim is deleted.

For important production data, you may choose:

```yaml
reclaimPolicy: Retain
```

depending on your data-protection policy.

Kubernetes supports `Delete` and `Retain`.


## volumeBindingMode

```yaml
volumeBindingMode: WaitForFirstConsumer
```

Instead of immediately provisioning the EBS volume:

```text
PVC
 ↓
Wait
 ↓
Pod scheduled
 ↓
Determine AZ
 ↓
Create EBS in correct AZ
```

This is important for topology-aware storage.

## allowVolumeExpansion

```yaml
allowVolumeExpansion: true
```

Allows the PVC to request a larger volume later.

You can grow a volume, but you cannot shrink it through Kubernetes volume expansion.

---

# 11. Create the PVC

Create:

`pvc.yaml`

```yaml
apiVersion: v1
kind: PersistentVolumeClaim

metadata:
  name: app-data

spec:
  accessModes:
    - ReadWriteOnce

  storageClassName: ebs-gp3

  resources:
    requests:
      storage: 5Gi
```

Apply:

```bash
kubectl apply -f pvc.yaml
```

Check:

```bash
kubectl get pvc
```

Initially you may see:

```text
NAME       STATUS    VOLUME   CAPACITY
app-data   Pending
```

**This is expected** because the StorageClass uses:

```text
WaitForFirstConsumer
```

The volume waits for a Pod that consumes the PVC.

---

# 12. Create a Pod That Uses the PVC

Create:

`app.yaml`

```yaml
apiVersion: v1
kind: Pod

metadata:
  name: storage-demo

spec:
  containers:
  - name: nginx
    image: nginx:1.27

    volumeMounts:
    - name: app-storage
      mountPath: /data

  volumes:
  - name: app-storage
    persistentVolumeClaim:
      claimName: app-data
```

Apply:

```bash
kubectl apply -f app.yaml
```

Watch:

```bash
kubectl get pods -w
```

And:

```bash
kubectl get pvc
```

You should eventually see:

```text
NAME       STATUS   VOLUME                                     CAPACITY
app-data   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   5Gi
```

---

# 13. Observe Dynamic Provisioning

Run:

```bash
kubectl get pv
```

You should see a dynamically created PV:

```text
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY
pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   5Gi        RWO            Delete
```

You did **not** manually create this PV.

That is the key point:

```text
PVC
 ↓
StorageClass
 ↓
CSI Driver
 ↓
AWS EBS
 ↓
PV automatically created
 ↓
PVC Bound
```

---

# 14. Verify the EBS Volume in AWS

Open:

```text
AWS Console
 → EC2
 → Elastic Block Store
 → Volumes
```

You should find a new EBS volume.

You can also use:

```bash
aws ec2 describe-volumes --region <your-region>
```

The volume will have CSI/Kubernetes metadata and tags depending on the driver version/configuration.

This is a very useful classroom demonstration:

```text
Kubernetes PVC
      ↓
StorageClass
      ↓
EBS CSI Driver
      ↓
AWS EC2 API
      ↓
New EBS Volume
```

---

# 15. Verify the Pod Mount

Check the filesystem:

```bash
kubectl exec -it storage-demo -- df -h
```

Check `/data`:

```bash
kubectl exec -it storage-demo -- ls -ld /data
```

Create data:

```bash
kubectl exec -it storage-demo -- sh -c 'echo "Hello from Kubernetes persistent storage" > /data/test.txt'
```

Read it:

```bash
kubectl exec -it storage-demo -- cat /data/test.txt
```

Expected:

```text
Hello from Kubernetes persistent storage
```

---

# 16. Demonstrate Persistence

Delete the Pod:

```bash
kubectl delete pod storage-demo
```

Create it again:

```bash
kubectl apply -f app.yaml
```

Wait:

```bash
kubectl get pod -w
```

Read the data:

```bash
kubectl exec -it storage-demo -- cat /data/test.txt
```

Expected:

```text
Hello from Kubernetes persistent storage
```

Explain:

> The Pod was deleted, but the PVC and EBS volume remained, so the replacement Pod mounted the same persistent storage.

---

# 17. Inspect All Storage Objects

Run:

```bash
kubectl get storageclass
```

```bash
kubectl get pvc
```

```bash
kubectl get pv
```

```bash
kubectl get pods -o wide
```

Then:

```bash
kubectl describe pvc app-data
```

```bash
kubectl describe pv <pv-name>
```

```bash
kubectl describe pod storage-demo
```

These commands are also useful for production troubleshooting.

---

# 18. Demonstrate Reclaim Policy

Check:

```bash
kubectl get pv
```

You should see:

```text
RECLAIM POLICY
Delete
```

This lab uses `Delete`.

> **Warning:** The following step is destructive. Do not run it against important production data.

Delete the Pod:

```bash
kubectl delete pod storage-demo
```

Then delete the PVC:

```bash
kubectl delete pvc app-data
```

Check:

```bash
kubectl get pv
```

Then verify AWS:

```bash
aws ec2 describe-volumes --region <your-region>
```

With the `Delete` reclaim policy, the dynamically provisioned PV and underlying EBS volume are expected to be removed by the CSI provisioning workflow.

---

# 19. Production Reclaim Policy

For important production data:

```yaml
reclaimPolicy: Retain
```

Conceptually:

```text
PVC deleted
    ↓
PV retained
    ↓
Storage retained
    ↓
Administrator decides what to do
```

This is useful when automatic deletion of data is unacceptable.

---

# 20. LAB — Volume Expansion

Create the PVC again if you deleted it:

```bash
kubectl apply -f pvc.yaml
kubectl apply -f app.yaml
```

The StorageClass contains:

```yaml
allowVolumeExpansion: true
```

Change the PVC from:

```yaml
resources:
  requests:
    storage: 5Gi
```

to:

```yaml
resources:
  requests:
    storage: 10Gi
```

Or use:

```bash
kubectl patch pvc app-data   -p '{"spec":{"resources":{"requests":{"storage":"10Gi"}}}}'
```

Check:

```bash
kubectl get pvc app-data
```

Then:

```bash
kubectl describe pvc app-data
```

Kubernetes supports volume expansion for supported CSI storage when `allowVolumeExpansion` is enabled.


---

# 21. Production Scenario

In a real organization, developers normally don't create EBS volumes manually.

The platform team provides StorageClasses such as:

```text
ebs-gp3
ebs-io2
efs
```

Then:

```text
Platform Team
     │
     ├── ebs-gp3
     ├── ebs-io2
     └── efs
            │
            ↓
       Developers
            │
            ↓
          PVC
            │
            ↓
          Pod
```

The developer only needs to specify:

```yaml
storageClassName: ebs-gp3
```

They don't need to know the AWS API calls required to create an EBS volume.

---

# 22. EBS vs EFS

## EBS

```text
Pod
 ↓
EBS
```

EBS is block storage and is commonly used for workloads that need block storage, such as databases and stateful applications.

A typical EBS access mode is:

```text
ReadWriteOnce
```

## EFS

```text
Pod 1 ─┐
Pod 2 ─┼── EFS
Pod 3 ─┘
```

EFS is a shared network filesystem and can be used when multiple Pods/nodes need shared filesystem access, depending on configuration.

---

# 23. Important EBS Limitation

EBS is Availability-Zone specific.

Example:

```text
Region: ap-south-1

AZ-A
 └── EBS Volume

AZ-B
 └── Pod
```

The Pod cannot simply attach that EBS volume from another AZ.

This is one reason:

```yaml
volumeBindingMode: WaitForFirstConsumer
```

is important for topology-aware dynamic provisioning.

---

# 24. Troubleshooting

## PVC stuck in Pending

```bash
kubectl describe pvc app-data
```

Check:

```bash
kubectl get storageclass
```

Check CSI:

```bash
kubectl get pods -n kube-system | grep ebs
```

Check events:

```bash
kubectl get events --sort-by=.lastTimestamp
```

---

## EBS CSI controller errors

```bash
kubectl logs -n kube-system <ebs-csi-controller-pod>
```

Look for:

```text
UnauthorizedOperation
AccessDenied
failed to provision volume
```

These commonly indicate AWS permission/credential problems.

---

## Pod stuck in ContainerCreating

Run:

```bash
kubectl describe pod storage-demo
```

Look for:

```text
FailedAttachVolume
FailedMount
```

Check:

```bash
kubectl get volumeattachment
```

And:

```bash
kubectl describe pv <pv-name>
```

---

# 25. Complete Lab Flow

```text
                Developer
                    │
                    ↓
                   PVC
              "I need 5Gi"
                    │
                    ↓
              StorageClass
                ebs-gp3
                    │
                    ↓
             EBS CSI Driver
                    │
              AWS API calls
                    │
                    ↓
             Amazon EBS 5Gi
                    │
                    ↓
           PersistentVolume
                    │
                    ↓
               PVC Bound
                    │
                    ↓
                   Pod
                    │
                    ↓
              /data mounted
```

### Key concept

> **The developer creates the PVC. The StorageClass tells Kubernetes which provisioner and storage parameters to use. The CSI driver communicates with AWS and dynamically creates the EBS volume. Kubernetes then creates/binds the PV and the Pod mounts the volume.**

---
