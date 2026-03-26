# Lesson 03: Basic Commands

*Sarah speaking:* This is the lesson you'll refer back to most. These are the commands you'll type dozens of times a week. Let's go through the entire container lifecycle — from "spin it up" to "tear it down" — and actually understand what each command does.

---

## The Container Lifecycle

A container moves through these states:

```
[Image] --run--> [Created] --start--> [Running] --stop--> [Stopped] --rm--> [Gone]
                                          │
                                     exec/logs
                                     (interact)
```

We have a command for each transition. Let's go through them.

---

## `docker run` — Create and Start a Container

`docker run` is the workhorse. It creates a new container from an image and starts it.

### Simplest possible form

```bash
docker run nginx
```

This starts nginx in the **foreground** — the terminal is attached, you see the logs. Press `Ctrl+C` to stop it. The container is stopped but not removed.

### Run in the background: `-d` (detached)

```bash
docker run -d nginx
```

The container starts and runs in the background. Docker prints the container ID and returns you to your prompt immediately.

```
3f2a1c8d9e4b7f6a0c2e5d8b1a9f3c6e7d4b2a0f8e1c9d7b6a5f4e3c2d1b0a
```

### Give it a name: `--name`

```bash
docker run -d --name my-nginx nginx
```

Without `--name`, Docker invents a random name (like `hungry_tesla` or `suspicious_mclean`). Always name your containers — it makes everything else easier.

### Map a port: `-p`

```bash
docker run -d --name my-nginx -p 8080:80 nginx
```

Format is `-p HOST_PORT:CONTAINER_PORT`.

The container's nginx listens on port 80 inside the container. `-p 8080:80` tells Docker to forward traffic from your host's port 8080 to the container's port 80. This is a **NAT rule** at the kernel level — Docker manages iptables entries to make it work.

Now you can open `http://localhost:8080` in your browser and see the nginx welcome page.

### Interactive mode: `-it`

```bash
docker run -it alpine sh
```

`-i` keeps stdin open. `-t` allocates a pseudo-TTY. Together they give you an interactive shell *inside* the container. You're now running `sh` inside an Alpine Linux environment.

Type `exit` (or press `Ctrl+D`) to leave. The container stops when the shell exits.

### Auto-remove when done: `--rm`

```bash
docker run --rm alpine echo "hello from alpine"
```

When the container finishes, Docker automatically removes it. Perfect for one-off tasks where you don't want to clean up manually.

Output:
```
hello from alpine
```

### Environment variables: `-e`

```bash
docker run -d --name my-db -e POSTGRES_PASSWORD=secret postgres
```

Pass environment variables into a container. Most official images use environment variables for configuration.

---

## `docker ps` — List Running Containers

```bash
docker ps
```

Output:
```
CONTAINER ID   IMAGE     COMMAND                  CREATED         STATUS         PORTS                  NAMES
3f2a1c8d9e4b   nginx     "/docker-entrypoint.…"   2 minutes ago   Up 2 minutes   0.0.0.0:8080->80/tcp   my-nginx
```

Key columns:
- **CONTAINER ID** — truncated version of the full ID
- **STATUS** — `Up 2 minutes`, `Exited (0) 3 seconds ago`, etc.
- **PORTS** — the port mapping (`0.0.0.0:8080->80/tcp` means "all host interfaces, port 8080, forwarded to container port 80")
- **NAMES** — the human-readable name

### Show all containers (including stopped ones)

```bash
docker ps -a
```

This shows running AND stopped containers. Stopped containers still exist until you `docker rm` them. New learners often end up with dozens of stopped containers eating disk space — `docker ps -a` reveals them.

### Filter by name or label

```bash
docker ps --filter "name=my-nginx"
docker ps --filter "label=app=learn-docker-k8s"
```

Useful for finding specific containers in a busy environment.

---

## `docker stop` — Graceful Shutdown

```bash
docker stop my-nginx
```

Sends `SIGTERM` to the main process in the container, giving it 10 seconds to shut down gracefully. If it doesn't stop in time, Docker sends `SIGKILL`. The container moves to the `Exited` state.

This is the polite way to stop a container. Most apps handle `SIGTERM` to flush buffers, close connections, and clean up.

