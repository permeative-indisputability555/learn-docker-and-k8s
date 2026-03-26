# Challenge 5.2: Health Checks

> "It works... sometimes. Sometimes the backend starts fine, sometimes it crashes immediately. It depends on how fast Postgres initializes. On the CI server it almost always fails. This is the definition of a flaky system."
> — Sarah

---

## The Situation

You have a running Compose stack from Challenge 1. But there is a hidden fragility in it.

The `backend` service starts at the same time as `postgres`. Sometimes everything is fine — Postgres happens to be ready before the backend tries to connect. Sometimes the backend crashes with `ECONNREFUSED` and Docker just lets it die (or keeps restarting it in a loop, depending on the restart policy).

On a fast machine with a warm Docker cache, you might never notice. On the CI server, on a cold machine, or when someone runs `docker compose up` for the first time after a `docker compose down -v`, you will see failures.

The `docker-compose.yml` provided for this challenge does NOT have health checks. Your job is to add them.

---

## Starting Point

Save this as your `docker-compose.yml` and try running it a few times. On a cold start, the backend will frequently crash:

```yaml
name: learn-ch05

services:

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: cloudbrew
      POSTGRES_USER: brew
      POSTGRES_PASSWORD: brewpass
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-net
    labels:
      app: learn-docker-k8s
      chapter: ch05

  redis:
    image: redis:7-alpine
    networks:
      - app-net
    labels:
      app: learn-docker-k8s
      chapter: ch05

  backend:
    build: ../app/backend
    environment:
      DATABASE_URL: postgres://brew:brewpass@postgres:5432/cloudbrew
      REDIS_URL: redis://redis:6379
      PORT: "3000"
    ports:
      - "3000:3000"
    networks:
      - app-net
    depends_on:
      - postgres
      - redis
    labels:
      app: learn-docker-k8s
      chapter: ch05

  frontend:
    build: ../app/frontend
    ports:
      - "8080:80"
    networks:
      - app-net
    depends_on:
      - backend
    labels:
      app: learn-docker-k8s
      chapter: ch05

networks:
  app-net:
    labels:
      app: learn-docker-k8s
      chapter: ch05

volumes:
  db-data:
    labels:
      app: learn-docker-k8s
      chapter: ch05
```

To reproduce the failure reliably, tear down completely and restart:

```bash
docker compose down -v && docker compose up
```

Watch the backend logs:

```bash
docker compose logs -f backend
```

You may see something like:

```
Failed to initialize database: connect ECONNREFUSED 172.18.0.3:5432
```

---

## Your Task

Modify the `docker-compose.yml` to:

1. Add a health check to the `postgres` service using `pg_isready`
2. Add a health check to the `redis` service using `redis-cli ping`
3. Update the `backend` service's `depends_on` to use `condition: service_healthy` for both `postgres` and `redis`

The backend must not start until both Postgres and Redis pass their health checks.

---

## Success Criteria

Run the verification script:

```bash
bash challenges/verify.sh
```

The backend should now start cleanly every time. Verify by watching `docker compose ps` — Postgres and Redis should show as `healthy` before the backend starts:

```bash
watch docker compose ps
```

You should see the status progress:

```
postgres: starting → healthy
redis:    starting → healthy
backend:  (waiting) → starting → running
```

Also verify:

```bash
# Postgres health check is passing
docker inspect $(docker compose ps -q postgres) \
  --format '{{.State.Health.Status}}'
# Should output: healthy

# Redis health check is passing
docker inspect $(docker compose ps -q redis) \
  --format '{{.State.Health.Status}}'
# Should output: healthy

# Backend started without crashing (has been up for more than a few seconds)
docker compose ps backend
```

---

## Hints

<details>
<summary>Hint 1 — Where health checks go in the YAML</summary>

A health check is a property of the service that needs to be checked — not the service that depends on it. You add `healthcheck:` to the `postgres` service definition, and then reference the result in the `backend` service's `depends_on`.

```yaml
services:
  postgres:
    image: postgres:16-alpine
    ...
    healthcheck:        # <-- add this to postgres
      test: ...
      interval: ...

  backend:
    depends_on:
      postgres:
        condition: service_healthy   # <-- change this in backend
```

</details>

<details>
<summary>Hint 2 — The right test commands</summary>

For Postgres, the built-in tool is `pg_isready`. It checks if the Postgres server is accepting connections. You need to tell it which user and database to check:

```
pg_isready -U brew -d cloudbrew
```

For Redis, the built-in test is `redis-cli ping`. Redis responds with `PONG` when it is ready.

Both of these commands are available inside the official images — no extra packages needed.

For the `test:` property, use the `CMD-SHELL` form when you need the shell to evaluate the command:

```yaml
test: ["CMD-SHELL", "pg_isready -U brew -d cloudbrew"]
```

</details>

<details>
<summary>Hint 3 — Recommended timing values</summary>

Health checks that are too slow make startup feel sluggish. These values work well for local development:

```yaml
# For postgres:
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U brew -d cloudbrew"]
  interval: 5s        # check every 5 seconds
  timeout: 5s         # fail the check if it takes longer than 5 seconds
  retries: 5          # mark unhealthy after 5 consecutive failures
  start_period: 10s   # give postgres 10 seconds to start before counting failures

# For redis:
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 5s
  timeout: 3s
  retries: 5
```

And for the backend's `depends_on`:

```yaml
depends_on:
  postgres:
    condition: service_healthy
  redis:
    condition: service_healthy
```

</details>
