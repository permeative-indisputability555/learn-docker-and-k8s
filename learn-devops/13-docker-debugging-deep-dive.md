# Docker Debugging Techniques Deep Dive

Debugging Docker containers requires a systematic approach that moves from non-invasive observation to direct interaction. Here is a step-by-step breakdown of essential debugging techniques.

### 1. Log Analysis (The First Line of Defense)
Checking logs is the primary step to understand why a container is failing or misbehaving.
*   **Exact Command:** `docker logs <container_id>` (Use `--tail 10` for recent entries or `-f` to stream in real-time).
*   **When to Use:** When a container crashes immediately on startup or an application returns internal errors.
*   **What Output Tells You:** It shows everything the application sent to `stdout` and `stderr`, such as stack traces, missing dependency errors, or failed database connections.
*   **Beginner Scenario:** Your Node.js app won't start; the logs reveal a "Module Not Found" error because a library was missing from the `package.json`.

### 2. Interpreting Exit Codes
When a container stops, it leaves a numeric code that signals the cause of the shutdown.
*   **Exact Command:** `docker inspect <container_id> --format='{{.State.ExitCode}}'` or `docker ps -a`.
*   **When to Use:** When a container has disappeared or stopped unexpectedly.
*   **What Output Tells You:**
    *   **0:** Success; the app finished its task and closed normally.
    *   **1:** General application error (e.g., a code exception).
    *   **127:** "Command not found"; your `CMD` or `ENTRYPOINT` points to a non-existent file.
    *   **137:** **SIGKILL**; the container was forcefully stopped, often due to an Out of Memory (OOM) error.
    *   **143:** **SIGTERM**; a graceful shutdown, usually after a `docker stop` command.
*   **Beginner Scenario:** A database container vanishes. The exit code is **137**, and running `docker inspect` shows `OOMKilled: true`, meaning the host ran out of RAM and killed the container.

### 3. Non-Invasive Inspection
Before entering a container, gather configuration data without modifying the running environment.
*   **Exact Command:** `docker inspect <container_id>`.
*   **When to Use:** To verify environment variables, network settings, or volume mounts.
*   **What Output Tells You:** A detailed JSON object containing the container's IP address, restart counts, and the exact command being executed.
*   **Beginner Scenario:** You can't connect to your database. `inspect` reveals that the environment variable `DB_PASSWORD` was misspelled as `DB_PASSWARD`.

### 4. Interactive Shell Access (`docker exec`)
If logs and inspection aren't enough, you may need to enter the container to test commands directly.
*   **Exact Command:** `docker exec -it <container_id> /bin/bash` (use `/bin/sh` if bash is unavailable).
*   **When to Use:** For real-time debugging, such as checking file permissions or manually running a script inside the container environment.
*   **What Output Tells You:** It provides an interactive terminal inside the container.
*   **Beginner Scenario:** Your app can't write to a `/data` folder; you `exec` in and run `ls -l` to find that the folder is owned by `root` instead of the application user.

### 5. Advanced Debugging for Slim Images (`docker debug`)
Traditional `exec` commands fail if an image is "slim" or "distroless" (missing a shell).
*   **Exact Command:** `docker debug <container_id|image_name>`.
*   **When to Use:** When `docker exec` fails with a "file not found" error because the image has no shell.
*   **What Output Tells You:** It opens a debug shell that brings its own "toolbox" (including `vim`, `htop`, and `curl`) without modifying the target image.
*   **Beginner Scenario:** You are using a production-hardened Alpine image with no tools. You use `docker debug` to run `curl` and test if the container can reach an external API.

### 6. Resource Monitoring
Performance issues are often caused by resource starvation.
*   **Exact Command:** `docker stats`.
*   **When to Use:** When the application is slow, unresponsive, or the host machine is lagging.
*   **What Output Tells You:** A live stream of CPU usage, memory usage, and network I/O for all running containers.
*   **Beginner Scenario:** Your web server is extremely slow. `stats` shows it is using 99.5% of its assigned memory, causing it to "thrash".

### 7. Health Checks and Event Tracking
Monitoring the high-level state of a container over time.
*   **Exact Commands:** 
    *   **Health:** `docker inspect` (look for `.State.Health`).
    *   **Events:** `docker events --since 1h`.
*   **When to Use:** To track periodic failures or see if an app is "ready" to receive traffic.
*   **What Output Tells You:** `events` shows a timeline of restarts and health check failures. Health checks tell you if the application *inside* the container is actually working, even if the container is "running".
*   **Beginner Scenario:** Your app keeps restarting. `docker events` shows a "health_status: unhealthy" event followed immediately by a "die" event, proving that a failing health check is triggering a restart loop.