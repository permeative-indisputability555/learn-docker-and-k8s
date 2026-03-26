# Challenge 1: Optimize the Bloated Image

## The Situation

You pull up the Bean-Tracker repository and open the Dockerfile. You already knew it was bad. You just didn't know *how* bad.

Marcus is standing behind you. "Is that... `apt-get install build-essential`? In the production image?"

You close your eyes for a moment.

"Yes. Yes it is."

"And it's downloading the Go compiler at build time? From the internet?"

"It would appear so."

"Sarah, our production image is shipping a C compiler to our customers."

"It is. Yes."

"Fix it."

---

## Your Mission

The Bean-Tracker application is a simple Go HTTP server. Right now it lives in a bloated Docker image. Your job is to optimize it.

**Success criteria:** `docker images learn-ch02-app:optimized` must show an image under **100MB**.

---

## The Files

The application lives in `challenges/app/`. Here's what's there:

**`challenges/app/main.go`** — The Go application (don't modify this)

**`challenges/app/go.mod`** — Go module file (don't modify this)

**`challenges/app/Dockerfile.bloated`** — The current Dockerfile. Read it carefully.

---

## The Bloated Dockerfile

Open `challenges/app/Dockerfile.bloated` and read it. Count the problems.

Here's what you're working with:

```dockerfile
FROM ubuntu:22.04

RUN apt-get update
RUN apt-get install -y curl wget git build-essential

RUN wget https://go.dev/dl/go1.21.0.linux-amd64.tar.gz
RUN tar -C /usr/local -xzf go1.21.0.linux-amd64.tar.gz
RUN rm go1.21.0.linux-amd64.tar.gz

ENV PATH=$PATH:/usr/local/go/bin

COPY . /app

WORKDIR /app

RUN go mod download
RUN go build -o bean-tracker .

EXPOSE 8080

CMD ["/app/bean-tracker"]
```

---

## Your Task

1. Navigate to `challenges/app/`
2. Create a new file called `Dockerfile` (a fresh one — leave `Dockerfile.bloated` alone)
3. Optimize the build so the final image is under 100MB
4. Build it with this exact command (the verify script checks for this tag):

```bash
docker build \
  -t learn-ch02-app:optimized \
  -f challenges/app/Dockerfile \
  challenges/app/
```

5. Verify the image is running correctly:

```bash
docker run --rm -p 8080:8080 \
  --label app=learn-docker-k8s \
  --label chapter=ch02 \
  learn-ch02-app:optimized
```

Then in another terminal:
```bash
curl http://localhost:8080
curl http://localhost:8080/health
```

6. Check the size:

```bash
docker images learn-ch02-app:optimized
```

---

## Requirements

- The image must be tagged `learn-ch02-app:optimized`
- The image must be under 100MB (the verify script checks this in bytes)
- The application must respond to `GET /` and `GET /health`
- The final image must NOT contain the Go compiler or build tools

---

## Hints

Don't peek unless you're stuck. Try for at least 15 minutes first.

<details>
<summary>Hint 1 — General direction</summary>

The core problem is that this Dockerfile installs Go manually and leaves all the build tools in the final image. Ask yourself: does the running application actually *need* the Go compiler to serve HTTP requests? What would it take to have a build environment separate from the run environment?

</details>

<details>
<summary>Hint 2 — Specific technique</summary>

Look into multi-stage builds (covered in Lesson 3). The idea is: use the official `golang:1.21` image in one stage to compile the binary. Then start a second, much smaller stage and copy only the compiled binary across. The `golang:1.21` image is large, but it gives you a proper Go environment without the manual wget/tar dance. The final stage can use `alpine:3.21` or even smaller.

Also: when building Go for a Linux target with no C dependencies, try setting `CGO_ENABLED=0` — this produces a fully static binary that doesn't need any C libraries at runtime.

</details>

<details>
<summary>Hint 3 — Near-answer guidance</summary>

Your Dockerfile structure should look roughly like this:

```
Stage 1 (builder):
  FROM golang:1.21-alpine AS builder
  WORKDIR /app
  COPY go.mod ./          <- copy module file first
  RUN go mod download     <- cache this layer
  COPY . .
  RUN CGO_ENABLED=0 GOOS=linux go build -o bean-tracker .

Stage 2 (final):
  FROM alpine:3.21
  COPY --from=builder /app/bean-tracker /app/bean-tracker
  EXPOSE 8080
  CMD ["/app/bean-tracker"]
```

The `--from=builder` syntax in `COPY` is what copies files between stages. You can optionally add `-ldflags="-w -s"` to the build command to strip debug symbols and further shrink the binary.

</details>

---

## Verification

When you think you're done, run the chapter verify script:

```bash
bash curriculum/ch02-image-optimization/challenges/verify.sh
```

Or check manually:

```bash
# Check the image exists and see its size
docker images learn-ch02-app:optimized

# Check the size in bytes (should be less than 104857600)
docker image inspect learn-ch02-app:optimized --format '{{.Size}}'
```

---

## Post-Challenge Debrief

Once you pass, think about these questions (the game engine will discuss them with you):

1. **What you did:** You separated the build environment from the runtime environment using multi-stage builds.

2. **Why it works:** Docker throws away intermediate stages when the build is complete. Only the final `FROM` stage becomes the image. Files copied between stages with `COPY --from` are the only artifacts that survive.

3. **Real-world connection:** This pattern is standard practice at every company shipping containerized applications. The compiler has no business being in production. Neither does your source code, in most cases.

4. **Interview angle:** "What is a multi-stage Docker build and why would you use one?" is a very common interview question for DevOps and backend engineering roles.

5. **Pro tip:** You can build only a specific stage with `docker build --target builder .` — useful for debugging the build stage without running the full multi-stage pipeline.
