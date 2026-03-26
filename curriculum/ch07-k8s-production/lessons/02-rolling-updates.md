# Lesson 2: Rolling Updates

> **Sarah:** "The `latest` tag incident this morning? That was a deployment with no update strategy. One bad push, three pods replaced simultaneously, zero fallback plan. Let me show you how deployments are supposed to work."

---

## The Problem with Replacing Everything at Once

Suppose you have a Deployment with 3 replicas running `learn-api:1.0`. You push `learn-api:2.0`. Without a strategy, Kubernetes would terminate all three old pods and start three new ones at the same time.

During that window:
- If `2.0` has a startup time of 10 seconds, you have 10 seconds of zero capacity
- If `2.0` has a bug, all three pods are now broken with no automatic recovery
- Your users are getting 503s

This is called a **Recreate** strategy, and there are exactly two valid reasons to use it: you are running a database with strict write ordering requirements, or you are doing a tutorial about what NOT to do.

For everything else, you want a **RollingUpdate**.

---

## Rolling Update Strategy

A rolling update replaces pods gradually: start some new ones, wait for them to be ready, terminate some old ones, repeat. At every point during the update, some version of your application is serving traffic.

Two parameters control the pace:

### maxSurge

How many extra pods can exist above your desired replica count during the update.

- `maxSurge: 1` with `replicas: 3` means K8s can have up to 4 pods running at once during the update
- `maxSurge: 25%` rounds up — with `replicas: 4`, this allows 1 extra pod (25% of 4 = 1)
- `maxSurge: 0` means no extra capacity is created — only valid if `maxUnavailable > 0`

### maxUnavailable

How many pods can be below Ready state during the update.

- `maxUnavailable: 0` means zero pods can go down — the update adds new pods before removing old ones (safest option, requires `maxSurge > 0`)
- `maxUnavailable: 1` means one pod can be unhealthy at a time
- `maxUnavailable: 25%` rounds down — with `replicas: 4`, this allows 1 pod to be unavailable

### Common configurations

**Zero downtime (recommended for production):**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```
With `replicas: 3`: K8s starts 1 new pod (total 4), waits for it to be Ready, then removes 1 old pod (total 3), repeats. You always have at least 3 ready pods.

**Fast update (accept brief capacity reduction):**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 1
```
Removes one old pod and adds one new pod simultaneously. Total pods oscillates between 2 and 4 with `replicas: 3`. Finishes twice as fast, but you briefly have less capacity.

**Full replacement (not recommended):**
```yaml
strategy:
  type: Recreate
```
Terminates all old pods, then starts all new pods. Causes downtime. Use only when necessary.

---

## Triggering a Rolling Update

The most common way to trigger a rollout is changing the container image. Kubernetes tracks this in the Deployment spec and initiates a rollout automatically when it detects a change.

**Changing the image tag in YAML then applying:**
```bash
# Edit the image in your deployment YAML from nginx:1.24 to nginx:1.25
kubectl apply -f deployment.yaml
```

**Using `kubectl set image` (no YAML file needed):**
```bash
kubectl set image deployment/learn-frontend \
  nginx=nginx:1.25 \
  -n learn-ch07
```

The format is: `deployment/<deployment-name> <container-name>=<new-image>:<tag>`

**Force a re-pull of the same image (useful for mutable tags — but please stop using mutable tags):**
```bash
kubectl rollout restart deployment/learn-frontend -n learn-ch07
```

This creates a new ReplicaSet and triggers a rolling update even if nothing in the spec changed.

---

## Monitoring a Rollout

```bash
# Watch the rollout in real time — this blocks until complete or times out
kubectl rollout status deployment/learn-frontend -n learn-ch07

# See the rollout history
kubectl rollout history deployment/learn-frontend -n learn-ch07

# See details about a specific revision
kubectl rollout history deployment/learn-frontend \
  --revision=2 \
  -n learn-ch07
```

While a rollout is happening, `kubectl get pods -n learn-ch07` will show you the transition: some pods with the old name pattern, some with the new name pattern, all in various states of Starting and Running.

```bash
# Watch pods change in real time
kubectl get pods -n learn-ch07 -w
```

---

## Rolling Back

Kubernetes keeps a history of your Deployments as ReplicaSets. When you roll back, K8s scales the previous ReplicaSet back up instead of creating a new one.

**Undo the last rollout:**
```bash
kubectl rollout undo deployment/learn-frontend -n learn-ch07
```

**Undo to a specific revision:**
```bash
# First check what revisions exist
kubectl rollout history deployment/learn-frontend -n learn-ch07

# Roll back to revision 2
kubectl rollout undo deployment/learn-frontend --to-revision=2 -n learn-ch07
```

**Watch the rollback happen:**
```bash
kubectl rollout status deployment/learn-frontend -n learn-ch07
```

A rollback is itself a rolling update — the same `maxSurge` and `maxUnavailable` rules apply.

### When rollback does NOT help

