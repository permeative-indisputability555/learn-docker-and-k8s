---
name: env-check
description: Check if the system is ready for the Learn Docker & K8s game. Verifies Docker, Docker Compose, kubectl, kind, disk space, and port availability. Use when the user asks about requirements, setup, or environment issues.
argument-hint: "[--full]"
---

# Environment Check

Run the environment check script and report results to the player in a friendly way:

```bash
bash engine/environment-check.sh
```

## After the check:

### All Passed
Tell the player they're all set. If this is during game start, continue to the game.

### Some Warnings
Explain which optional tools are missing and when they'll need them:
- kubectl + kind: "You won't need these until Chapters 6-7 (Kubernetes). You can install them later!"
- curl: "Some challenge verifications use curl. Most things still work without it."

### Failures
Guide the player to fix each failure:
- Docker not installed → Link to https://docs.docker.com/get-docker/
- Docker not running → "Start Docker Desktop" or `sudo systemctl start docker`
- Docker Compose missing → Link to https://docs.docker.com/compose/install/

If `$ARGUMENTS` contains "--full", also check:
- Docker can pull images: `docker pull hello-world`
- Docker can run containers: `docker run --rm hello-world`
- Docker networking works: `docker network create learn-test && docker network rm learn-test`

Be encouraging — don't make missing optional tools feel like failures.
