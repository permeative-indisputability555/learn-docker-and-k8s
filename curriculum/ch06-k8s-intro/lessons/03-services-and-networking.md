# Lesson 3: Services and Networking

## The Problem With Pod IPs

Remember how we talked about Pods being mortal? They get killed and recreated constantly — during scaling, rolling updates, node failures, and manual deletions. Every time a Pod is recreated, it gets a **new IP address**.

This creates a fundamental networking problem: how does one service reliably reach another if the target's IP keeps changing?

In Docker, we solved this with user-defined bridge networks and built-in DNS: containers could find each other by name. In Kubernetes, we solve it with **Services**.

A Service is a stable, virtual endpoint that sits in front of a group of Pods. It has a fixed IP address (the **ClusterIP**) and a DNS name that never changes. Traffic to the Service gets load-balanced across all healthy Pods matching its selector.

Think of it this way: instead of calling individual baristas by their direct line (which changes every shift), you call the coffee bar's main number (the Service). The same number always works, regardless of who's on shift that day.

---

## How Services Find Pods: Labels and Selectors

Services don't reference Pods by name. They use **label selectors** — they claim ownership of any Pod that has certain labels.

```yaml
# In a Service spec:
selector:
  app: nginx          # "Give me all Pods with app=nginx"
  environment: prod   # AND environment=prod
```

```yaml
# In a Pod's metadata:
labels:
  app: nginx
  environment: prod
```

Any Pod with these labels in the same namespace becomes a backend for this Service. Add a new Pod with the same labels and it automatically joins the Service's pool. Remove or crash a Pod and the Service stops routing to it.

This decoupling is deliberate. Services and Pods are managed independently. You can scale Pods up or down without touching the Service definition. You can change which Pods a Service targets just by changing their labels.

---

## Service Types

### ClusterIP (default)

The most common type. Creates a virtual IP address that's only reachable **inside the cluster**.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: learn-ch06
spec:
  type: ClusterIP     # This is the default — you can omit it
  selector:
    app: backend
  ports:
    - protocol: TCP
      port: 80        # Port the Service listens on
      targetPort: 3000  # Port the container is actually running on
```

When you create this Service, Kubernetes:
1. Allocates a virtual IP from the cluster's service CIDR range (e.g., `10.96.0.1`)
2. Creates a DNS record: `backend-svc.learn-ch06.svc.cluster.local`
3. Programs iptables rules on every node to forward traffic to that VIP → healthy backend Pods

Any Pod in the cluster can now reach the backend at:
- `http://backend-svc` (works within the same namespace)
- `http://backend-svc.learn-ch06` (works from any namespace)
- `http://backend-svc.learn-ch06.svc.cluster.local` (fully qualified)

The short form `backend-svc` works because Kubernetes configures Pod DNS search domains. When a Pod looks up `backend-svc`, DNS appends `.learn-ch06.svc.cluster.local` and resolves it.

ClusterIP is the right choice for **internal service-to-service communication** — backend APIs, databases, caches. Things that should not be exposed to the outside world.

### NodePort

Exposes the Service on a port on every node in the cluster. External traffic can reach the Service at `<any-node-IP>:<nodePort>`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: learn-ch06
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
    - protocol: TCP
      port: 80          # ClusterIP port (still accessible internally)
      targetPort: 8080  # Container port
      nodePort: 30080   # External port on every node (range: 30000-32767)
```

NodePort is useful for:
- Testing and development when you need external access
- Clusters without a cloud load balancer (bare-metal, kind)

For kind clusters, you can access the app at `localhost:<nodePort>` if you configure port mapping in the kind cluster config. More commonly, you'll use `kubectl port-forward` instead (covered below).

Limitation: NodePort exposes a port on *every* node. Traffic can arrive at any node, regardless of whether that node has a running Pod. kube-proxy routes it correctly, but this adds network hops.

### LoadBalancer

The cloud-native way to expose a Service externally. When you create a LoadBalancer Service, Kubernetes talks to your cloud provider's API (AWS, GCP, Azure) and provisions an actual cloud load balancer (like an AWS ALB or GCP Network Load Balancer).

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-svc
  namespace: learn-ch06
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 8080
```

After a moment, `kubectl get service frontend-svc` will show an external IP assigned by the cloud provider. Traffic to that IP goes to the cloud load balancer, which distributes it across your nodes, which route it to your Pods.

In kind (local), LoadBalancer type Services will stay in `<pending>` for the external IP because there's no cloud provider. Use NodePort or `kubectl port-forward` for local access instead.

### Service Type Summary

| Type | Reachable From | Use Case |
|------|---------------|----------|
| ClusterIP | Inside cluster only | Internal APIs, databases, caches |
| NodePort | Any node IP + port | Dev/test external access, bare metal |
| LoadBalancer | Cloud-provisioned IP | Production external access on cloud |
| ExternalName | DNS alias | Pointing cluster DNS at external services |

---

## Service YAML Deep Dive

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-svc
  namespace: learn-ch06
  labels:
    app: backend        # Labels on the Service itself (optional but good practice)
spec:
  type: ClusterIP
  selector:
    app: backend        # Which Pod labels to match
  ports:
    - name: http        # Optional name — useful with multiple ports
      protocol: TCP
      port: 80          # The Service's port (what callers use)
      targetPort: 3000  # The container's port (what Pods are actually listening on)
```

**`port` vs `targetPort`:**
- `port`: What you call the Service on (e.g., `http://backend-svc:80`)
- `targetPort`: Where traffic actually lands inside the container

