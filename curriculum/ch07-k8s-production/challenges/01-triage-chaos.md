# Challenge 1: Triage the Chaos

> **Sarah:** "Okay. This is it. Three things are broken simultaneously and Dave's phone is in airplane mode somewhere over the Atlantic. I'm going to give you the broken manifests and the tools. You're going to tell me what's wrong with each one and fix it. I'll be right here if you need a hint."

---

## The Situation

It is 6:47 AM. The incident channel has three active alerts:

1. **`api` Deployment** — `ImagePullBackOff`. Pods are stuck at 0/3. (Hint: look at the image tag carefully.)
2. **`worker` Deployment** — `OOMKilled`. Restart count is climbing.
3. **`app-config` ConfigMap** — Database credentials are visible in pod logs. A security alert fired.

All three need to be fixed before the 7 AM morning rush.

---

## Setup: Apply the Broken State

First, create the namespace and apply all the broken manifests:

```bash
kubectl create namespace learn-ch07
```

Save the following as `broken-state.yaml` and apply it:

```yaml
# ============================================================
# BROKEN MANIFEST 1: api Deployment
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: learn-ch07
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
        - name: api
          image: nginx:latestt
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "64Mi"
              cpu: "100m"
            limits:
              memory: "128Mi"
              cpu: "250m"

---
# ============================================================
# BROKEN MANIFEST 2: worker Deployment
# ============================================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
  namespace: learn-ch07
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
        - name: worker
          image: nginx:1.25
          resources:
            requests:
              memory: "8Mi"
              cpu: "50m"
            limits:
              memory: "10Mi"
              cpu: "100m"

---
# ============================================================
# BROKEN MANIFEST 3: ConfigMap with credentials in plain text
# ============================================================
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: learn-ch07
data:
  LOG_LEVEL: "debug"
  API_BASE_URL: "https://api.cloudbrew.internal"
  DB_HOST: "postgres.cloudbrew.internal"
  DB_PORT: "5432"
  DB_NAME: "cloudbrew_production"
  DB_USER: "cloudbrew_admin"
  DB_PASSWORD: "Sup3rS3cr3tP@ssw0rd!"

---
# ============================================================
# A simple pod that loads the ConfigMap as env vars
# (this is what's leaking credentials into logs)
# ============================================================
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: learn-ch07
spec:
  containers:
    - name: app
      image: nginx:1.25
      envFrom:
        - configMapRef:
            name: app-config
```

```bash
kubectl apply -f broken-state.yaml
```

---

## Your Mission

Diagnose and fix all three issues. The criteria for success:

- All pods in `learn-ch07` are in `Running` state with `READY 1/1` (or `3/3` for the api Deployment)
- No pods have `ImagePullBackOff`, `CrashLoopBackOff`, or `OOMKilled` status
- The `app-config` ConfigMap contains no sensitive credentials
- A Secret named `db-credentials` exists in `learn-ch07` with the database user and password
- The `app-pod` Pod reads DB credentials from the Secret, not the ConfigMap

---

## Investigation Tools

```bash
# See the current state of all pods
kubectl get pods -n learn-ch07

# Get detailed information about what went wrong
kubectl describe pod <pod-name> -n learn-ch07

# Read pod logs
kubectl logs <pod-name> -n learn-ch07

# See the previous container's logs (useful for OOMKilled)
kubectl logs <pod-name> -n learn-ch07 --previous

# Inspect a ConfigMap
kubectl get configmap app-config -n learn-ch07 -o yaml

# Inspect a Secret
kubectl get secret db-credentials -n learn-ch07 -o yaml
```

---

## Hints

Work through these one at a time. Read the hint for the issue you are stuck on, then try to fix it yourself before moving on.

<details>
<summary>Hint 1: ImagePullBackOff on the api Deployment</summary>

Run `kubectl describe pod` on one of the `api` pods. Look at the Events section at the bottom. You will see the exact error message from the image pull attempt.

Read the image name in the manifest very carefully. Compare it to a valid Docker Hub image tag format. Look for something that looks almost right but is not — specifically, look at the tag after the colon.

Once you find the typo, fix the image tag in your manifest to `nginx:latest` and apply it again. Or use `kubectl set image` to update it directly without editing the file.

</details>

<details>
<summary>Hint 2: OOMKilled on the worker Deployment</summary>

Run `kubectl describe pod` on the `worker` pod. Look at "Last State" — you will see "Reason: OOMKilled" and "Exit Code: 137".

Then look at the resource limits in the manifest. The `worker` container is running `nginx:1.25`. A basic nginx process uses roughly 5–20 MB of memory just to start. Look at the `limits.memory` value. It is 10 megabytes. That is almost certainly less than nginx needs to initialize.

Increase `limits.memory` and `requests.memory` to values that give nginx room to operate. After applying the fix, watch the pod status. It should go to `Running` and stay there.

</details>

<details>
<summary>Hint 3: Database credentials in the ConfigMap</summary>

ConfigMaps are for non-sensitive configuration. The fields `DB_USER` and `DB_PASSWORD` in `app-config` are sensitive credentials — they must not live in a ConfigMap.

Your fix has two parts:

1. Remove `DB_USER` and `DB_PASSWORD` from the `app-config` ConfigMap. Keep the non-sensitive fields (`LOG_LEVEL`, `API_BASE_URL`, `DB_HOST`, `DB_PORT`, `DB_NAME`).

2. Create a Kubernetes Secret named `db-credentials` in the `learn-ch07` namespace containing `DB_USER` and `DB_PASSWORD`.

3. Update `app-pod` to continue reading the ConfigMap for non-sensitive config, but read `DB_USER` and `DB_PASSWORD` from the Secret instead.

After applying your changes, run `kubectl logs app-pod -n learn-ch07` and confirm the credentials are no longer visible.

</details>

---

## Verification

When you think you are done, run:

```bash
bash curriculum/ch07-k8s-production/challenges/verify.sh
```

Or check manually:

```bash
# All pods should be Running
kubectl get pods -n learn-ch07

# ConfigMap should not contain DB_USER or DB_PASSWORD
kubectl get configmap app-config -n learn-ch07 -o yaml

# Secret should exist with the credentials
kubectl get secret db-credentials -n learn-ch07
```

---

> **Sarah:** "Three fires, three fixes. This is the job. Notice what you did: you didn't panic, you read the error messages, and you followed the evidence. That's all incident response is."

**Next:** [Challenge 02 — Zero-Downtime Update](02-zero-downtime-update.md)
