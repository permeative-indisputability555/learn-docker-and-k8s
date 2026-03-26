# Lesson 3: Resource Management

> **Sarah:** "When I saw 'OOMKilled' in the incident channel this morning, I knew exactly what happened. Someone deployed a worker with no memory limit, a memory leak hit, and Kubernetes did the only thing it could: it killed the process. The fix is resource limits. The investigation is Exit Code 137. Let me walk you through both."

---

## Why Resource Management Matters

A Kubernetes node is a machine with a fixed amount of CPU and memory. Pods share that node. Without resource constraints:

- One misbehaving pod can consume all available memory and starve every other pod on the node
- A pod with a memory leak will grow until the node runs out of memory, then the kernel kills something — usually the largest consumer
- The scheduler cannot make good placement decisions because it does not know how much each pod needs
- You cannot guarantee performance for any service

Resource requests and limits are how you tell Kubernetes what each pod needs and what it is allowed to use.

---

## Requests and Limits

Every container in a pod can specify two values for CPU and memory:

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "250m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

### Requests

**The guaranteed minimum.** When the scheduler places a pod on a node, it reserves the requested resources for that pod. A pod is only placed on a node that has enough unreserved capacity to satisfy the request.

- If you request `128Mi` memory, the scheduler guarantees the pod will land on a node with at least `128Mi` free
- The pod might use less than `128Mi` — that's fine
- Other pods can use the unreserved remainder

Requests affect scheduling. They do not cap usage.

### Limits

**The hard ceiling.** If a pod tries to use more resources than its limit:

- **Memory:** The process is killed immediately by the Linux OOM (Out Of Memory) killer. The pod gets an Exit Code 137. Kubernetes marks it as `OOMKilled` and restarts it (if the restart policy allows).
- **CPU:** The process is throttled — it does not get more CPU cycles than the limit allows. It slows down. It is NOT killed. This is called CPU throttling.

Limits affect runtime behavior. They cap usage.

### Resource units

**CPU:**
- `1` = 1 vCPU core (or 1 physical core, depending on the node)
- `500m` = 500 millicores = 0.5 vCPU
- `100m` = 100 millicores = 0.1 vCPU
- Fractional cores are normal and expected

**Memory:**
- `256Mi` = 256 mebibytes (2^28 bytes) — use this notation
- `256M` = 256 megabytes (10^8 bytes) — similar but not identical
- `1Gi` = 1 gibibyte
- `1G` = 1 gigabyte
- Always use `Mi` and `Gi` to avoid confusion

---

## OOMKilled and Exit Code 137

### What happens step by step

1. Your pod's memory usage crosses its `limits.memory` value
2. The Linux kernel's OOM killer fires
3. The process is sent `SIGKILL` — no grace period, no cleanup
4. The container exits with code **137** (128 + 9, where 9 is the signal number for SIGKILL)
5. Kubernetes records the reason as `OOMKilled`
6. If `restartPolicy` is `Always` (the default for Deployments), Kubernetes restarts the pod
7. If the memory leak is still there, the pod will OOMKill again — and again — entering `CrashLoopBackOff`

### Reading the incident

```bash
kubectl get pods -n learn-ch07
# NAME                      READY   STATUS             RESTARTS   AGE
# worker-7d9b6f4d8-x4r2p    0/1     OOMKilled          4          12m

kubectl describe pod worker-7d9b6f4d8-x4r2p -n learn-ch07
# ...
# Last State:     Terminated
#   Reason:       OOMKilled
#   Exit Code:    137
#   Started:      Thu, 26 Mar 2026 06:33:12 +0000
#   Finished:     Thu, 26 Mar 2026 06:34:47 +0000
```

### Exit Code 137 is diagnostic

Exit Code 137 tells you: this process was killed by SIGKILL. In a Kubernetes pod with memory limits, this almost always means OOMKilled. The combination of:
- `Reason: OOMKilled` in `kubectl describe`
- `Exit Code: 137`
- A `limits.memory` value that is plausibly too low

...is a complete diagnostic picture.

### Fixing OOMKilled

Two possible causes, two different fixes:

**The limit is too low for the actual workload:**
Increase `limits.memory`. Look at the pod's memory usage over time (Prometheus, or `kubectl top pod`) to understand the real peak. Set the limit to at least 2x the normal working memory with headroom for spikes.

**The app has a memory leak:**
The limit is correct, but the app is broken. Increasing the limit buys time but does not fix the leak. You need to fix the code. As a temporary mitigation, a lower restart threshold gives you more uptime while the fix is being built.

---

## Quality of Service Classes

When a node runs out of memory and the OOM killer must choose what to terminate, it does not pick randomly. Kubernetes assigns each pod a **Quality of Service (QoS) class** based on its resource configuration. The OOM killer evicts lower-QoS pods first.

### Guaranteed

**Condition:** Every container in the pod has `requests` and `limits` set, AND `requests == limits` for both CPU and memory.

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

This pod is the last to be evicted under node memory pressure. Use this for your most critical services.

### Burstable

**Condition:** At least one container has requests or limits set, but not all containers have `requests == limits`.

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

