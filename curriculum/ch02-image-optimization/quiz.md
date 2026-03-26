# Chapter 2 Quiz: Image Optimization

*Used by the skip-level protocol. A score of 4/5 (80%) is required to skip Chapter 2.*

---

## Question 1

You have this Dockerfile:

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "server.js"]
```

You build it, warm the cache, then change a single line in `server.js` and build again. What happens?

**A)** Only the `COPY . .` layer is rebuilt; `npm install` uses the cache.

**B)** Both `COPY . .` and `RUN npm install` are rebuilt from scratch.

**C)** Nothing is rebuilt because only metadata changed.

**D)** Only `RUN npm install` is rebuilt; `COPY` uses the cache.

<details>
<summary>Answer</summary>

**B — Both `COPY . .` and `RUN npm install` are rebuilt from scratch.**

When `server.js` changes, Docker detects that the output of `COPY . .` is different from the cached version. This invalidates that layer, and since cache invalidation cascades downward, `RUN npm install` must also be rebuilt even though `package.json` didn't change.

The fix is to copy `package.json` and `package-lock.json` separately before running `npm install`, then copy the rest of the source code afterward. That way, `npm install` only re-runs when dependencies actually change.

</details>

---

## Question 2

What is wrong with this Dockerfile snippet?

```dockerfile
RUN apt-get update
RUN apt-get install -y curl nginx
```

**A)** `apt-get` should be replaced with `apk` on all Linux base images.

**B)** The `update` and `install` commands are on separate `RUN` lines, which can cause the install to use a stale package index if the second line changes later.

**C)** There is nothing wrong — this is the recommended pattern.

**D)** `RUN` should only be used once per Dockerfile.

<details>
<summary>Answer</summary>

**B — The `update` and `install` commands are on separate `RUN` lines.**

If you later add a package to the `install` line, Docker invalidates only that layer and reuses the cached `apt-get update` layer — which may be months old. The package installation then runs against a stale package index, causing "Unable to locate package" errors or installing outdated packages.

The correct pattern is:
```dockerfile
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    curl \
    nginx \
    && rm -rf /var/lib/apt/lists/*
```

</details>

---

## Question 3

Which of the following best describes what a multi-stage Docker build accomplishes?

**A)** It builds the same image in parallel across multiple CPU cores to speed up the build.

**B)** It allows you to use one image (e.g., with a compiler) to build an artifact, then copy only that artifact into a smaller final image — leaving build tools behind.

**C)** It creates multiple tags for the same image automatically.

**D)** It splits a large Dockerfile into separate files that Docker executes in sequence.

<details>
<summary>Answer</summary>

**B — It uses one stage for building and copies only the artifact into a smaller final stage.**

A multi-stage build lets you use a large, feature-rich image (like `golang:1.21` with the full Go compiler) for compilation, then start a new stage from a minimal base image (like `alpine:3.21`) and copy only the compiled binary across with `COPY --from=builder`. The final image doesn't contain the compiler, the source code, or any build-time dependencies — just what's needed to run the application.

</details>

---

## Question 4

A developer notices that their Docker build is sending 800MB to the daemon before any instructions run, even though the application source code is only 2MB. What is the most likely cause and fix?

**A)** The `FROM` base image is too large. Switching to `alpine` will reduce the context transfer.

**B)** There is no `WORKDIR` set. Setting `WORKDIR /app` reduces the amount of data sent.

**C)** Directories like `node_modules` or `.git` are being included in the build context. Creating a `.dockerignore` file to exclude them will fix the issue.

**D)** `RUN` commands are too slow. Using `--no-cache` on the build will speed up the transfer.

<details>
<summary>Answer</summary>

**C — Large directories like `node_modules` or `.git` are included in the build context.**

The Docker build context is everything in the directory you pass to `docker build`. Without a `.dockerignore` file, Docker sends all of it — including large directories that the Dockerfile never uses. Creating a `.dockerignore` that excludes `node_modules/`, `.git/`, test data, and other non-essential files can reduce the build context from hundreds of megabytes to a few kilobytes.

The `.dockerignore` file also prevents sensitive files like `.env` from accidentally ending up in the image.

</details>

---

## Question 5

You have the following multi-stage Dockerfile and you want to inspect the intermediate `builder` stage for debugging without running the final production stage. Which command achieves this?

```dockerfile
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o server .

FROM alpine:3.21
COPY --from=builder /app/server /server
CMD ["/server"]
```

**A)** `docker build --stage=builder -t debug-image .`

**B)** `docker build --target builder -t debug-image .`

**C)** `docker build --only builder -t debug-image .`

**D)** `docker build --stop-at=builder -t debug-image .`

<details>
<summary>Answer</summary>

**B — `docker build --target builder -t debug-image .`**

The `--target` flag tells Docker to stop building at the specified stage name and use that as the final image. This is extremely useful for debugging: you can build only the `builder` stage, run a container from it, and inspect what happened during the compile step — without the production stage discarding those files.

```bash
docker build --target builder -t debug-builder .
docker run --rm -it debug-builder sh
# Now you're inside the builder stage with all build tools available
```

</details>

---

## Scoring

| Score | Result |
|-------|--------|
| 5 / 5 | Perfect — you can skip Chapter 2 entirely |
| 4 / 5 | Pass — skip granted |
| 3 / 5 | Borderline — consider reviewing Lesson 2 (layer caching) before skipping |
| 0–2 / 5 | Work through Chapter 2's lessons; you'll be glad you did |
