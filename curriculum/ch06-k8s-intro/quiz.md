# Chapter 6 Quiz: The Giant Roaster

Use this quiz to test your understanding before moving to Chapter 7 — or to unlock Chapter 6 if you're skipping ahead. You need 4 out of 5 correct to pass.

---

## Question 1

You have a Deployment with `replicas: 3`. You manually delete one Pod with `kubectl delete pod`. What happens next, and why?

**A)** The Pod stays deleted. Deployments only create Pods during the initial apply.

**B)** Kubernetes recreates the Pod automatically, because the ReplicaSet controller detects the actual count (2) is less than the desired count (3) and creates a replacement.

**C)** Kubernetes recreates the Pod, but you must run `kubectl apply` again to trigger the reconciliation.

**D)** The Deployment enters a degraded state and sends an alert, but does not automatically recover.

<details>
<summary>Answer</summary>

**B** — The ReplicaSet controller runs a continuous reconciliation loop comparing desired state vs. actual state. When actual (2) < desired (3), it creates a new Pod immediately. No `kubectl apply` is needed. This is the core self-healing behavior of Kubernetes.
</details>

---

## Question 2

A frontend Pod needs to call the backend API. The backend has 3 Pods running. Which approach should the frontend use to reach the backend, and why?

**A)** Look up the backend Pod IPs using `kubectl get pods` and hardcode one of them as the backend URL.

**B)** Call the backend's Service by its DNS name (e.g., `http://backend-svc`), which provides a stable endpoint regardless of which Pods are running or what IPs they have.

**C)** Use `kubectl port-forward` to expose the backend locally, then call `localhost` from the frontend.

**D)** Create a NodePort Service and call the node's external IP directly.

<details>
<summary>Answer</summary>

**B** — Pod IPs are ephemeral and change whenever a Pod is recreated (restarts, rolling updates, rescheduling). A Service provides a stable ClusterIP and DNS name that doesn't change. Hardcoding Pod IPs (A) breaks whenever Pods restart. Port-forward (C) is for local developer access, not inter-Pod communication. NodePort (D) works but is unnecessary for internal communication and adds external exposure.
</details>

---

## Question 3

You run `kubectl get endpoints backend-svc -n learn-ch06` and see:

```
NAME          ENDPOINTS   AGE
backend-svc   <none>      5m
```

What is the most likely cause?

**A)** The Service is still starting up — wait a few more minutes.

**B)** The backend Pods are not Running yet.

**C)** The Service's `selector` does not match the labels on the backend Pods.

**D)** ClusterIP Services do not have Endpoints — only NodePort Services do.

<details>
<summary>Answer</summary>

**C** is the most likely cause (B is also possible but less common). Kubernetes populates Endpoints by finding Pods whose labels match the Service's `selector`. If the selector has a typo or uses the wrong label key/value, no Pods match and Endpoints stays empty. This is the #1 debugging step for "Service not routing traffic": check that `spec.selector` in the Service exactly matches `metadata.labels` on the target Pods. Both B and C could cause empty endpoints, but a label mismatch is far more common than all Pods being down.
</details>

---

## Question 4

What is the role of **etcd** in a Kubernetes cluster?

**A)** etcd is the container runtime that pulls images and starts containers on worker nodes.

**B)** etcd is a distributed key-value store that holds the complete desired state of the cluster — every resource definition, every configuration, every secret.

**C)** etcd is the load balancer that distributes traffic to Pods via iptables rules.

**D)** etcd is the CNI plugin that assigns IP addresses to Pods.

<details>
<summary>Answer</summary>

**B** — etcd is the cluster's database. When you run `kubectl apply`, your manifest is ultimately stored in etcd. The API Server is the only component that reads and writes etcd directly. All other control plane components (Scheduler, Controller Manager) watch the API Server, not etcd directly. Losing etcd without a backup means losing the entire cluster's memory of what should be running.
</details>

---

## Question 5

A Pod is in `ImagePullBackOff` status. What does this mean, and what is your first diagnostic step?

**A)** The Pod ran to completion successfully. `ImagePullBackOff` is the status for finished Pods.

**B)** The container crashed after starting. Check `kubectl logs <pod-name>` to see the crash output.

**C)** Kubernetes cannot pull the container image — likely due to a wrong image name, bad tag, or missing registry credentials. The first diagnostic step is `kubectl describe pod <pod-name>` to read the Events section, which shows the exact image pull error.

**D)** The Pod is waiting for a PersistentVolume to be provisioned. `ImagePullBackOff` indicates a storage issue.

<details>
<summary>Answer</summary>

**C** — `ImagePullBackOff` means kubelet tried to pull the image and failed. The "BackOff" means Kubernetes is retrying with exponential delay. `kubectl describe pod` shows the Events section with the exact error (e.g., "repository does not exist", "unauthorized", "not found"). Common causes: typo in image name (like `ngnix` instead of `nginx`), nonexistent tag, private registry without pull secret, or Docker Hub rate limiting.
</details>

---

## Score

- **5/5** — You've got this. Chapter 7 won't know what hit it.
- **4/5** — Solid. One concept to review before moving on.
- **3/5 or below** — Worth rereading the lessons before moving to Chapter 7. The concepts in this chapter are foundational for everything that follows.
