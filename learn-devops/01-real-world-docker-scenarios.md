# Real-World Docker Scenarios (Easy → Hard)

Beginners typically encounter Docker scenarios in a progression that moves from simply running pre-made software to building custom applications and finally orchestrating complex environments. Here are the most common real-world scenarios listed from easiest to hardest:

### 1. Running a Simple Web Server (Easiest)
This is the entry point where beginners use "Docker Official Images" to host basic services like Nginx or Apache.
*   **What goes wrong:** The most common failure is a **port mismatch**. A beginner might run the container but find the website unreachable because they forgot that containers are isolated and their internal ports must be manually mapped to the host machine.
*   **Commands to learn:**
    *   `docker run -d -p 8080:80 nginx`: Runs a container in detached mode and maps host port 8080 to container port 80.
    *   `docker ps`: Lists running containers to verify status and port mappings.
    *   `docker stop [container_name]`: Safely shuts down the service.

### 2. Containerizing Your Own Application (Easy-Intermediate)
Beginners must learn to write a **Dockerfile** to package their specific code and dependencies into an immutable image.
*   **What goes wrong:** 
    *   **Stale builds:** If `apt-get update` and `apt-get install` are on separate lines, Docker may use a cached version of the update command, leading to outdated or failing package installations.
    *   **Bloated images:** Including unnecessary tools like text editors or compilers in production images increases the attack surface and download times.
*   **Commands to learn:**
    *   `docker build -t my-app:v1 .`: Creates an image from a Dockerfile in the current directory.
    *   `docker images`: Views locally stored images and their sizes.
    *   `docker pull/push`: Downloads or uploads images to a registry like Docker Hub.

### 3. Persisting Data with Volumes (Intermediate)
Once a beginner runs a database (like MySQL or MongoDB), they quickly realize that **containers are ephemeral**; if the container is deleted, all stored data is lost.
*   **What goes wrong:** Beginners often forget to mount a volume, resulting in a "blank slate" every time a database container restarts or updates. They may also struggle with host-container permission mismatches when using bind mounts.
*   **Commands to learn:**
    *   `docker run -v my-db-data:/var/lib/mysql`: Uses a named volume to ensure data persists independently of the container lifecycle.
    *   `docker volume ls/inspect`: Manages and views the details of persistent storage objects.

### 4. Orchestrating Multi-Container Apps with Docker Compose (Intermediate-Hard)
Real-world apps usually require at least two containers: a frontend/application and a database.
*   **What goes wrong:**
    *   **Startup Race Conditions:** The application might crash because it tries to connect to the database before the database is fully initialized. While `depends_on` tells Docker which container to start first, it doesn't guarantee the service inside is "ready".
    *   **YAML Syntax Errors:** Docker Compose relies heavily on precise indentation; a single misplaced space can prevent the entire environment from launching.
*   **Commands to learn:**
    *   `docker-compose up -d`: Orchestrates the entire stack defined in a `docker-compose.yml` file.
    *   `docker-compose logs -f`: Streams logs from all services to debug connection issues between containers.
    *   `docker-compose down`: Stops and removes all containers and networks defined in the file.

### 5. Custom Networking and Troubleshooting (Hardest)
Advanced beginners eventually need containers to communicate in specific ways, such as isolating a database from the public internet or connecting containers directly to a physical home network.
*   **What goes wrong:**
    *   **DNS Failures:** On the "default bridge" network, containers cannot find each other by name—they must use IP addresses, which change constantly. Beginners must learn to use **User-Defined Bridges** to enable automatic DNS resolution.
    *   **Promiscuous Mode Issues:** When using MacVLAN to give containers their own MAC addresses, the physical network switch or virtual machine host may block the traffic unless "promiscuous mode" is manually enabled.
*   **Commands to learn:**
    *   `docker network create [name]`: Creates a custom isolated network for specific containers.
    *   `docker inspect [network_name]`: Allows you to see exactly which containers are connected to a network and their internal IP addresses.
    *   `docker exec -it [container] ping [other_container]`: A vital troubleshooting step to verify connectivity between services.