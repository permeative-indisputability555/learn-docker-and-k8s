# Challenge 5.3: Secrets and Profiles

> "Marcus forwarded me a GitHub notification. Someone found our database password in our public repo. It was committed eight months ago. I already changed the password and rotated all the credentials, but this is exactly what I warned everyone about. Time to do this properly."
> — Sarah

---

## The Situation

Look at the `docker-compose.yml` from the previous challenge. You will see this:

```yaml
environment:
  POSTGRES_DB: cloudbrew
  POSTGRES_USER: brew
  POSTGRES_PASSWORD: brewpass      # <-- plaintext in the file
  DATABASE_URL: postgres://brew:brewpass@postgres:5432/cloudbrew   # <-- also here
```

These values are committed to the repository. Anyone who can read the repo can read these credentials. This needs to change.

Additionally, the team has been asking for a couple of things:

1. **Developers** want a database UI (Adminer) for browsing data locally — but it should never start in any other environment
2. **QA** wants a test runner that automatically runs integration tests against the stack — but it should only run when explicitly requested

Profiles can solve both problems.

---

## Your Task

This challenge has three parts.

### Part 1: Move secrets to a `.env` file

Create a `.env` file in the same directory as your `docker-compose.yml`. Move all sensitive values into it.

Sensitive values to move:
- `POSTGRES_PASSWORD`
- `DATABASE_URL` (contains the password)
- Any value that would cause harm if made public

Non-sensitive values can stay inline or also move to `.env` — your choice.

Update the `docker-compose.yml` to reference the variables from `.env` using `${VARIABLE_NAME}` syntax.

Verify that your `docker-compose.yml` contains no literal passwords or secrets.

### Part 2: Create a `.env.example` file

Create `.env.example` with placeholder values that shows developers what they need to set up, without exposing real credentials.

### Part 3: Add profiles

Add two new services with profiles:

**`adminer`** (profile: `dev`):
- Image: `adminer` (the official Adminer image)
- Port: `8081:8080`
- Network: `app-net`
- Labels: `app: learn-docker-k8s`, `chapter: ch05`

**`test-runner`** (profile: `test`):
- Build: the backend image (`../app/backend`)
- Command: `npm test`
- Environment: `DATABASE_URL` (from your `.env`), `NODE_ENV: test`
- Network: `app-net`
- Depends on: `postgres` with `condition: service_healthy`
- Labels: `app: learn-docker-k8s`, `chapter: ch05`

The test-runner should use `depends_on` with `condition: service_completed_successfully` is not needed here — just `service_healthy` on postgres is sufficient.

---

## Verifying the Profiles

After completing the challenge, test that profiles work correctly:

```bash
# Core stack only — should NOT start adminer or test-runner
docker compose down -v
docker compose up -d
docker compose ps
# Should show: postgres, redis, backend, frontend (4 services)

# Start with the dev profile — adminer should be added
docker compose --profile dev up -d
docker compose ps
# Should show: postgres, redis, backend, frontend, adminer (5 services)
# Adminer should be accessible at http://localhost:8081

# Run the test suite
docker compose --profile test run test-runner
# Should output test results and exit
```

---

## Success Criteria

Run the verification script:

```bash
bash challenges/verify.sh
```

The script checks:
1. All four core services are running
2. The `docker-compose.yml` file does not contain any literal passwords
3. A `.env` file exists
4. A `.env.example` file exists
5. `adminer` starts with `--profile dev`
6. Frontend is accessible at `http://localhost:8080`

---

## Hints

<details>
<summary>Hint 1 — The .env file location and syntax</summary>

The `.env` file must be in the same directory as your `docker-compose.yml`. Docker Compose loads it automatically — no extra configuration needed.

```bash
# .env
POSTGRES_DB=cloudbrew
POSTGRES_USER=brew
POSTGRES_PASSWORD=a-new-secure-password
DATABASE_URL=postgres://brew:a-new-secure-password@postgres:5432/cloudbrew
REDIS_URL=redis://redis:6379
```

In `docker-compose.yml`, reference them with dollar-brace syntax:

```yaml
environment:
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
  POSTGRES_DB: ${POSTGRES_DB}
```

You can verify the variables are being picked up correctly with:

```bash
docker compose config
```

This prints the fully resolved Compose file with all variables substituted — a great way to check there are no `${UNDEFINED_VARIABLE}` errors.

</details>

<details>
<summary>Hint 2 — .env.example format and .gitignore</summary>

The `.env.example` file is a template — real variable names, fake values:

```bash
# .env.example
# Copy this file to .env and fill in your values
POSTGRES_DB=cloudbrew
POSTGRES_USER=brew
POSTGRES_PASSWORD=change-me
DATABASE_URL=postgres://brew:change-me@postgres:5432/cloudbrew
REDIS_URL=redis://redis:6379
```

You should also have a `.gitignore` file that includes:

```
.env
```

This ensures `.env` is never accidentally committed, while `.env.example` is tracked.

To check for accidental secrets in your Compose file, you can use:

```bash
grep -i "password\|secret\|key" docker-compose.yml
```

The only matches should be variable references like `${POSTGRES_PASSWORD}`, not literal values.

</details>

<details>
<summary>Hint 3 — Profile syntax</summary>

Add the `profiles:` key to any service that should only start when explicitly activated:

```yaml
services:

  adminer:
    image: adminer
    ports:
      - "8081:8080"
    networks:
      - app-net
    profiles:
      - dev                     # only starts with --profile dev
    labels:
      app: learn-docker-k8s
      chapter: ch05

  test-runner:
    build: ../app/backend
    command: npm test
    environment:
      DATABASE_URL: ${DATABASE_URL}
      NODE_ENV: test
    networks:
      - app-net
    depends_on:
      postgres:
        condition: service_healthy
    profiles:
      - test                    # only starts with --profile test
    labels:
      app: learn-docker-k8s
      chapter: ch05
```

Services without a `profiles:` key always start. Services with `profiles:` only start when you pass `--profile <name>` to `docker compose`.

</details>
