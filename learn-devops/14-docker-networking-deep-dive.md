# Docker Networking Deep Dive

Docker networking is a multi-layered system that allows containers to communicate with each other, the host, and external networks. By default, Docker provides several drivers that handle these connections differently based on isolation and performance needs.

### 1. Default Bridge vs. User-Defined Bridge
When Docker starts, it creates a virtual bridge interface, typically called **docker0**.
*   **Default Bridge:** If no network is specified, containers attach here. It provides basic isolation and uses NAT to allow containers to reach the internet. However, it has **limited DNS features**; containers cannot resolve each other by name, only by internal IP.
*   **User-Defined Bridge:** These are custom networks created by the user. They provide better isolation and **automatic DNS resolution**, allowing containers to communicate using their names instead of shifting IP addresses.

**Hands-on Exercise:**
1.  Run a container on the default bridge: `docker run -d --name web1 busybox sleep 3600`.
2.  Try to ping it from another default container: `docker run --rm busybox ping web1` (This will **fail**).
3.  Create a user-defined bridge: `docker network create my-net`.
4.  Run two containers on it: `docker run -d --name web2 --network my-net busybox sleep 3600`.
5.  Ping by name: `docker run --rm --network my-net busybox ping web2` (This will **succeed**).

### 2. DNS Resolution Mechanics
Docker provides an embedded DNS server at the address **127.0.0.11**.
*   **User-Defined/Overlay Networks:** The embedded DNS server resolves container names, service names, and aliases.
*   **Default Bridge:** Containers typically inherit a copy of the host's `/etc/resolv.conf`. 

**Troubleshooting Command:** Inside a container, run `nslookup <container_name>` or `cat /etc/resolv.conf` to verify which DNS server is being used.

### 3. Port Mapping Internals
Port mapping (`-p host:container`) makes a container service available outside the host.
*   **Mechanics:** Docker creates **DNAT (Destination Network Address Translation)** rules in the host's **iptables**.
*   **Packet Flow:** Traffic hits the host port $\rightarrow$ Docker DNATs it to the container's internal IP and port $\rightarrow$ the bridge handles delivery.
*   **Misconception:** The `EXPOSE` instruction in a Dockerfile is only metadata; it does **not** actually publish the port.

**Troubleshooting Command:** Use `sudo iptables -t nat -L -n` to see the DNAT rules Docker has created for your port mappings.

### 4. Host Networking
In this mode, the container shares the **host's network stack** directly, removing network isolation.
*   **Benefits:** No NAT is required, resulting in the **lowest latency**. 
*   **Downsides:** There is no isolation; if a container binds to port 80, it takes over port 80 on the actual host.

**Hands-on Exercise:**
1.  Run Nginx on the host network: `docker run -d --network host nginx`.
2.  Access it directly via your host's IP address on port 80 without using the `-p` flag.

### 5. Macvlan
Macvlan allows you to assign a **MAC address** to a container, making it appear as a physical device on your network.
*   **Bridge Mode:** Containers connect directly to the physical network but require the host's network interface to be in **promiscuous mode** to handle multiple MAC addresses on one port.
*   **802.1Q Mode:** Allows Docker to create sub-interfaces (VLANs) for containers, sending traffic over a trunk link.

**Hands-on Exercise:**
1.  Enable promiscuous mode: `sudo ip link set <interface> promisc on`.
2.  Create the network: `docker network create -d macvlan --subnet=10.0.0.0/24 --gateway=10.0.0.1 -o parent=<interface> my-macvlan`.
3.  Run a container with a static IP: `docker run -d --network my-macvlan --ip 10.0.0.50 busybox`.

### 6. Ipvlan (L2 and L3)
Ipvlan is similar to Macvlan but handles MAC addresses differently to avoid promiscuous mode issues.
*   **L2 Mode:** Containers share the **host's MAC address** but have unique IP addresses.
*   **L3 Mode:** The host acts as a **router**. It does not use ARP or broadcast traffic; communication is handled via layer 3 routing. It requires static routes on your physical router to reach the container subnets.

**Hands-on Exercise (L3):**
1.  Create an L3 network: `docker network create -d ipvlan --subnet=192.168.94.0/24 -o parent=<interface> -o ipvlan_mode=l3 my-ipv3`.
2.  Run a container and observe it cannot reach the internet until you add a **static route** on your home router pointing `192.168.94.0/24` to your host's IP.

### 7. Overlay
Overlay networks enable communication between containers across **multiple Docker hosts**.
*   **Mechanics:** It uses **VXLAN encapsulation** to tunnel traffic between hosts, creating a distributed virtual network. This is the standard for **Docker Swarm**.

### Summary of Troubleshooting Commands
*   **`ip addr`**: Shows virtual interfaces like `docker0` and container-specific `veth` pairs.
*   **`ss -lnt`**: Shows which ports are currently listening on the host to find port conflicts.
*   **`docker network inspect <name>`**: Reveals container IPs, gateway, and subnet details for a specific network.
*   **`docker exec <container> ping <target>`**: Tests basic connectivity between points.