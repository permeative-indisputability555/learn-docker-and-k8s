# Essential Linux Commands for Docker Users

To effectively use Docker, you must master the underlying Linux fundamentals that containers rely on for isolation, execution, and communication. Below are the essential commands and concepts organized by category, with real-world Docker use cases.

### 1. File System Navigation
Understanding the Linux directory structure is vital because every container has its own isolated root filesystem.
*   **Key Commands:** `ls` (list files), `cd` (change directory), `pwd` (print working directory), and `cat` (view file content).
*   **Concepts:** **Absolute vs. Relative paths**. You should always use absolute paths for reliability in your Dockerfile `WORKDIR`.
*   **Docker Example:** Use `docker exec -it [container] ls /app` to verify that your `COPY` instruction correctly placed your application code into the expected directory.

### 2. Process Management
Containers are essentially isolated processes; managing them requires understanding how Linux handles execution.
*   **Key Commands:** `ps` (view running processes), `top` (monitor resource usage), and `kill` (terminate a process).
*   **Concepts:** **PID 1 and Signal Handling**. The main process in a container runs as PID 1 and is responsible for handling Unix signals like `SIGTERM`.
*   **Docker Example:** `exec` into a container and run `top` to identify why a container is hitting its memory limit or consuming 100% CPU.

### 3. Networking
Docker abstracts complex Linux networking into drivers, but troubleshooting requires standard Linux tools.
*   **Key Commands:** 
    *   `ip address show` (or `ip a`): View virtual interfaces and assigned IPs.
    *   `ping`: Test basic connectivity between containers.
    *   `curl`: Verify if a web service is responding internally.
    *   `netstat` or `ss`: Check which ports a process is listening on.
*   **Concepts:** **DNS Resolution and NAT**. Containers on a user-defined bridge use an embedded DNS server for service discovery.
*   **Docker Example:** Run `docker exec [container] curl http://database:3306` to see if your application can reach the database service by its container name.

### 4. Permissions and Users
Security hardening in Docker often involves managing Linux users and file ownership to avoid running as `root`.
*   **Key Commands:** `chown` (change owner), `chmod` (change permissions), `useradd`, and `groupadd`.
*   **Concepts:** **Least Privilege**. Running a service as a non-privileged user limits the potential damage if the container is compromised.
*   **Docker Example:** In your Dockerfile, use `useradd` to create a service user and the `USER` instruction to switch away from `root` before starting your app.

### 5. Environment Variables
Environment variables are the primary way to inject configuration into containers without rebuilding the image.
*   **Key Commands:** `export` (set a variable) and `env` (list all variables).
*   **Concepts:** **$PATH variable**. Adding your application's binary directory to the `$PATH` ensures that your `CMD` or `ENTRYPOINT` can find the executable without using full paths.
*   **Docker Example:** Use `docker run -e DB_PASSWORD=secret` to pass sensitive credentials into a containerized application.

### 6. Shell Scripting Basics
Dockerfile instructions like `RUN` execute shell commands; knowing how to chain them is essential for performance.
*   **Key Concepts:**
    *   **Chaining (`&&`):** Executes the second command only if the first succeeds. This is critical for keeping image layers small and preventing "stale" package lists.
    *   **Pipes (`|`):** Directs the output of one command into another.
    *   **Exec form:** Using `exec` in entrypoint scripts ensures your application replaces the shell as PID 1, allowing it to receive shutdown signals.
*   **Docker Example:** Use `RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*` to update, install, and clean up in a single layer to minimize image size.