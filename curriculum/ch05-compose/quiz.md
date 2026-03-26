# Chapter 5 Quiz: The Symphony of Steam

> "Before we move on, let me make sure things actually stuck. These are the kinds of questions you'll get asked in a job interview — or that you'll wish you knew the answer to at 2 AM."
> — Sarah

---

## Question 1

You have a `docker-compose.yml` with two services: `api` and `postgres`. You add this to the `api` service:

```yaml
depends_on:
  - postgres
```

You run `docker compose up`. On the first run, the `api` crashes with a connection refused error. What is the most likely cause, and what is the correct fix?

A) The `depends_on` syntax is wrong — it should be `depends_on: [postgres]`

B) `depends_on` only waits for the `postgres` container to start, not for the Postgres server inside it to be ready. Fix: add a `healthcheck` to `postgres` and change `depends_on` to use `condition: service_healthy`

C) The `postgres` image doesn't support health checks. Fix: write a custom wait script in the `api` Dockerfile

D) `depends_on` is only for Kubernetes, not Docker Compose

<details>
<summary>Answer</summary>

**B** is correct.

`depends_on` (basic form) only controls container start order. The Postgres *container* may be running while the Postgres *database process* is still initializing and not yet accepting connections. The fix is to add a `healthcheck` to the `postgres` service using `pg_isready`, then update `depends_on` in `api` to use `condition: service_healthy`.

The other options are incorrect: the list syntax `[postgres]` is valid YAML but equivalent to the block form. Many images (including the official Postgres image) support health checks. And `depends_on` is a Docker Compose concept, not Kubernetes.

</details>

---

## Question 2

A teammate runs `docker compose up -d` and then asks: "Why isn't my code change showing up? I edited `server.js` but the old version is still running."

What is the most likely explanation, and what command should they run?

A) They need to restart Docker Desktop

B) Compose cached the image from the last build. They should run `docker compose up -d --build` to force a rebuild

C) They forgot to run `npm install` before starting Compose

D) The `server.js` changes are only visible after running `docker compose restart`

<details>
<summary>Answer</summary>

**B** is correct.

When you use `build:` in a Compose service, Compose builds the image once and caches it. Running `docker compose up -d` again does not rebuild the image unless you pass `--build`. The correct command is:

```bash
docker compose up -d --build
```

This forces Docker to re-run the build, pick up the code changes, create a new image, and restart the container with the updated image.

`docker compose restart` only restarts the container without rebuilding the image, so the change would still not appear.

</details>

---

## Question 3

You are reviewing a pull request. The diff includes this section of `docker-compose.yml`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: Tr0ub4dor&3
      POSTGRES_USER: admin
```

What should your review comment say, and what should the fix be?

A) Looks fine — environment variables in Compose files are always encrypted at rest

B) The password is weak. It should be at least 32 characters

C) The password is hardcoded in plain text in a file that will be committed to the repository. It should be moved to a `.env` file, referenced as `${POSTGRES_PASSWORD}`, and `.env` must be added to `.gitignore`

D) The `POSTGRES_USER` should not be `admin` — it should be `postgres` for compatibility

<details>
<summary>Answer</summary>

**C** is correct.

Hardcoding secrets in `docker-compose.yml` is a security vulnerability. The file will be committed to version control, and anyone who can read the repository — including future contributors, security auditors, or an attacker who gains access to the repo — can see the credentials.

The correct pattern:

1. Create `.env` with `POSTGRES_PASSWORD=Tr0ub4dor&3`
2. Add `.env` to `.gitignore`
3. Create `.env.example` with `POSTGRES_PASSWORD=change-me`
4. In `docker-compose.yml`: `POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}`

Password strength (B) is a separate concern, and the username (D) is irrelevant to the security issue being raised.

</details>

---

## Question 4

You want to add a database administration tool (Adminer) to your Compose file. It should be available when developers run `docker compose --profile dev up`, but should never start in a production deployment that runs just `docker compose up`.

Which configuration achieves this?

**Option A:**
```yaml
adminer:
  image: adminer
  environment:
    RUN_IN: dev
```

**Option B:**
```yaml
adminer:
  image: adminer
  profiles:
    - dev
```

**Option C:**
```yaml
adminer:
  image: adminer
  deploy:
    replicas: 0
```

**Option D:**
```yaml
adminer:
  image: adminer
  restart: "no"
```

<details>
<summary>Answer</summary>

**Option B** is correct.

The `profiles:` key is exactly designed for this use case. Services with a profile only start when that profile is explicitly activated:

```bash
docker compose up -d                   # adminer does NOT start
docker compose --profile dev up -d     # adminer starts
```

Option A would start Adminer every time — the `environment` key has no effect on whether a service starts.

Option C uses `deploy.replicas` which is a Docker Swarm concept and does not control startup behavior in standalone Compose.

Option D (`restart: "no"`) means the container will not be automatically restarted if it stops, but it would still start initially with `docker compose up`.

</details>

---

## Question 5

After running `docker compose up -d`, you check the status and see:

```
NAME                    STATUS              PORTS
learn-ch05-postgres-1   Up (healthy)        5432/tcp
learn-ch05-redis-1      Up (healthy)        6379/tcp
learn-ch05-backend-1    Up 3 seconds        0.0.0.0:3000->3000/tcp
learn-ch05-frontend-1   Up 2 seconds        0.0.0.0:8080->80/tcp
```

Then 30 seconds later you check again:

```
NAME                    STATUS              PORTS
learn-ch05-postgres-1   Up (healthy)        5432/tcp
learn-ch05-redis-1      Up (healthy)        6379/tcp
learn-ch05-backend-1    Restarting (1)      0.0.0.0:3000->3000/tcp
learn-ch05-frontend-1   Up 32 seconds       0.0.0.0:8080->80/tcp
```

The backend is in a `Restarting` state. Which of the following would be the BEST first diagnostic step?

A) Run `docker compose down -v && docker compose up -d --build` to start fresh

B) Run `docker compose logs backend` to see the error output from the backend container

C) Increase the `retries` count in the backend's health check configuration

D) Remove `depends_on` from the backend service — it might be causing a conflict

<details>
<summary>Answer</summary>

**B** is correct.

When a container is restarting, the first step is always to read its logs to understand *why* it exited. `docker compose logs backend` (or `docker compose logs --tail=50 backend`) shows the output from the container's last run, which typically contains the error that caused it to exit.

Common causes include:
- A missing environment variable the application requires
- An application error during initialization (e.g., failing to connect to a dependency)
- A crash in the application code

Option A (teardown and rebuild) is a sledgehammer approach that destroys state and loses the error information from the logs. Always diagnose before destroying.

Option C (increasing health check retries) would only matter if the backend had a health check — and health check failures cause the container to be marked `unhealthy`, not `Restarting`. `Restarting` means the container process is exiting.

Option D (removing `depends_on`) would make the race condition *worse*, not better. The backend probably crashed because it connected to Postgres before it was ready — that is what `depends_on: condition: service_healthy` is designed to prevent.

</details>
