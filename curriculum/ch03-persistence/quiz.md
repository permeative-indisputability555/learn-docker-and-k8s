# Chapter 03 Quiz: The Vanishing Beans

> Used by the skip-level protocol. Score >= 80% (4/5) to skip this chapter.

---

## Question 1

Dave runs the following commands in sequence:

```bash
docker run -d --name db -e MYSQL_ROOT_PASSWORD=secret mysql:8.0
# ... creates a table and inserts 100 rows ...
docker stop db
docker rm db
docker run -d --name db -e MYSQL_ROOT_PASSWORD=secret mysql:8.0
```

After the last command, how many rows are in the table?

**A)** 100 — `docker stop` preserved the data before it was removed
**B)** 100 — Docker automatically creates a volume for MySQL containers
**C)** 0 — the data was in the container's writable layer, which was deleted by `docker rm`
**D)** 0 — MySQL data is always stored in the image, not the container

<details>
<summary>Answer</summary>

**C** is correct.

The data was written to `/var/lib/mysql` inside the container's writable layer (the `upperdir` of the OverlayFS mount). `docker stop` only pauses the process — the writable layer still exists. `docker rm` deletes the container, including its writable layer. The new `docker run` creates a brand new container with an empty writable layer, so MySQL initializes a fresh data directory.

Option B is a common misconception: MySQL's official image *does* declare a volume in its Dockerfile (`VOLUME /var/lib/mysql`), which creates an anonymous volume. However, because the anonymous volume has a generated UUID as its name, the second `docker run` creates a *new* anonymous volume — it does not reuse the first one. Named volumes (`-v mydata:/var/lib/mysql`) are the correct solution.

</details>

---

## Question 2

You want to run a PostgreSQL container in production where the data must:
- Survive container deletion and recreation
- Be portable (the host machine might be replaced)
- Not be tied to a specific filesystem path on the host

Which mount type should you use?

**A)** Bind mount — map `/data/postgres` on the host to `/var/lib/postgresql/data` in the container
**B)** Named volume with a production volume driver (e.g., cloud block storage)
**C)** tmpfs mount — in-memory storage is the fastest option for databases
**D)** Anonymous volume — Docker manages the lifecycle automatically

<details>
<summary>Answer</summary>

**B** is correct.

Named volumes with an appropriate driver are the right choice for production databases. The `local` driver stores data on the host filesystem (fine for single-host setups), but production environments with multiple hosts or replaceable machines need a volume driver that stores data on shared/networked storage (AWS EBS, Azure Disk, NFS, Portworx, etc.).

Option A (bind mount) ties you to a specific path on a specific machine — when the machine is replaced, the data path is gone unless you manually copy it. Option C (tmpfs) is exactly backwards — tmpfs is the most ephemeral storage type, living only in RAM. Option D (anonymous volumes) cannot be reused across container deletions because the UUID name changes.

</details>

---

## Question 3

What is the difference between these two `docker run` commands?

```bash
# Command A
docker run -d -v /var/lib/mysql mysql:8.0

# Command B
docker run -d -v my-db-data:/var/lib/mysql mysql:8.0
```

**A)** Command A creates a bind mount from the host path `/var/lib/mysql`; Command B creates a named volume
**B)** Command A creates an anonymous volume; Command B creates a named volume called `my-db-data`
**C)** They are equivalent — Docker treats both the same way internally
**D)** Command A uses the container's writable layer; Command B creates a separate volume

<details>
<summary>Answer</summary>

**B** is correct.

When `-v` starts with a `/` or `./`, Docker treats it as a bind mount (a host filesystem path). When it starts with a name (no leading slash), Docker treats it as a volume name. A path with no corresponding host path prefix creates an **anonymous volume** — a Docker-managed volume with a generated UUID as its name, making it difficult to reference later.

Command A creates an anonymous volume (visible in `docker volume ls` as a long UUID). Command B creates a named volume called `my-db-data` (visible as `my-db-data` in `docker volume ls`). The key practical difference: Command B's volume can be reused by name in future `docker run` commands; Command A's cannot, because the UUID changes each time.

</details>

---

## Question 4

A containerized Node.js app fails to start with this error:

```
FATAL: Cannot write to log directory: EACCES: permission denied, open '/app/logs/app.log'
```

The Dockerfile contains `USER node` at the end. The app worked fine before that line was added. Which of the following is the most likely root cause?

**A)** The `node` user does not exist inside the container
**B)** The `/app/logs` directory (whether from the image or a mounted volume) is owned by root, and the `node` user does not have write permission
**C)** The `-v` flag does not work with non-root users
**D)** The `node:20-alpine` base image restricts filesystem writes in the `/app` directory

<details>
<summary>Answer</summary>

**B** is correct.

When `USER node` is added, all subsequent processes (including `CMD`) run as the `node` user (UID 1000 in the official `node` images). If `/app/logs` was created by `root` during the Docker build — or if a volume is mounted and Docker initializes the mount point as root-owned — the `node` user cannot write to it.

The fix is to create the directory and `chown` it to the correct user *before* the `USER` directive in the Dockerfile, while the build is still running as root:

```dockerfile
RUN mkdir -p /app/logs && chown -R node:node /app/logs
USER node
```

Options A and D are incorrect — the `node` user exists in the official image, and there is no blanket write restriction on `/app`. Option C is incorrect — volumes work fine with non-root users once the permissions are set correctly.

</details>

---

## Question 5

You need to back up the data in a named volume called `production-db` without stopping the running database container. Which command correctly creates a compressed backup archive on your host?

**A)**
```bash
docker volume export production-db > backup.tar.gz
```

**B)**
```bash
docker cp production-db:/var/lib/mysql ./backup
```

**C)**
```bash
docker run --rm \
  -v production-db:/source:ro \
  -v "$(pwd)":/backup \
  alpine tar czf /backup/backup.tar.gz -C /source .
```

**D)**
```bash
docker volume inspect production-db --format '{{.Mountpoint}}' | xargs tar czf backup.tar.gz
```

<details>
<summary>Answer</summary>

**C** is correct.

This is the standard "sidecar backup" pattern. A temporary Alpine container mounts the target volume read-only at `/source` and your host's current directory at `/backup`. It runs `tar` to compress everything from the volume into an archive on your host, then exits and is removed (`--rm`).

Option A is incorrect — `docker volume export` is not a real Docker command. Option B is incorrect — `docker cp` copies files from a container's filesystem, not from a named volume (and the syntax is wrong; you cannot reference a volume by name in `docker cp`). Option D might work on Linux where the Mountpoint is directly accessible, but it requires root access to `/var/lib/docker/volumes/`, does not work on macOS/Windows (where the volume lives inside a VM), and accessing the data while the database is writing can produce a corrupt backup. The temporary-container method (Option C) is the portable, correct approach.

</details>
