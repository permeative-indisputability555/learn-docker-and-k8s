# Challenge 2: Zero-Downtime Update

> **Sarah:** "The morning rush is live and we need to update the frontend from nginx 1.24 to 1.25. In the old days, Dave would restart the server at 2 AM and call it 'planned maintenance.' We do it differently. We do it while users are watching, and nothing breaks."

---

## The Situation

The `learn-frontend` Deployment is running `nginx:1.24` with 3 replicas. A security patch is available in `nginx:1.25` and it needs to go out today. The business requirement: **zero failed requests during the update**.

A continuous curl loop will be running throughout the update. You will see every request's HTTP status code. When the update completes, you will count the failures. The target is zero.

---

## Setup

Apply the starting Deployment:

```bash
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: learn-frontend
  namespace: learn-ch07
spec:
  replicas: 3
  selector:
    matchLabels:
      app: learn-frontend
  template:
    metadata:
      labels:
        app: learn-frontend
    spec:
      containers:
        - name: nginx
          image: nginx:1.24
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 2
            periodSeconds: 3
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: learn-frontend
  namespace: learn-ch07
spec:
  selector:
    app: learn-frontend
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
EOF
```

Wait for the Deployment to be ready:

```bash
kubectl rollout status deployment/learn-frontend -n learn-ch07
```

---

## The Continuous Curl Loop

Open a second terminal. Start this loop and **leave it running** throughout the entire challenge:

```bash
# Port-forward the Service in the background
kubectl port-forward service/learn-frontend 8088:80 -n learn-ch07 &
PORT_FWD_PID=$!

echo "Port-forward PID: $PORT_FWD_PID"
echo "Starting request loop. Press Ctrl+C to stop."
echo ""

FAIL_COUNT=0
PASS_COUNT=0

while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8088 2>/dev/null)
  TIMESTAMP=$(date +%T)
  if [ "$STATUS" = "200" ]; then
    echo "[$TIMESTAMP] HTTP $STATUS OK"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "[$TIMESTAMP] HTTP $STATUS FAIL <---"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
  sleep 0.5
done
```

You should see a steady stream of `HTTP 200 OK` lines. That is your baseline.

When you are done, stop the loop with `Ctrl+C`, then:

```bash
kill $PORT_FWD_PID 2>/dev/null
echo ""
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
```

---

## Your Mission

With the curl loop running in the second terminal, perform a rolling update of `learn-frontend` from `nginx:1.24` to `nginx:1.25`.

**Requirements:**

1. The Deployment must use a rolling update strategy with `maxSurge: 1` and `maxUnavailable: 0`
2. The image must be updated to `nginx:1.25`
3. The curl loop in the second terminal must show **zero failures** (`FAIL` lines) from the moment you trigger the update to the moment it completes

**You decide the approach:** edit and re-apply your manifest, or use `kubectl set image`. Both work.

---

## What to Watch

In your primary terminal, while the update runs:

```bash
# Watch pod transitions in real time
kubectl get pods -n learn-ch07 -w
```

You will see new pods spin up with new names, reach `Running` state, and old pods terminate. The curl loop should continue showing `200` the whole time.

```bash
# Check rollout progress
kubectl rollout status deployment/learn-frontend -n learn-ch07
```

---

## Bonus: Simulate a Bad Deploy and Roll Back

Once you have completed the zero-downtime update successfully, try this:

1. Trigger an update to a non-existent image tag: `nginx:9.99.99`
2. Watch the new pods fail to start (`ImagePullBackOff`)
3. Notice that the old pods are still running (because `maxUnavailable: 0` — K8s won't remove them until new ones are ready)
4. Roll back with `kubectl rollout undo`
5. Confirm the curl loop kept returning `200` throughout

This is why rollback exists. The old ReplicaSet is still around, waiting.

---

## Hints

<details>
<summary>Hint 1: Setting the update strategy</summary>

The rolling update strategy is configured inside the Deployment spec, not at the top level. It belongs under `spec.strategy`:

```yaml
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    ...
```

Add this block to your Deployment YAML and re-apply it before triggering the image update. Or you can do both in one step: update the strategy and the image at the same time in the YAML, then apply.

</details>

<details>
<summary>Hint 2: Triggering the image update</summary>

Two options:

**Option A — Edit and apply your manifest:**
Change the image from `nginx:1.24` to `nginx:1.25` in your YAML file and run `kubectl apply -f deployment.yaml`. Kubernetes detects the change and starts a rolling update.

**Option B — kubectl set image (no file needed):**
```bash
kubectl set image deployment/learn-frontend nginx=nginx:1.25 -n learn-ch07
```
The format is `deployment/<name> <container-name>=<new-image>:<tag>`. The container name is `nginx` (as defined in the manifest above).

Both approaches trigger an identical rolling update.

</details>

<details>
<summary>Hint 3: The curl loop is showing failures</summary>

If you see `FAIL` lines in your curl loop, there are a few things to check:

First, confirm your strategy is set correctly. Run `kubectl get deployment learn-frontend -n learn-ch07 -o yaml` and look at `spec.strategy`. Both `maxSurge` and `maxUnavailable` should be present.

Second, check if the `maxUnavailable: 0` is actually in effect. Kubernetes won't remove an old pod until the new one passes its readiness check. If your pods have no readiness probe, Kubernetes considers them Ready the moment the container starts — which is before nginx is actually accepting connections. Adding a readiness probe ensures the pod is truly ready before traffic is routed to it:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 3
  periodSeconds: 3
```

Third, check if the port-forward is still running. If the port-forward process dies during the test, all subsequent curls will fail with connection refused, not HTTP errors. The curl command will output an empty string or `000` for the status code.

</details>

---

## Verification

After the update completes, check your curl loop output:

- Every line should show `HTTP 200 OK`
- Zero `FAIL` lines
- The final summary should read `X passed, 0 failed`

Then verify in Kubernetes:

```bash
# Confirm all pods are running the new image
kubectl get pods -n learn-ch07 -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# Confirm the rollout history shows the update
kubectl rollout history deployment/learn-frontend -n learn-ch07
```

Run the verify script:

```bash
bash curriculum/ch07-k8s-production/challenges/verify.sh
```

---

> **Sarah:** "That's what zero-downtime deployment looks like. No maintenance windows. No 2 AM alerts. Users kept ordering their morning lattes the entire time. Dave's going to see a rollout history and have no idea anything changed — which is exactly how it should be."

**Next:** [Challenge 03 — Autoscaling](03-autoscaling.md)
