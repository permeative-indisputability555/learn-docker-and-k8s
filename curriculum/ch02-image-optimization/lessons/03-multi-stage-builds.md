# Lesson 3: Multi-Stage Builds

## The Scene

"Alright," you say, opening the Bean-Tracker Dockerfile. "Here's where the real size comes from."

You scroll down. `FROM golang:1.21`. The Go compiler image. It's over 800MB on its own — and it's in the production image.

"We're shipping the compiler to production. Every customer request is being served by an image that contains a full Go development environment."

You can see the expression on the player's face: *why would anyone do that?*

"Because the alternative wasn't obvious until Docker added multi-stage builds. Before that, you had two options: one Dockerfile that was huge, or two separate Dockerfiles and a build script to glue them together. Both were annoying. Multi-stage builds solved it cleanly."

---

## The Problem: Build Tools Don't Belong in Production

When you compile a Go program, you need:
- The Go compiler (`go build`)
- The standard library source
- Build tools and headers

When you *run* a Go program, you need:
- The compiled binary
- Any shared libraries it links against (sometimes none, for static binaries)

That's it. The compiler, the standard library source, the build tools — none of that has any business being in a production image. It's dead weight that:

1. Makes the image bigger (slower pulls, more storage cost)
2. Increases the attack surface (more software = more potential vulnerabilities)
3. Means you're shipping your source code to production (usually undesirable)

---

## The Before: Single Stage

```dockerfile
FROM golang:1.21

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o server .

EXPOSE 8080
CMD ["./server"]
```

Let's look at what this image contains:
- The full Go toolchain (~800MB)
- All Go standard library sources
- Your source code
- The compiled binary

```bash
docker image ls
# golang-single-stage   latest   a1b2c3d4e5f6   2 minutes ago   872MB
```

872MB. For a web server whose binary is probably 12MB.

---

## The After: Multi-Stage Build

```dockerfile
# ---- Stage 1: Build ----
FROM golang:1.21 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o server .


# ---- Stage 2: Production ----
FROM alpine:3.21

WORKDIR /root/

COPY --from=builder /app/server .

EXPOSE 8080
CMD ["./server"]
```

```bash
docker image ls
# golang-multi-stage   latest   f6e5d4c3b2a1   30 seconds ago   13.2MB
```

13MB. Same binary. No compiler. No source code.

**The magic line is `COPY --from=builder`.** It copies a file from a previous build stage into the current stage. Docker builds the `builder` stage (with the full compiler), produces the binary, then throws the `builder` stage away and starts fresh with `alpine:3.21`. Only the binary survives into the final image.

---

## Anatomy of a Multi-Stage Dockerfile

```dockerfile
FROM image1 AS stage-name-1
# ... instructions ...

FROM image2 AS stage-name-2
# ... instructions ...
COPY --from=stage-name-1 /path/in/stage1 /path/in/stage2

FROM image3
COPY --from=stage-name-2 /some/artifact .
```

Key points:
- You can have as many stages as you want
- Stages are named with `AS name` (optional but highly recommended for readability)
- You can reference stages by name (`--from=builder`) or by index (`--from=0`)
- The final `FROM` determines what becomes the actual image

---

## Node.js Multi-Stage Example

The same principle applies to any compiled or build-step language:

```dockerfile
# ---- Stage 1: Install & build ----
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build          # Creates /app/dist/


# ---- Stage 2: Production server ----
FROM node:20-alpine AS production

WORKDIR /app

COPY package*.json ./
RUN npm ci --production    # Only production dependencies

COPY --from=builder /app/dist ./dist

EXPOSE 3000
CMD ["node", "dist/server.js"]
```

Here we have:
- Stage 1: Full dev dependencies + build tools (creates `dist/`)
- Stage 2: Only production dependencies + built output

The final image doesn't contain dev dependencies, build tools, or source files — just the compiled output and what's needed to run it.

---

## Choosing Your Base Image

The base image you choose for the final stage has a huge impact on image size and security posture. Here's how the options compare:

### ubuntu / debian
The default for many official images. Familiar, lots of packages available, large.

```dockerfile
FROM ubuntu:24.04
# ~70MB base. Full system utilities, apt package manager.
# Use when: you need many system-level packages or are unfamiliar with Alpine
```

### alpine
A minimal Linux distribution built for containers. Uses musl libc instead of glibc.

```dockerfile
FROM alpine:3.21
# ~7MB base. Uses apk package manager.
# Use when: you want small images and are comfortable with the occasional musl quirk
```

