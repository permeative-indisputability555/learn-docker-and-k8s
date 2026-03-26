# Production Scenario Bank

This scenario bank is designed for a learning game based on real-world production challenges and daily operations tasks extracted from the sources.

### **Category 1: Networking and Connectivity**

**Scenario: The Port Tug-of-War**
*   **Error Message:** `"Port Already Allocated"` or `"bind: address already in use"`.
*   **Debugging Workflow:** 
    1.  Run `docker ps` to see if a container is already using the host port.
    2.  Use `sudo lsof -i :<port_number>` to check if a non-containerized process on the host is hogging the port.
    3.  Check the `docker-compose.yml` or `docker run` command to verify which number is on the left of the colon (host) versus the right (container).
*   **Aha Moment:** "I can have ten containers using port 80 internally, but only **one** of them can claim port 80 on my physical host machine!".

**Scenario: The Silent Internal Network**
*   **Error Message:** `"Name Not Resolved"` or `"Could not reach [service_name]"`.
*   **Debugging Workflow:**
    1.  Run `docker network ls` to see if the containers are on the same network.
    2.  Use `docker network inspect <network_name>` to verify both containers are attached to the same user-defined bridge.
    3.  Inside the container, run `nslookup <target_container_name>` to check Docker’s embedded DNS.
*   **Aha Moment:** "The default bridge network doesn't support DNS resolution by name; I **must** create a user-defined network for my services to talk to each other as 'web' and 'db'!".

**Scenario: The Loopback Lockdown**
*   **Error Message:** `"Connection Refused"` when trying to access the app via the host IP, even though the container is running.
*   **Debugging Workflow:**
    1.  Check the application configuration inside the container.
    2.  Verify if the app is binding to `127.0.0.1` (localhost).
    3.  Use `netstat -tlnp` inside the container to see the listening interface.
*   **Aha Moment:** "If my app binds to `127.0.0.1` inside the container, it only talks to itself! To be reached via the host, it must listen on `0.0.0.0` (all interfaces)!".

---

### **Category 2: Storage and Persistence**

**Scenario: The Amnesiac Database**
*   **Error Message:** No explicit error; the application starts normally, but all previously saved user data or configuration files are missing after a restart.
*   **Debugging Workflow:**
    1.  Run `docker inspect <container_id>` and look for the `"Mounts"` section.
    2.  Check if files are being written to the "writable layer" instead of a volume.
*   **Aha Moment:** "Containers are ephemeral! If I don't use a **Named Volume** or **Bind Mount**, my data dies the moment the container is removed!".

**Scenario: The Permission Wall**
*   **Error Message:** `"Permission Denied"` when the application tries to write to a mounted volume.
*   **Debugging Workflow:**
    1.  Check the UID/GID of the user running the app inside the container (`whoami` and `id`).
    2.  Compare it to the owner of the folder on the host machine.
    3.  Attempt to use the `:Z` flag (for SELinux systems) or match the UID manually.
*   **Aha Moment:** "Linux permissions don't care that it's a container; if 'appuser' inside doesn't have the same ID as the folder owner outside, the door is locked!".

---

### **Category 3: Resource Management and Stability**

**Scenario: The "OOM" Reaper**
*   **Error Message:** Container status shows `"Exited (137)"`. `docker inspect` reveals `"OOMKilled": true`.
*   **Debugging Workflow:**
    1.  Run `docker stats` to watch live memory consumption.
    2.  Check `memory.events` in cgroups v2 to see if the container is being throttled or nearing its `memory.max`.
*   **Aha Moment:** "My container was a 'noisy neighbor' that ate all the host's RAM until the kernel killed it! I need to set **hard memory limits** to keep it in its cage!".

**Scenario: The Infinite Restart Loop**
*   **Error Message:** `docker ps` shows the container status flickering between `"Up 2 seconds"` and `"Restarting"`.
*   **Debugging Workflow:**
    1.  Run `docker logs <container_id>` immediately to see the last few lines of output.
    2.  Check the `ENTRYPOINT` or `CMD` script for syntax errors.
    3.  Verify if a required dependency (like a database) is missing.
*   **Aha Moment:** "The container isn't 'broken,' it's just crashing on startup because it can't find its config file, and my `restart: always` policy is just hiding the crash!".

---

### **Category 4: Image and Build Optimization**

**Scenario: The Stale Update Mystery**
*   **Error Message:** Application is missing new features or security patches even after a `docker build`.
*   **Debugging Workflow:**
    1.  Check the `FROM` line in the Dockerfile for the `latest` tag.
    2.  Look for `RUN apt-get update` and `RUN apt-get install` on separate lines.
*   **Aha Moment:** "Docker cached my old 'update' layer! I need to chain these commands with `&&` to force a fresh update every time I install a new package!".

**Scenario: The "Command Not Found" (Exit 127)**
*   **Error Message:** `"Exited (127)"` or `"docker: Error response from daemon: oci runtime error: [binary] not found"`.
*   **Debugging Workflow:**
    1.  Check for typos in the `CMD` or `ENTRYPOINT`.
    2.  Verify if the binary was actually copied into the final stage of a multi-stage build.
    3.  Ensure the `WORKDIR` is set correctly; otherwise, the container might be looking for the file in the root directory.
*   **Aha Moment:** "I used a multi-stage build to save space but forgot to `COPY` the actual executable into the final runner image!".

---

### **Category 5: Security and Operations**

**Scenario: The Exposed Secret**
*   **Error Message:** No error, but a security audit reveals database passwords in the image history.
*   **Debugging Workflow:**
    1.  Run `docker history <image_name>`.
    2.  Search for `ENV` or `COPY` commands involving `.env` files.
*   **Aha Moment:** "Images are immutable! Deleting a secret in a later layer doesn't remove it from the history; I must inject secrets at **runtime** using environment variables or a secret manager!".