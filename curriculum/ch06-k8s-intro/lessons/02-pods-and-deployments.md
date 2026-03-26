# Lesson 2: Pods and Deployments

## The Smallest Thing That Runs

In Docker, the atomic unit is a **container**. In Kubernetes, the atomic unit is a **Pod**.

A Pod is a wrapper around one or more containers that:
- Share the same **network namespace** (they have one IP address between them)
- Share the same **storage volumes** (they can read/write the same mounted directories)
- Are always **scheduled together** on the same node
- Live and die together — if the Pod is deleted, all its containers go with it

In the vast majority of cases, a Pod contains exactly one container. Multi-container Pods are a real pattern (called "sidecar"), but start by thinking of Pod = container.

### Why Not Just Use Containers Directly?

Kubernetes doesn't schedule containers — it schedules Pods. This indirection exists because:

1. Some workloads genuinely need tightly-coupled processes (a web server + a log shipper that must run on the same machine and share a volume)
2. The Pod abstraction gives K8s a consistent unit regardless of what's inside

The practical consequence: you'll always write Pod specs, never bare container specs.

---

## Pod YAML Anatomy

Every Kubernetes resource is defined in a YAML manifest. Here's the most minimal Pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: learn-nginx-pod
  namespace: learn-ch06
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.25
      ports:
        - containerPort: 80
```

Let's walk through every field:

**`apiVersion: v1`**
The API version that defines this resource type. Pods use the core API (`v1`). Other resources use group-versioned APIs like `apps/v1` (Deployments) or `networking.k8s.io/v1` (Ingress). Always check the K8s docs for the correct `apiVersion` — it changes between K8s versions.

**`kind: Pod`**
The type of resource. K8s uses this to know which schema to validate against and which controller to hand it off to.

**`metadata`**
Data *about* the resource.
- `name`: The unique identifier for this resource within its namespace
- `namespace`: Which namespace this resource belongs to
- `labels`: Key-value pairs attached to the resource. Labels are how Kubernetes resources find each other — Services, Deployments, and others use label selectors to target specific Pods.

**`spec`**
The desired state — what you actually want to run.
- `containers`: A list of containers in this Pod
- `name`: A name for this specific container (for logs and exec commands)
- `image`: The container image, same format as Docker (`image:tag`)
- `ports`: Informational only — K8s doesn't use this for network rules, but it documents intent and some tools read it

### The Four Universal Fields

Every Kubernetes resource (Pod, Deployment, Service, ConfigMap, etc.) has these four top-level fields:

| Field | Purpose |
|-------|---------|
| `apiVersion` | Which API schema defines this resource |
| `kind` | What type of resource this is |
| `metadata` | Identity: name, namespace, labels, annotations |
| `spec` | Desired state: what you want |

Once you know these four fields, every K8s manifest becomes readable.

---

## Why You Rarely Create Pods Directly

Here's a trap beginners fall into: creating Pods directly.

```bash
kubectl apply -f pod.yaml   # Creates the Pod
kubectl delete pod learn-nginx-pod   # Pod is gone — and stays gone
```

When you delete a Pod directly, it's gone. Nobody recreates it. There's no self-healing.

Pods on their own are mortal. They don't self-heal. For self-healing and scaling, you need a **Deployment**.

---

## Deployments: Declaring Desired State

A **Deployment** is a higher-level resource that manages a set of identical Pods. You tell it:
- What container image to run
- How many replicas you want
- How to roll out updates

The Deployment creates a **ReplicaSet**, which creates and manages the actual Pods. The chain looks like this:

```
Deployment
  └── ReplicaSet
        ├── Pod (replica 1)
        ├── Pod (replica 2)
        └── Pod (replica 3)
```

You typically interact with the Deployment (not the ReplicaSet directly). The ReplicaSet is an implementation detail that Kubernetes manages for you. When you do a rolling update, the Deployment creates a *new* ReplicaSet with the updated image and scales the old one down.

### Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-nginx
  namespace: learn-ch06
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "200m"
```

#### New Fields Explained

**`spec.replicas: 3`**
How many Pod copies you want running. The ReplicaSet controller ensures this count is always maintained.

**`spec.selector.matchLabels`**
This is how the Deployment knows *which Pods it owns*. Any Pod with `app: nginx` in its labels is considered part of this Deployment. This selector must match the labels in `spec.template.metadata.labels` — if they don't match, the Deployment won't work.

**`spec.template`**
A Pod template — the blueprint for every Pod this Deployment creates. It has `metadata` (with labels) and `spec` (with containers), just like a standalone Pod manifest.

