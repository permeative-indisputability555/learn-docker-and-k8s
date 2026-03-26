# 10 Progressive Docker Compose Challenges

Based on the Docker documentation, interactive labs (iximiuz, k8squest), and production best practices, here are 10 progressive Docker Compose challenges designed to simulate real-world engineering scenarios.

### Challenge 1: The "It Works on My Machine" Starter
*   **Story:** Your team has a simple Node.js website. You need to ensure every developer runs the exact same version without manually installing dependencies.
*   **Features:** `services`, `image`, `restart: always`.
*   **Success Criteria:** Running `docker compose up -d` starts the container; `docker compose ps` shows the status as "Up".

### Challenge 2: The Gateway Exposure
*   **Story:** The web server runs internally on port 80, but your host machine's port 80 is already taken by another project.
*   **Features:** `ports` mapping.
*   **Success Criteria:** Mapping a custom host port (e.g., `8081:80`) allows you to see the "Welcome" page at `http://localhost:8081` in your browser.

### Challenge 3: The Environment Injector
*   **Story:** Your application needs to connect to a specific API, but the API URL changes between "Development" and "Staging" environments.
*   **Features:** `environment` variables or an `.env` file.
*   **Success Criteria:** The application logs show it is connecting to the URL defined in your Compose file rather than a hardcoded default.

### Challenge 4: The Internal Bridge (Isolation)
*   **Story:** You are adding a database. For security, the database should **never** be accessible from the public internet, only by the web application.
*   **Features:** `networks` (User-defined bridge).
*   **Success Criteria:** The web app can "ping" the database by its service name (e.g., `db`), but trying to access the database port from your host machine fails.

### Challenge 5: The "Golden Data" Survival
*   **Story:** Every time you restart your database container, all your test users disappear because the container filesystem is ephemeral.
*   **Features:** `volumes` (Named volumes or bind mounts).
*   **Success Criteria:** Create a record in the database, run `docker compose down`, then `docker compose up`; the record must still exist.

### Challenge 6: The Race Condition Fixer
*   **Story:** Your application crashes on startup because it tries to connect to the database before the database is fully initialized and ready to accept connections.
*   **Features:** `depends_on` with `condition: service_healthy`, `healthcheck`.
*   **Success Criteria:** The application container remains in a "Waiting" state and only starts its process after the database health check returns "healthy".

### Challenge 7: The Security Hardening (Secrets)
*   **Story:** A security audit flagged that your database passwords are visible in plain text in your `docker-compose.yml` file.
*   **Features:** `secrets`.
*   **Success Criteria:** Passwords are moved into external secret files; the application reads the password from `/run/secrets/db_password` instead of an environment variable.

### Challenge 8: The OOM-Killer Guard
*   **Story:** One of your services has a memory leak that eventually crashes the entire host machine. You need to provide "guardrails".
*   **Features:** `deploy` limits (CPU and Memory).
*   **Success Criteria:** `docker stats` confirms the container is restricted to a specific memory limit (e.g., 128MB) and cannot exceed it.

### Challenge 9: The Multi-Stage Workflow (Profiles)
*   **Story:** You have "Admin Tools" (like a database GUI) that you need during local development but should **not** be started in the production environment.
*   **Features:** `profiles`.
*   **Success Criteria:** Running `docker compose up` starts only the core app; running `docker compose --profile debug up` starts the app plus the admin tools.

### Challenge 10: The Full Production Symphony
*   **Story:** You must deploy a "3-Tier" stack: a React Frontend, a Python API, and a Redis Cache, all behind an Nginx Reverse Proxy that load balances traffic.
*   **Features:** Multiple `networks` (frontend/backend isolation), `volumes` for Nginx config, `build` context for custom images, and `deploy` replicas.
*   **Success Criteria:** Accessing port 80 on the host reaches Nginx, which successfully routes traffic to the frontend; the frontend successfully fetches data from the API through the internal network.