This decoupling is intentional. You can change the container's listening port without changing the port that all callers use.

---

## Verifying Service Endpoints

When you create a Service, Kubernetes creates an **Endpoints** object that tracks the actual Pod IPs backing the Service.

```bash
# See the Endpoints for a Service
kubectl get endpoints backend-svc -n learn-ch06
```

If the Endpoints list is empty (`<none>`), the Service's selector isn't matching any Pods. Check:
1. Do the Pods have the right labels? (`kubectl get pods --show-labels -n learn-ch06`)
2. Are the Pods `Running`? (Endpoints only include healthy Pods)
3. Does the selector in the Service match the labels exactly? (case-sensitive)

This is one of the most common debugging steps for "my Service isn't working" problems.

---

## kubectl port-forward: Local Testing

For local development and testing with kind, `kubectl port-forward` creates a tunnel from your laptop to a Pod or Service inside the cluster.

```bash
# Forward localhost:8080 to port 80 on the Service
kubectl port-forward service/frontend-svc 8080:80 -n learn-ch06

# Forward localhost:8080 to a specific Pod
kubectl port-forward pod/<pod-name> 8080:80 -n learn-ch06
```

While this command is running, you can access the app at `http://localhost:8080` in your browser. Press Ctrl+C to stop the tunnel.

`port-forward` bypasses all kube-proxy routing and connects directly to the Pod — useful for debugging. It's not meant for production traffic.

---

## Under the Hood: How K8s Networking Works

This is the "Linux fundamentals" section. You don't need to memorize this to use K8s, but understanding it helps when things go wrong.

### Virtual IPs and iptables

When you create a ClusterIP Service, Kubernetes allocates a virtual IP. This IP is not assigned to any real interface — it's a **virtual address** that exists only in iptables rules.

**kube-proxy** (running on every node) watches the API Server for Service and Endpoints changes. When they change, it updates iptables rules on the node:

```
Traffic to 10.96.0.50:80 (ClusterIP)
  └─► iptables DNAT rule: forward to one of:
        10.244.1.5:3000 (Pod 1)
        10.244.2.8:3000 (Pod 2)
        10.244.1.9:3000 (Pod 3)
```

The DNAT (Destination NAT) rules replace the destination IP before the packet is forwarded. The client never knows which Pod it actually hit — it just sent to the Service IP and got a response.

### CoreDNS

Service DNS is handled by **CoreDNS**, which runs as a Deployment in the `kube-system` namespace. When a Pod's init process starts, Kubernetes injects DNS configuration into `/etc/resolv.conf` inside the Pod:

```
nameserver 10.96.0.10   # CoreDNS ClusterIP
search learn-ch06.svc.cluster.local svc.cluster.local cluster.local
```

This is why `http://backend-svc` works from within the same namespace — the search domain appends the FQDN automatically.

### Pod-to-Pod Networking (CNI)

Pods on different nodes need to communicate. Kubernetes delegates this to a **CNI (Container Network Interface) plugin**. kind uses `kindnet` by default.

The CNI plugin ensures:
- Every Pod gets a unique IP from a cluster-wide Pod CIDR (e.g., `10.244.0.0/16`)
- Any Pod can reach any other Pod's IP directly, regardless of which node they're on
- Node-to-node traffic is typically tunneled (VXLAN) or routed (BGP)

You don't configure CNI directly — it's set up when the cluster is created.

---

## Putting It All Together: A Complete Stack

Here's how a typical frontend → backend stack looks in K8s:

```
Internet
    │
    ▼
[NodePort Service: frontend-svc :30080]
    │
    ▼
[Frontend Pods (3 replicas)]   ──labels: app=frontend──►  frontend-svc selector
    │
    │  http://backend-svc:80
    ▼
[ClusterIP Service: backend-svc :80]
    │
    ▼
[Backend Pods (3 replicas)]    ──labels: app=backend───►  backend-svc selector
```

The frontend talks to the backend using `http://backend-svc:80` — the Service DNS name. It never needs to know individual Pod IPs.

---

## Summary

| Concept | What it is |
|---------|-----------|
| Service | A stable virtual endpoint (IP + DNS name) in front of a group of Pods |
| ClusterIP | Service type reachable only inside the cluster |
| NodePort | Service type reachable at `<node-ip>:<port>` from outside |
| LoadBalancer | Service type that provisions a cloud load balancer |
| Labels | Key-value pairs attached to K8s resources |
| Selectors | Filter expressions that match Pods by their labels |
| Endpoints | The actual Pod IPs backing a Service (auto-managed by K8s) |
| kube-proxy | Programs iptables rules on each node for Service routing |
| CoreDNS | Provides DNS for Service names inside the cluster |
| CNI | Plugin that handles Pod-to-Pod networking across nodes |
| `port-forward` | Tunnel from localhost to a Pod/Service (dev/debug only) |

---

That's the core of Kubernetes networking for this chapter. You now know:
- Why Pods need Services (ephemeral IPs)
- How Services use label selectors to find Pods
- The three main Service types and when to use each
- How to debug with `kubectl get endpoints`
- How `port-forward` works for local testing
- What kube-proxy and iptables are doing under the hood

Time to put it all into practice. Head to the challenges.

**Challenges:**
- [Challenge 1: Self-Healing](../challenges/01-self-healing.md)
- [Challenge 2: Service Discovery](../challenges/02-service-discovery.md)
- [Challenge 3: Debug the CrashLoop](../challenges/03-debug-crashloop.md)