The Alpine caveat: some software behaves slightly differently with musl vs glibc. Most common applications work fine. Occasionally you'll hit a subtle bug that's specific to musl. If something mysterious breaks on Alpine, switching to a Debian slim image is a reasonable diagnostic step.

### distroless
Google's "no shell, no package manager" images. Contain only the runtime, nothing else.

```dockerfile
FROM gcr.io/distroless/static-debian12
# For Go static binaries: tiny (~2MB) and secure.

FROM gcr.io/distroless/nodejs20-debian12
# For Node.js apps.
```

Distroless images are excellent for security: there's no shell to exec into, no package manager to exploit, no utilities that could be weaponized. The tradeoff is that debugging is much harder — `docker exec mycontainer bash` won't work.

```dockerfile
# A distroless Go example
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 go build -o server .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /app/server /
CMD ["/server"]
```

### scratch
The empty image. Nothing. Not even a shell or a `ls` command.

```dockerfile
FROM scratch
COPY --from=builder /app/server /server
CMD ["/server"]
```

Only viable for statically compiled binaries with zero external dependencies. Go is the most common language where this works out of the box (with `CGO_ENABLED=0`).

### Comparison Table

| Base image | Size | Shell | Package manager | Use when |
|------------|------|-------|-----------------|----------|
| `ubuntu:24.04` | ~70MB | bash | apt | You need many system packages |
| `debian:bookworm-slim` | ~75MB | bash | apt | Familiar, smaller than full Debian |
| `alpine:3.21` | ~7MB | sh | apk | Small size, comfortable with musl |
| `distroless/static` | ~2MB | No | No | Go static binaries, security-first |
| `scratch` | 0MB | No | No | Fully static binaries, absolute minimum |

---

## .dockerignore — The Build Context Problem

Before we wrap up, there's one more thing that can make your builds slow and your images accidentally large: the build context.

When you run `docker build .`, Docker sends the entire current directory to the Docker daemon. This is the "build context." If you have `node_modules` (200MB), `.git` history (100MB), test fixtures, and local config files sitting in your project directory, all of that gets sent to the daemon before a single instruction runs.

You'll see it here:

```
[+] Building 0.0s (0/0)
=> transferring context: 347.82MB
```

347MB of context transfer before Docker even starts building. Painful.

**The fix is a `.dockerignore` file** — same syntax as `.gitignore`:

```
# .dockerignore

# Version control
.git
.gitignore

# Dependencies (they get installed during build)
node_modules

# Build output (don't copy in old build artifacts)
dist/
build/

# Local config and secrets
.env
.env.local
*.local

# Logs
*.log
npm-debug.log*

# OS junk
.DS_Store
Thumbs.db

# Test and dev files
*.test.js
*.spec.js
coverage/
__tests__/

# IDE files
.vscode/
.idea/
```

With a good `.dockerignore`, that same build looks like:

```
[+] Building 0.0s (0/0)
=> transferring context: 48.3kB
```

From 347MB to 48KB.

**`.dockerignore` also prevents accidental secret inclusion.** Without it, a `.env` file sitting in your project root gets sent to the daemon and could end up in the image. Always create a `.dockerignore` as part of setting up any project's Docker build.

---

## Putting It All Together

Here's the optimized Bean-Tracker Dockerfile using everything we've learned:

```dockerfile
# ---- Stage 1: Build the Go binary ----
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy dependency files first (cache optimization)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code (changes more often)
COPY . .

# Build a static binary
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -o bean-tracker .


# ---- Stage 2: Minimal production image ----
FROM alpine:3.21

# Good practice: run as non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY --from=builder /app/bean-tracker .

# Label for resource tracking
LABEL app=learn-docker-k8s
LABEL chapter=ch02

USER appuser

EXPOSE 8080
CMD ["./bean-tracker"]
```

Size comparison:

| Version | Size |
|---------|------|
| Original (ubuntu + full build env) | ~2.1GB |
| After multi-stage (alpine final) | ~18MB |
| With -ldflags stripping debug info | ~12MB |

That's roughly a 99.4% reduction. Marcus's chart is about to look very different.

---

## Try It Yourself

1. Look at the bloated Dockerfile provided in Challenge 1
2. Before attempting the challenge, try identifying which of these problems it has:
   - Build tools in the final image?
   - Inefficient `apt-get` pattern?
   - Wrong layer order for caching?
   - No `.dockerignore`?
   - Too large a base image for the final stage?

When you're ready to put all three lessons into practice, head to the challenges.
