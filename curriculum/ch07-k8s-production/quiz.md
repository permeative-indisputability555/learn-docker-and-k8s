# Chapter 7 Quiz: Production Kubernetes Operations

> **Sarah:** "Before you go, five questions. Not a trick — just making sure the concepts stick. These are the things people get wrong in production."

---

## Question 1

You find the following in a pod's manifest:

```yaml
envFrom:
  - configMapRef:
      name: app-config
```

And `app-config` contains:

```yaml
data:
  LOG_LEVEL: "debug"
  DB_PASSWORD: "s3cr3t!"
  API_URL: "https://api.internal"
```

**What is wrong with this configuration, and how should you fix it?**

A) Nothing is wrong. ConfigMaps are encrypted, so storing passwords in them is safe.

B) The `envFrom` syntax is incorrect. You must use individual `env` entries with `valueFrom.configMapKeyRef`.

C) `DB_PASSWORD` should not be stored in a ConfigMap. It should be in a Kubernetes Secret, and the pod should reference it with `valueFrom.secretKeyRef`.

D) This configuration is acceptable for staging environments but not production.

<details>
<summary>Answer</summary>

**C.**

ConfigMaps are not encrypted and are designed for non-sensitive configuration. Storing a database password in a ConfigMap means it is readable by anyone with `kubectl get configmap` access, it may appear in pod logs if the application prints its environment, and it has no additional access controls.

The correct fix: remove `DB_PASSWORD` from the ConfigMap, create a `Secret` containing it, and reference it in the pod spec with:

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: DB_PASSWORD
```

Option A is false — base64 encoding is not encryption. Option B is wrong — `envFrom` with a ConfigMap is valid syntax. Option D is also wrong — credentials in a ConfigMap are a security problem in any environment.

</details>

---

## Question 2

A pod shows the following in `kubectl describe`:

```
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
```

The pod's resource configuration is:

```yaml
resources:
  requests:
    memory: "64Mi"
  limits:
    memory: "128Mi"
```

**Which of the following is NOT a correct statement about this situation?**

A) The pod was killed by the Linux kernel's OOM killer.

B) Exit Code 137 means the process received SIGKILL (signal 9, and 128 + 9 = 137).

C) The pod exceeded its `limits.memory` value of 128Mi.

D) Increasing `requests.memory` to 128Mi will fix the OOMKilled condition.

<details>
<summary>Answer</summary>

**D.**

`requests.memory` tells the scheduler the minimum to reserve — it does not affect the limit at which the pod is killed. Increasing requests from 64Mi to 128Mi will not change the 128Mi ceiling at which the OOM killer fires.

To fix the OOMKilled condition, you must increase `limits.memory` to a value the pod can actually run within, or fix the memory leak in the application that is causing it to consume more than 128Mi.

Options A, B, and C are all correct statements about this situation.

</details>

---

## Question 3

You want to update the `learn-api` Deployment from `learn-api:v1.4` to `learn-api:v1.5`. Your Deployment has 4 replicas and is configured with:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

**How many pods will be running at the peak of the rolling update, and what is the minimum number of pods that will be available to serve traffic at any point during the update?**

A) Peak: 4 pods. Minimum available: 3 pods.

B) Peak: 5 pods. Minimum available: 4 pods.

C) Peak: 8 pods. Minimum available: 4 pods.

D) Peak: 5 pods. Minimum available: 3 pods.

<details>
<summary>Answer</summary>

**B.**

With `replicas: 4`, `maxSurge: 1`, and `maxUnavailable: 0`:

- `maxSurge: 1` means K8s can run at most `4 + 1 = 5` pods simultaneously. So the peak is 5.
- `maxUnavailable: 0` means zero pods can be unavailable at any time. The minimum available is always 4.

The update proceeds as: start 1 new pod (total 5), wait for it to be Ready, remove 1 old pod (total 4), repeat. At no point does available capacity drop below the desired replica count of 4.

</details>

---

## Question 4

A pod has these resource settings:

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "500m"
  limits:
    memory: "256Mi"
    cpu: "500m"
```

**What Quality of Service (QoS) class is this pod assigned, and what does that mean for eviction priority?**

A) BestEffort — this pod will be evicted first under node memory pressure because no limits are set.

B) Burstable — this pod can use more than its requests up to its limits, so it is in the middle tier.

C) Guaranteed — requests equal limits, so this pod is the last to be evicted under node memory pressure.

D) Guaranteed — but only if all containers in the pod have identical requests and limits.

<details>
<summary>Answer</summary>

**C** (with the clarification from D being important).

When `requests == limits` for both CPU and memory on a container, Kubernetes assigns the pod QoS class `Guaranteed`. Guaranteed pods are evicted last when the node is under memory pressure.

Option D is also partially true — the condition is that ALL containers in the pod must have `requests == limits`. If a pod has two containers and only one has matching requests/limits, the pod is `Burstable`, not `Guaranteed`. For a single-container pod like this one, C is the complete answer.

BestEffort applies when no resources are set at all. Burstable applies when resources are set but requests do not equal limits.

</details>

---

## Question 5

You run `kubectl get hpa -n learn-ch07` and see:

```
NAME                    REFERENCE                     TARGETS         MINPODS   MAXPODS   REPLICAS
learn-frontend-hpa      Deployment/learn-frontend     <unknown>/50%   2         10        2
```

The `TARGETS` column shows `<unknown>/50%` instead of an actual CPU percentage.

**What are the two most likely causes of this, and how would you diagnose them?**

A) The Deployment name is wrong in the HPA spec, and the namespace is incorrect.

B) The Metrics Server is not installed or not ready, or the target Deployment has no `requests.cpu` set on its containers.

C) The HPA was created with the wrong API version, and the target Deployment has no replicas running.

D) The HPA target utilization of 50% is invalid; it must be a value between 1 and 30.

<details>
<summary>Answer</summary>

**B.**

`<unknown>` in the TARGETS column means the HPA cannot read the current metric. The two most common causes are:

1. **Metrics Server is not installed or not ready.** The HPA reads CPU utilization from the Metrics Server. Without it, no metric is available. Check with `kubectl top pods -n learn-ch07` — if that errors, the Metrics Server is the problem.

2. **`requests.cpu` is not set on the Deployment's containers.** The HPA calculates CPU utilization as a percentage of the requested CPU. If `requests.cpu` is missing, utilization cannot be expressed as a percentage and the HPA reports `<unknown>`.

To diagnose: run `kubectl describe hpa learn-frontend-hpa -n learn-ch07` and read the Conditions and Events sections. The HPA will tell you exactly which condition is preventing it from getting metrics.

</details>

---

> **Sarah:** "Five for five? Good. Now go read the Graduation section. You've earned it."