Rollback swaps the image tag. It does not:
- Restore data deleted by the buggy version
- Fix a database migration that ran during the update
- Undo changes made to external systems

For schema migrations and stateful operations, rollback is not the right tool. This is why database migrations should be backward-compatible: the old code should be able to run against the new schema, so you can roll back the application without rolling back the database.

---

## The `latest` Tag Problem

The incident this morning was triggered by a push with the `latest` tag. Here is why this is dangerous:

```yaml
image: learn-api:latest
```

When Kubernetes starts a pod, it pulls the image according to the `imagePullPolicy`. For `latest`, the default policy is `Always` — meaning every pod restart pulls the image again. This means:

- A new push to `latest` in your registry immediately affects any pod that restarts
- There is no "previous version" to roll back to — `latest` is whatever was pushed most recently
- Two pods started at different times might be running different builds of `latest`
- `kubectl rollout history` does not help you — every revision says `learn-api:latest`

**Use explicit, immutable image tags in production.** Common patterns:

- Git commit SHA: `learn-api:a3f8c12`
- Semantic version: `learn-api:2.4.1`
- Date + build number: `learn-api:20260326.42`

This gives you:
- Reproducibility: you know exactly what code is running
- Safe rollback: the previous image tag still exists in your registry
- Audit trail: you can trace a running pod back to a specific commit

---

## Blue-Green Deployments

A blue-green deployment maintains two complete, identical environments ("blue" and "green"). Only one is live at a time. To deploy a new version:

1. Deploy the new version to the inactive environment (say, green)
2. Run smoke tests against green
3. Switch the load balancer to point at green
4. Blue is now idle — keep it for immediate rollback if needed

**How this looks in Kubernetes:**

```yaml
# Blue deployment (currently live)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-frontend-blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-frontend
      slot: blue

---
# Service pointing at blue
apiVersion: v1
kind: Service
metadata:
  name: learn-frontend
spec:
  selector:
    app: learn-frontend
    slot: blue   # Change this to "green" to switch traffic
```

To cut over: update the Service selector from `slot: blue` to `slot: green`. The Service immediately routes to the green pods. Rollback is a one-line change back to `slot: blue`.

**Trade-offs:** Requires 2x the compute capacity during the transition. More expensive, but the safest possible deployment strategy for stateless services.

---

## Canary Deployments

A canary deployment sends a small percentage of traffic to the new version while the majority still goes to the old version. If the new version behaves well, gradually increase the percentage. If it misbehaves, route all traffic back to the old version.

**Simple canary with Kubernetes labels:**

If you have 10 pods total — 9 on `v1` and 1 on `v2` — and your Service selects on `app: learn-frontend` (both versions have this label), roughly 10% of traffic will hit `v2`. You watch error rates for `v2`. If they look good, scale `v2` up and scale `v1` down.

```yaml
# v1 deployment: 9 replicas
# v2 deployment: 1 replica
# Same Service selector: app: learn-frontend
```

**Full canary with Ingress-level traffic splitting** requires an Ingress controller that supports weighted routing (NGINX Ingress, Istio, Argo Rollouts). This gives you percentage-based traffic splitting independent of replica counts.

**When to use canary vs. rolling update:**
- Rolling update: standard releases, well-tested code, stateless services
- Canary: high-risk changes, new features you want to validate with real traffic, services where a bad release could have significant user impact

---

## Readiness and Liveness Probes

Rolling updates only work safely if Kubernetes knows when a pod is genuinely ready to receive traffic. This is what probes are for.

```yaml
readinessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  failureThreshold: 3
```

- **Readiness probe:** Is this pod ready to receive traffic? If it fails, the pod is removed from Service endpoints but is NOT restarted. During a rolling update, the new pod is not counted as "Ready" (and old pods are not removed) until the readiness probe passes.
- **Liveness probe:** Is this pod alive? If it fails, the pod is restarted. Use this to recover from deadlocks or infinite loops.

Without a readiness probe, Kubernetes considers a pod Ready the moment the container starts. Your pod could be in the middle of loading configuration or warming up a cache, and traffic is already being sent to it. A readiness probe prevents this.

---

## Quick Reference

```bash
# Trigger update
kubectl set image deployment/<name> <container>=<image>:<tag> -n <namespace>
kubectl apply -f deployment.yaml

# Monitor
kubectl rollout status deployment/<name> -n <namespace>
kubectl rollout history deployment/<name> -n <namespace>

# Rollback
kubectl rollout undo deployment/<name> -n <namespace>
kubectl rollout undo deployment/<name> --to-revision=<n> -n <namespace>

# Force restart (same image)
kubectl rollout restart deployment/<name> -n <namespace>
```

---

> **Sarah:** "The rule I give every engineer on their first day: never use `latest` in a manifest that goes anywhere near production. Use a git SHA. You'll thank yourself at 6 AM when you need to know exactly what's running."

**Next:** [Resource Management](03-resource-management.md)