The pod can burst above its requests up to its limits. Most production workloads should be here: you set a baseline (requests) and a ceiling (limits), and the pod can use whatever is available in between.

### BestEffort

**Condition:** No resources set at all. No requests, no limits.

```yaml
# No resources section
```

This pod gets whatever CPU and memory happen to be free. It is the first to be evicted when the node is under pressure. Never use BestEffort for anything you care about.

### Practical guidance

```
Critical service (database, payment processor): Guaranteed
Standard application pod: Burstable
Batch job that can tolerate termination: Burstable or BestEffort
```

Setting `requests == limits` (Guaranteed) is safe but wastes capacity — the scheduler reserves the full limit on the node even if the pod uses less. Setting `requests < limits` (Burstable) is more efficient: you reserve only what you need, and the pod can use more if the node has spare capacity.

---

## Horizontal Pod Autoscaler (HPA)

Setting fixed replica counts is fine when your traffic is predictable. It is not fine when a coffee influencer tweets about you and your traffic triples in two minutes.

The Horizontal Pod Autoscaler (HPA) automatically adjusts the replica count of a Deployment based on observed metrics. The most common metric is CPU utilization, but you can also scale on memory, custom metrics, or external metrics.

### How it works

The HPA controller runs in the control plane and polls the Metrics Server every 15 seconds. It compares the current average CPU utilization across all pods to the target you configured. If utilization is too high, it scales up. If it drops below the target for a sustained period, it scales down.

The scaling formula: `desiredReplicas = ceil(currentReplicas * (currentMetric / desiredMetric))`

If you have 2 pods averaging 80% CPU and your target is 50%, the HPA calculates `ceil(2 * (80/50)) = ceil(3.2) = 4`. It scales to 4 pods.

### Creating an HPA

**From the command line:**
```bash
kubectl autoscale deployment learn-frontend \
  --min=2 \
  --max=10 \
  --cpu-percent=50 \
  -n learn-ch07
```

**From YAML:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: learn-frontend-hpa
  namespace: learn-ch07
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: learn-frontend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

### Requirements for HPA to work

1. **Metrics Server must be installed.** In a kind cluster: `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`. In most managed clusters (EKS, GKE, AKS), it is already installed.
2. **The target Deployment must have CPU requests set.** The HPA measures utilization as a percentage of the requested CPU. If `requests.cpu` is not set, utilization cannot be calculated and the HPA will not scale.

### Checking HPA status

```bash
kubectl get hpa -n learn-ch07
# NAME                   REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS
# learn-frontend-hpa     Deployment/learn-front  23%/50%   2         10        2

kubectl describe hpa learn-frontend-hpa -n learn-ch07
# Shows events: when it scaled up, when it scaled down, why
```

### Scale-down delay

By default, the HPA waits 5 minutes before scaling down. This prevents flapping — where traffic drops briefly and you scale down, then traffic spikes again and you scale back up, burning time and pod startup costs. The scale-up decision is faster (15–30 seconds reaction time).

---

## LimitRange and ResourceQuota

Two namespace-level objects let you enforce resource policies across all pods:

**LimitRange:** Sets default requests and limits for pods that do not specify them. Prevents BestEffort pods from accidentally being created.

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: learn-ch07
spec:
  limits:
    - type: Container
      default:
        memory: "128Mi"
        cpu: "250m"
      defaultRequest:
        memory: "64Mi"
        cpu: "100m"
```

**ResourceQuota:** Caps the total resources that can be consumed by all pods in a namespace.

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: namespace-quota
  namespace: learn-ch07
spec:
  hard:
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"
    pods: "20"
```

These are production hygiene tools. For this chapter's challenges, you will set resources directly in your Deployments.

---

## Practical Sizing Guidelines

These are starting points, not rules. Profile your actual workload.

| Service type | Suggested requests | Suggested limits |
|---|---|---|
| Node.js web API | 100m CPU, 128Mi | 500m CPU, 256Mi |
| Python worker | 200m CPU, 256Mi | 1000m CPU, 512Mi |
| Go microservice | 50m CPU, 64Mi | 200m CPU, 128Mi |
| PostgreSQL (small) | 250m CPU, 256Mi | 1000m CPU, 1Gi |

When in doubt, start with requests lower than you think you need and limits higher than you think you need. Watch actual usage. Tighten over time.

---

## Quick Reference

```bash
# Check pod resource usage
kubectl top pod -n <namespace>
kubectl top node

# Check why a pod was killed
kubectl describe pod <pod-name> -n <namespace>
# Look for: Last State, Reason (OOMKilled), Exit Code (137)

# HPA status
kubectl get hpa -n <namespace>
kubectl describe hpa <name> -n <namespace>

# Create HPA
kubectl autoscale deployment <name> --min=2 --max=10 --cpu-percent=50 -n <namespace>
```

---

> **Sarah:** "Exit Code 137 used to feel like a cryptic error. Now you know it's just Kubernetes saying 'your pod asked for too much memory, so the kernel killed it.' Every time you see it, the question is the same: is the limit wrong, or is the app broken? Usually it's both."

**Now let's apply everything: [Challenge 01 — Triage the Chaos](../challenges/01-triage-chaos.md)**
