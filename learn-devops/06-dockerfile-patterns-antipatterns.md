# Dockerfile Patterns & Anti-Patterns

Here are the essential Dockerfile patterns and anti-patterns structured as "spot the bug" or "optimize this" challenges.

### 1. Layer Caching and "Stale Updates"
**Anti-Pattern:** Running `apt-get update` and `apt-get install` on separate lines. This leads to the "stale update" bug where Docker reuses a cached update layer, causing the installation to fail or fetch outdated packages.

*   **Before (Bug):**
    ```dockerfile
    RUN apt-get update
    RUN apt-get install -y curl nginx
    ```
*   **After (Fixed):**
    ```dockerfile
    RUN apt-get update && apt-get install -y \
        --no-install-recommends \
        curl \
        nginx && \
        rm -rf /var/lib/apt/lists/*
    ```
*   **Why:** Chaining commands ensures "cache busting" if the package list changes. Removing `/var/lib/apt/lists/` keeps the image size small.

### 2. Multi-Stage Builds (Size and Security)
**Anti-Pattern:** Including build-time tools (compilers, SDKs, debuggers) in the final production image, which increases image size and the security attack surface.

*   **Before (Bloated):**
    ```dockerfile
    FROM golang:1.21
    WORKDIR /app
    COPY . .
    RUN go build -o main .
    CMD ["./main"]
    ```
*   **After (Optimized):**
    ```dockerfile
    # Build stage
    FROM golang:1.21 AS builder
    WORKDIR /app
    COPY . .
    RUN go build -o main .

    # Final production stage
    FROM alpine:3.21 
    WORKDIR /root/
    COPY --from=builder /app/main .
    CMD ["./main"]
    ```
*   **Why:** The final image only contains the compiled binary and the minimal Alpine OS (under 6MB), leaving behind heavy compilers and source code.

### 3. Dependency Caching (The Order of Instructions)
**Anti-Pattern:** Copying the entire source code directory *before* installing dependencies. This forces Docker to reinstall all dependencies every time a single line of code changes.

*   **Before (Slow Build):**
    ```dockerfile
    FROM node:18-alpine
    WORKDIR /app
    COPY . .
    RUN npm install
    CMD ["node", "app.js"]
    ```
*   **After (Fast Build):**
    ```dockerfile
    FROM node:18-alpine
    WORKDIR /app
    COPY package*.json ./
    RUN npm install
    COPY . .
    CMD ["node", "app.js"]
    ```
*   **Why:** Docker caches instructions. By copying only `package.json` first, the `npm install` layer is reused as long as dependencies haven't changed, even if the application code has.

### 4. Security Hardening (User Privilege)
**Anti-Pattern:** Running the container application as the default `root` user, which provides an easy path for attackers to compromise the host system.

*   **Before (Insecure):**
    ```dockerfile
    FROM python:3.11-slim
    WORKDIR /app
    COPY requirements.txt .
    RUN pip install -r requirements.txt
    COPY . .
    CMD ["python", "app.py"]
    ```
*   **After (Hardened):**
    ```dockerfile
    FROM python:3.11-slim
    RUN groupadd -r myuser && useradd -r -g myuser myuser
    WORKDIR /app
    COPY . .
    RUN chown -R myuser:myuser /app
    USER myuser
    CMD ["python", "app.py"]
    ```
*   **Why:** Switching to a non-root `USER` limits the permissions of the application process inside the container.

### 5. .dockerignore Usage
**Anti-Pattern:** Sending a massive "build context" (including `node_modules`, `.git`, or temporary files) to the Docker daemon. This slows down the build process and can accidentally include secrets or local configurations in the image.

*   **Challenge:** "The build context is 1.5GB even though my app is only 5MB. Optimize this."
*   **Solution (Create a `.dockerignore` file):**
    ```text
    .git
    node_modules
    build/*.log
    secrets.env
    ```
*   **Why:** This prevents Docker from processing irrelevant files, leading to faster builds and smaller context transfers.

### 6. Immutability and Pinning
**Anti-Pattern:** Using the `latest` tag for base images, which can cause unpredictable build failures when the image publisher updates the tag with breaking changes.

*   **Before (Unpredictable):**
    ```dockerfile
    FROM ubuntu:latest
    ```
*   **After (Reproducible):**
    ```dockerfile
    # Pinning by version tag or digest for absolute certainty
    FROM ubuntu:24.04@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c
    ```
*   **Why:** Pinning by digest guarantees you always use the exact same image version, ensuring build reproducibility across environments.