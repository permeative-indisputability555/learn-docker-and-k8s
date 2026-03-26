# Common Beginner Mistakes → Challenge Scenarios

Here are the most common mistakes and misconceptions beginners encounter when learning Docker and Kubernetes, structured for use in a learning game:

### 1. The Ephemeral Data Trap
*   **What they do wrong:** Storing application data, such as database records or uploaded files, directly in the container’s writable layer without using volumes.
*   **The error they see:** All data disappears when the container is stopped, deleted, or updated to a new image version.
*   **The correct approach:** Use **Volumes** or **PersistentVolumes** to store data independently of the container lifecycle.

### 2. The "Stale Update" Dockerfile
*   **What they do wrong:** Writing `RUN apt-get update` and `RUN apt-get install` as separate instructions in a Dockerfile.
*   **The error they see:** Docker reuses the cached "update" layer from a previous build, resulting in the "install" step trying to download packages that no longer exist or are outdated.
*   **The correct approach:** Use **chaining** with `&&` to combine update and install in a single `RUN` statement, ensuring the cache is busted if the package list changes.

### 3. The Default Bridge DNS Blindspot
*   **What they do wrong:** Running multiple containers on the default "bridge" network and trying to make them communicate using their container names.
*   **The error they see:** "Could not resolve host" or "Ping: unknown host" because the default bridge does not support automatic DNS resolution.
*   **The correct approach:** Create and use a **User-Defined Bridge Network**, which includes an embedded DNS server for service discovery by name.

### 4. The External Port Mismatch
*   **What they do wrong:** Forgetting to map ports using the `-p` flag, or confusing the "host port" with the "container port".
*   **The error they see:** "Site cannot be reached" or "Connection refused" when trying to access the application via a browser at `localhost`.
*   **The correct approach:** Explicitly map the ports using `-p [host_port]:[container_port]`, ensuring the container port matches what the application is actually listening on.

### 5. The "Latest" Tag Gamble
*   **What they do wrong:** Using the `latest` image tag for base images or production deployments.
*   **The error they see:** A deployment that worked yesterday suddenly fails because the image provider pushed a breaking change to the `latest` tag.
*   **The correct approach:** **Pin base image versions** to specific tags or unique digests to ensure builds are immutable and reproducible.

### 6. The Kubernetes Label Mismatch
*   **What they do wrong:** Using different labels in the Pod metadata than those defined in the Service’s `selector`.
*   **The error they see:** The Service shows "0 endpoints" or requests time out, even though the Pods appear to be running.
*   **The correct approach:** Ensure the Service's `selector` exactly matches the Pod’s `labels` defined in the Deployment.

### 7. The Resource Hog (OOMKilled)
*   **What they do wrong:** Deploying containers without defining CPU or memory requests and limits.
*   **The error they see:** Pods are intermittently status **OOMKilled** or evicted because they exceeded the node’s available memory, or one "greedy" pod starved others of resources.
*   **The correct approach:** Define **resource requests and limits** in the Pod manifest to allow the Kubernetes scheduler to place workloads effectively.

### 8. The "Naked Pod" Deployment
*   **What they do wrong:** Creating individual Pods directly using `kubectl run` or YAML instead of using a Deployment.
*   **The error they see:** If the Pod crashes or the node it resides on fails, the Pod is not recreated, leading to application downtime.
*   **The correct approach:** Use a **Deployment** to manage Pods; it acts as a blueprint that ensures the "Desired State" (e.g., 3 replicas) is always maintained.

### 9. Treating Databases like Stateless Apps
*   **What they do wrong:** Attempting to scale a database like MySQL or MongoDB using a standard Deployment.
*   **The error they see:** Data corruption or "split-brain" issues because multiple database instances are trying to write to the same storage without a master/slave identity.
*   **The correct approach:** Use a **StatefulSet**, which provides stable network identities and unique, persistent storage for each pod replica.

### 10. The Docker Context Confusion
*   **What they do wrong:** Running `docker build` from a directory that contains massive unnecessary files (like `node_modules` or large datasets).
*   **The error they see:** The build is extremely slow and displays "Sending build context to Docker daemon" for several minutes for even a small code change.
*   **The correct approach:** Use a **.dockerignore** file to exclude heavy, irrelevant files from being sent to the builder.