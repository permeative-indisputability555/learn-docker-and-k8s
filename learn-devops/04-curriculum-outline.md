# Detailed Curriculum Outline (7 Chapters)

Here is a 7-chapter curriculum for an interactive learning game designed to take a beginner from a fresh Docker installation to managing production-grade Kubernetes clusters.

### Chapter 1: The "It Works on My Machine" Curse
*   **Story:** You just joined a startup. A senior dev sends you a "broken" Node.js app that runs for them but fails on your machine because of a specific library version mismatch. Your mission is to wrap this app in a container to ensure **environmental consistency**.
*   **Teaching Topics:** What are containers? (Isolation vs. Virtualization), Images vs. Containers, and basic Docker CLI.
*   **Challenge:** Run an official Nginx container, but map it to a specific host port so your browser can see it.
*   **Verification:** The game checks if `http://localhost:8080` returns the "Welcome to nginx" page.
*   **Fundamentals:** **Linux:** Namespaces (isolation). **Networking:** Port mapping (NAT).

### Chapter 2: The Slim-Down Challenge (Image Optimization)
*   **Story:** The production image is 2GB, causing slow deployments and high storage costs. Your boss demands you "cut the bloat" before the next release.
*   **Teaching Topics:** Dockerfile instructions (`FROM`, `RUN`, `COPY`), **multi-stage builds**, and choosing minimal base images like **Alpine**.
*   **Challenge:** Refactor a bloated Dockerfile using multi-stage builds and a `.dockerignore` file to reduce the image size by at least 70%.
*   **Verification:** The game runs `docker images` and validates the final image size is below a specific threshold (e.g., < 100MB).
*   **Fundamentals:** **Linux:** Layered filesystems (UnionFS). **Networking:** Image registry pulls.

### Chapter 3: The Persistent Data Crisis
*   **Story:** You deployed a database container, but after a routine restart, all customer records vanished! You must implement a solution to make the data **survive container restarts**.
*   **Teaching Topics:** Ephemeral vs. Persistent state, **Docker Volumes**, and Bind Mounts.
*   **Challenge:** Mount a named volume to a MySQL container and prove that data created in the SQL shell persists even after the container is deleted and recreated.
*   **Verification:** Game script creates a "test_db" inside the container, removes the container, and checks if "test_db" exists in a new container using that volume.
*   **Fundamentals:** **Linux:** Filesystem mounts (`/etc/fstab` logic). **Networking:** Internal container sockets.

### Chapter 4: Orchestrating the Symphony (Docker Compose)
*   **Story:** Running your frontend, backend, and database with separate `docker run` commands is becoming a nightmare. You need a way to launch the entire **it infrastructure** with a single command.
*   **Teaching Topics:** YAML syntax, `docker-compose.yml`, and container dependencies (`depends_on`).
*   **Challenge:** Create a Compose file for a WordPress site and a MySQL database. Ensure they communicate using **user-defined networks** so they can find each other by name.
*   **Verification:** Successfully running `docker-compose up -d` and accessing the WordPress setup page.
*   **Fundamentals:** **Linux:** YAML serialization. **Networking:** Service discovery via internal DNS resolution.

### Chapter 5: Leaving the Nest (Intro to Kubernetes)
*   **Story:** Your single Docker host crashed at 3 AM. To achieve **High Availability**, you must move the app to a Kubernetes cluster that self-heals when things go wrong.
*   **Teaching Topics:** The Control Plane (the "brain"), Nodes, **Pods** (smallest unit), and **Deployments**.
*   **Challenge:** Use `kubectl` to create an Nginx deployment with 3 replicas. Manually delete one Pod and watch Kubernetes automatically "reconcile" the state by starting a new one.
*   **Verification:** `kubectl get pods` shows exactly 3 running pods even after a manual deletion.
*   **Fundamentals:** **Linux:** Process management. **Networking:** Pod IP address allocation.

### Chapter 6: The "Who Can Talk to Who?" Network
*   **Story:** Your frontend Pod is running, but it can't find the backend Service. You need to configure **stable endpoints** because Pod IPs change every time they restart.
*   **Teaching Topics:** **Services** (ClusterIP vs. NodePort), **Ingress** controllers, and Labels/Selectors.
*   **Challenge:** Create a ClusterIP Service to link your frontend to your backend using **Labels**. Then, configure an **Ingress** rule to map `myapp.com` to your frontend.
*   **Verification:** A `curl` command to the Ingress address returns the expected response from the backend.
*   **Fundamentals:** **Linux:** Iptables/Nftables (routing logic). **Networking:** DNS search domains and Layer 7 HTTP routing.

### Chapter 7: Production-Ready Ops
*   **Story:** It's launch day! You need to handle **Secrets** securely, perform a **Rolling Update** for version 2.0 without downtime, and scale the app based on traffic.
*   **Teaching Topics:** **Secrets** and ConfigMaps, Rolling Update strategies, and Horizontal Pod Autoscaling (HPA).
*   **Challenge:** Update your app to a new image version. While the update is running, prove there is zero downtime. Then, move a database password from a plain-text file into a **Kubernetes Secret**.
*   **Verification:** The game runs a continuous ping/request loop during the update to ensure 100% success rate.
*   **Fundamentals:** **Linux:** Environment variables and Base64 encoding. **Networking:** Load balancing across replica sets.