### Stop multiple containers

```bash
docker stop container1 container2 container3
```

Or stop all running containers (carefully):
```bash
docker stop $(docker ps -q)
```

---

## `docker rm` — Remove a Container

```bash
docker rm my-nginx
```

Removes the stopped container and its writable layer. The image is unaffected.

You can only remove stopped containers. To force-remove a running container:
```bash
docker rm -f my-nginx
```

### Remove all stopped containers

```bash
docker rm $(docker ps -aq)
```

`-q` outputs only IDs. Combined with `-a`, this gives you all container IDs, which you pipe to `docker rm`.

---

## `docker logs` — View Container Output

```bash
docker logs my-nginx
```

Shows all the output the container has written to stdout and stderr since it started.

### Follow live logs: `-f`

```bash
docker logs -f my-nginx
```

Like `tail -f` — stays open and streams new log lines as they appear. Press `Ctrl+C` to stop following.

### Show last N lines: `--tail`

```bash
docker logs --tail 50 my-nginx
```

Useful when a container has been running for hours and you only want recent output.

### Add timestamps: `-t`

```bash
docker logs -t my-nginx
```

Output:
```
2024-03-15T09:32:14.531891042Z /docker-entrypoint.sh: Configuring nginx
2024-03-15T09:32:14.542331042Z /docker-entrypoint.sh: Launching nginx
2024-03-15T09:32:14.568902042Z nginx: the configuration file test is successful
```

---

## `docker exec` — Run a Command Inside a Running Container

```bash
docker exec my-nginx ls /etc/nginx
```

Output:
```
conf.d  fastcgi_params  mime.types  modules  nginx.conf  scgi_params  uwsgi_params
```

### Open an interactive shell

```bash
docker exec -it my-nginx bash
```

You're now inside the running container. Useful for:
- Checking the filesystem
- Reading config files
- Running debugging tools
- Checking environment variables with `env`

> Important: Changes you make inside `exec` shells affect the running container's writable layer but are lost when the container is removed. Never use `exec` as a deployment mechanism.

### Check environment variables inside a container

```bash
docker exec my-nginx env
```

---

## `docker start` — Start a Stopped Container

```bash
docker start my-nginx
```

Starts a stopped container (not creating a new one). Useful if you stopped a container and want to resume it without recreating it.

---

## Putting It All Together

Here's a full lifecycle example:

```bash
# 1. Pull the image
docker pull nginx

# 2. Run a container (detached, named, port mapped, labelled)
docker run -d \
  --name learn-ch01-nginx \
  -p 8080:80 \
  --label app=learn-docker-k8s \
  --label chapter=ch01 \
  nginx

# 3. Verify it's running
docker ps --filter "name=learn-ch01-nginx"

# 4. Check it's serving content
curl http://localhost:8080

# 5. Watch the access logs
docker logs -f learn-ch01-nginx
# (Ctrl+C to stop watching)

# 6. Open a shell inside the container
docker exec -it learn-ch01-nginx bash

# 7. Stop the container
docker stop learn-ch01-nginx

# 8. Remove the container
docker rm learn-ch01-nginx
```

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `docker run -d --name X IMAGE` | Start container in background with a name |
| `docker run -p 8080:80 IMAGE` | Map host port 8080 to container port 80 |
| `docker run -it IMAGE sh` | Start container with interactive shell |
| `docker run --rm IMAGE CMD` | Run one-off command, auto-remove after |
| `docker ps` | List running containers |
| `docker ps -a` | List all containers (including stopped) |
| `docker stop X` | Gracefully stop container X |
| `docker rm X` | Remove stopped container X |
| `docker rm -f X` | Force-remove running container X |
| `docker logs X` | Show stdout/stderr from container X |
| `docker logs -f X` | Follow live logs |
| `docker exec -it X bash` | Open interactive shell in running container X |
| `docker exec X COMMAND` | Run a one-off command in container X |

---

## What's Next

You've got the theory and the toolset. Time to apply it.

Head over to the challenges — your mission is to use these commands to solve real problems. No hand-holding in challenge mode; you've got everything you need.

**First challenge:** [Run Nginx](../challenges/01-run-nginx.md)