**`resources.requests` and `resources.limits`**
- `requests`: What the container is *guaranteed* to get. The Scheduler uses this to decide which node has enough room.
- `limits`: The maximum the container can use. If it exceeds the memory limit, it gets OOMKilled (you'll see this in Chapter 7).
- CPU is measured in millicores: `100m` = 0.1 CPU core
- Memory uses standard suffixes: `64Mi` = 64 mebibytes

Setting resource limits is considered a best practice for production. Without them, a single runaway process can starve other Pods on the node.

---

## The ReplicaSet and Self-Healing

When you apply the Deployment above, here's what happens internally:

1. You POST the Deployment manifest to the API Server
2. API Server stores it in etcd
3. The Deployment controller creates a ReplicaSet with `replicas: 3`
4. The ReplicaSet controller notices 0 Pods exist but 3 are desired — creates 3 Pod specs
5. The Scheduler assigns each Pod to a node
6. kubelet on each node pulls the image and starts the container
7. The ReplicaSet controller watches for changes. If a Pod dies, it creates a replacement.

Step 7 is the self-healing loop. It runs constantly, not just at startup.

---

## Essential kubectl Commands

### Applying Manifests

```bash
# Apply a manifest (create or update)
kubectl apply -f deployment.yaml

# Apply everything in a directory
kubectl apply -f ./manifests/

# Delete resources defined in a manifest
kubectl delete -f deployment.yaml
```

`kubectl apply` is idempotent — you can run it multiple times safely. It compares the manifest to the current cluster state and applies only the differences. This is the recommended way to manage resources.

### Getting Resource Status

```bash
# List Pods in the learn-ch06 namespace
kubectl get pods -n learn-ch06

# List Pods with more detail (node, IP address)
kubectl get pods -n learn-ch06 -o wide

# List Deployments
kubectl get deployments -n learn-ch06

# List ReplicaSets
kubectl get replicasets -n learn-ch06

# Watch resources in real time (like docker stats but for K8s events)
kubectl get pods -n learn-ch06 --watch
```

Sample output of `kubectl get pods -n learn-ch06`:
```
NAME                            READY   STATUS    RESTARTS   AGE
learn-nginx-7d5f4c9b6b-4xkzp   1/1     Running   0          2m
learn-nginx-7d5f4c9b6b-8qntr   1/1     Running   0          2m
learn-nginx-7d5f4c9b6b-vw9lx   1/1     Running   0          2m
```

The Pod names follow the pattern: `<deployment-name>-<replicaset-hash>-<pod-hash>`. This is why you don't hardcode Pod names — they're ephemeral and auto-generated.

**STATUS column cheat sheet:**

| Status | Meaning |
|--------|---------|
| `Pending` | Scheduled but not yet started (pulling image, waiting for node) |
| `Running` | All containers are running |
| `CrashLoopBackOff` | Container keeps crashing; K8s keeps trying with backoff |
| `ImagePullBackOff` | Can't pull the container image (bad tag, no registry access) |
| `Terminating` | Pod is being deleted |
| `OOMKilled` | Container exceeded its memory limit and was killed |
| `Completed` | Container ran to completion (for Jobs) |

### Inspecting Resources

```bash
# Full details on a Pod (events, conditions, container state)
kubectl describe pod <pod-name> -n learn-ch06

# Full details on a Deployment
kubectl describe deployment learn-nginx -n learn-ch06

# Get the YAML of a running resource
kubectl get deployment learn-nginx -n learn-ch06 -o yaml
```

`kubectl describe` is your first debugging tool. The **Events** section at the bottom tells the story of what happened to a resource — image pull failures, scheduling errors, probe failures, all appear there.

### Reading Logs

```bash
# Logs from a specific Pod
kubectl logs <pod-name> -n learn-ch06

# Follow logs in real time (like docker logs -f)
kubectl logs <pod-name> -n learn-ch06 -f

# Logs from a previous container instance (useful after CrashLoopBackOff)
kubectl logs <pod-name> -n learn-ch06 --previous

# Logs from all Pods with a specific label
kubectl logs -l app=nginx -n learn-ch06
```

### Exec Into a Container

```bash
# Open a shell inside a running container
kubectl exec -it <pod-name> -n learn-ch06 -- /bin/sh

# Run a one-off command without staying attached
kubectl exec <pod-name> -n learn-ch06 -- env
```

### Deleting Resources

```bash
# Delete a specific Pod (Deployment will recreate it — that's the point)
kubectl delete pod <pod-name> -n learn-ch06

# Delete a Deployment (and all its Pods)
kubectl delete deployment learn-nginx -n learn-ch06

# Delete everything in the namespace
kubectl delete all --all -n learn-ch06
```

---

## Scaling a Deployment

```bash
# Scale to 5 replicas imperatively
kubectl scale deployment learn-nginx --replicas=5 -n learn-ch06

# Or update the YAML and re-apply (preferred — keeps your YAML as source of truth)
# Edit replicas: 5 in the YAML file, then:
kubectl apply -f deployment.yaml
```

Watch the scale-up happen in real time:
```bash
kubectl get pods -n learn-ch06 --watch
```

---

## Updating an Image (Rolling Update)

When you update the image in your Deployment YAML and re-apply, Kubernetes performs a **rolling update** by default:

1. Creates a new ReplicaSet with the new image
2. Scales the new ReplicaSet up one Pod at a time
3. Scales the old ReplicaSet down one Pod at a time
4. Ensures at least `maxUnavailable` Pods stay running at all times

```bash
# Check rollout status
kubectl rollout status deployment/learn-nginx -n learn-ch06

# See rollout history
kubectl rollout history deployment/learn-nginx -n learn-ch06

# Rollback to previous version
kubectl rollout undo deployment/learn-nginx -n learn-ch06
```

---

## Summary

| Concept | What it is |
|---------|-----------|
| Pod | The smallest deployable unit; wraps one or more containers sharing network and storage |
| Deployment | Declares desired state for a set of Pods; manages rolling updates and self-healing |
| ReplicaSet | Maintained by Deployment; ensures the correct number of Pod replicas are running |
| `kubectl apply` | Apply a manifest (create or update) — idempotent |
| `kubectl get` | List resources and their status |
| `kubectl describe` | Full details + events for a resource |
| `kubectl logs` | Container output |
| `kubectl exec` | Run a command inside a running container |
| `resources.requests` | Guaranteed resources; used by Scheduler for placement |
| `resources.limits` | Maximum resources; exceeding memory limit causes OOMKill |

---

Up next: [Lesson 3 — Services and Networking](03-services-and-networking.md)

Your Pods are running. But nobody outside the cluster can reach them yet — and Pods can't reliably find *each other* either, because their IPs change every time they restart. Time to talk about Services.
