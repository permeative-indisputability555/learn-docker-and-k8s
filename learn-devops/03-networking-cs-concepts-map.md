# Networking & CS Concepts Mapped to Docker/K8s

Learning Docker and Kubernetes naturally exposes users to a wide range of core Networking, Linux, and Computer Science (CS) fundamentals by requiring them to manage isolated environments and orchestrated systems.

### 1. Networking Fundamentals
Working with container networks provides a hands-on laboratory for understanding the OSI model, particularly layers 2 through 4.

*   **Subnetting & Virtual Interfaces $\rightarrow$ Bridge Networks:** When Docker starts, it creates a virtual bridge interface (typically `docker0`) that acts like a virtual switch. This teaches users how **subnets** work, as every container on that bridge receives an IP address from a specific range.
*   **NAT & Port Forwarding $\rightarrow$ Port Mapping (`-p`):** Because containers are isolated, their internal services are not reachable by default. Mapping a host port to a container port teaches **Network Address Translation (NAT)** and how traffic is routed from a public-facing IP/port to a private one.
*   **Service Discovery $\rightarrow$ User-Defined Bridges & K8s Services:** On default bridges, containers must use IP addresses to communicate. Moving to **User-Defined Bridges** enables an embedded DNS server, teaching **DNS resolution** for service discovery. In Kubernetes, **Services** provide a stable **Virtual IP (VIP)** that abstracts away individual pod IPs, teaching internal **load balancing**.
*   **Layer 2 vs. Layer 3 Networking $\rightarrow$ Macvlan & IPvlan:** 
    *   **Macvlan** gives containers their own MAC addresses, making them appear as physical devices on the network, which teaches **Layer 2** concepts and requirements like **promiscuous mode**.
    *   **IPvlan L3 mode** turns the host into a **router**, teaching users about **routing tables** and why broadcast traffic (ARP) does not cross Layer 3 boundaries.
*   **HTTP Routing & TLS $\rightarrow$ Ingress:** Using a Kubernetes **Ingress** controller teaches **Layer 7 (Application Layer) routing** based on hostnames and paths, as well as **TLS termination** at the edge of a network.

### 2. Linux Fundamentals
Containers are essentially isolated Linux processes, forcing beginners to learn the underlying mechanics of the Linux kernel.

*   **Isolation $\rightarrow$ Namespaces:** Docker uses Linux **Namespaces** to provide isolated workspaces. By interacting with containers, users learn about the isolation of network stacks, process IDs (PIDs), and mount points.
*   **Resource Management $\rightarrow$ Cgroups:** Setting CPU and memory limits on containers is a direct application of Linux **Control Groups (cgroups)**, which manage and monitor system resources for groups of processes.
*   **Union Filesystems $\rightarrow$ Docker Image Layers:** Docker images utilize **Union Filesystems** (like OverlayFS) to stack multiple directories into a single, cohesive filesystem. This teaches the concept of **copy-on-write** and immutable layers.
*   **Process Management $\rightarrow$ PID 1 & Signal Handling:** Beginners learn that the main process in a container runs as **PID 1**, which has special responsibilities for handling **Unix signals** (like SIGTERM for graceful shutdowns).
*   **Routing Rules $\rightarrow$ Iptables/Nftables:** Kubernetes components like `kube-proxy` manage **iptables** or **nftables** rules to handle the "magic" of routing traffic through Service VIPs to actual pods.

### 3. Computer Science Fundamentals
The orchestration of containers introduces theoretical CS concepts through practical implementation.

*   **Ephemeral vs. Persistent State $\rightarrow$ Containers & Volumes:** Containers teach the "Twelve-Factor App" concept of **statelessness**. Using **Volumes** to store data independently of the container life cycle teaches users about data persistence and the risks of **ephemeral filesystems**.
*   **Desired State vs. Actual State $\rightarrow$ Kubernetes Controllers:** Kubernetes is built on the principle of a **reconciliation loop**, where the system constantly compares the "Desired State" (YAML config) with the "Actual State" (running pods) and takes action to match them. This is a fundamental concept in **control theory** and **declarative programming**.
*   **Immutability $\rightarrow$ Docker Images:** Images are read-only snapshots. This teaches the benefits of **immutable infrastructure**, where software is never patched "in place" but is instead rebuilt and redeployed to ensure consistency across environments.
*   **Distributed Systems & Consensus $\rightarrow$ Etcd:** Learning that the Kubernetes "brain" is **etcd**—a distributed key-value store—introduces users to the challenges of **consensus** and high availability in distributed systems.