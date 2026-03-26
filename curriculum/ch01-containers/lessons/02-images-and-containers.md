# Lesson 02: Images and Containers

*Sarah speaking:* One of the first things that trips people up with Docker is the terminology. People use "image" and "container" interchangeably, and then they get confused when commands don't do what they expect. Let's nail this down.

---

## The Recipe vs. The Dish

Here's the analogy I use with every new hire:

> **A Docker image is a recipe. A container is the dish you cook from it.**

The recipe (image) is a static document. It lists all the ingredients and instructions. You can share it with anyone. You can store it on a shelf. Making a copy of the recipe doesn't cost you much.

The dish (container) is the live, running thing. It exists in time. It consumes resources. You can eat from it, you can modify it, and eventually you throw it away. But you can always cook a new dish from the same recipe.

This matters practically:

- One image can be used to launch many containers simultaneously
- Deleting a container doesn't delete the image
- Images are immutable — you can't change an image, only build a new one
- Containers have a writable layer on top of the image (more on this in a moment)

---

## What's Inside an Image?

A Docker image is made up of **layers**. Each layer represents a set of filesystem changes.

Think of it like a stack of transparencies on an overhead projector (ask Dave, he's old enough to remember those). Each transparency adds something. The combined result is what you see.

Here's a simple example — what the layers of an official Node.js image look like conceptually:

```
Layer 5: npm install (your app's dependencies)
Layer 4: COPY . /app (your application code)
Layer 3: RUN apt-get install -y curl (add a tool)
Layer 2: node:20-slim base (Node runtime + slim Debian)
Layer 1: debian:slim (base OS filesystem)
```

When Docker builds or pulls an image, it downloads each layer independently. If you already have Layer 1 and 2 from a previous pull, Docker skips them. This is why pulling a second Node-based image is much faster than the first — you already have the shared base layers cached.

This layering is implemented by the **overlay2** storage driver you saw in `docker info`. Each layer is a directory of filesystem diffs stored at `/var/lib/docker/overlay2/`. The Docker daemon mounts them together using Linux's OverlayFS.

---

## Docker Hub

Docker Hub (`hub.docker.com`) is the default public registry. It's where official images live — maintained by Docker, Inc. or by the software vendors themselves.

When you run `docker pull nginx`, Docker looks up `docker.io/library/nginx:latest` — the full address with registry, namespace, image name, and tag. The shorthand just hides the defaults.

Image tags are like version labels: `nginx:1.25`, `node:20-alpine`, `postgres:16`. The `latest` tag is just a convention — it doesn't actually guarantee you get the newest version, and in production you should always pin to a specific tag.

Other popular registries:
- **GitHub Container Registry** — `ghcr.io/owner/image:tag`
- **AWS ECR** — for images you want to keep private in AWS
- **Google Artifact Registry** — same idea for GCP

---

## Pulling Images

Let's actually pull some images and look at what happens.

### Pull nginx

```bash
docker pull nginx
```

You'll see something like:

```
Using default tag: latest
latest: Pulling from library/nginx
a480a496ba95: Pull complete
f3ace1b8ce45: Pull complete
11d6fdd0e8a7: Pull complete
f1091da6fd5c: Pull complete
40eea07b7574: Pull complete
6476794e50f4: Pull complete
70850b3ec6b2: Pull complete
Digest: sha256:67682bda769fae1ccf5183192b8daf37b64cae99c6c3302650f6f8bf5f0f95df
Status: Downloaded newer image for nginx:latest
docker.io/library/nginx:latest
```

Each line like `a480a496ba95: Pull complete` is one layer. The hex ID is a content hash — Docker knows if a layer has changed because its hash changes.

### Pull alpine

```bash
docker pull alpine
```

Alpine is a minimal Linux distribution — just ~7MB. Used as a base image when you want the smallest possible footprint.

---

## Hands-On Exercise: Compare Image Sizes

Now let's look at what you've pulled.

### List your local images

```bash
docker images
```

Output:

```
REPOSITORY   TAG       IMAGE ID       CREATED        SIZE
nginx        latest    a6bd71f48f68   2 weeks ago    187MB
alpine       latest    05455a08881e   5 weeks ago    7.38MB
```

Notice the size difference: nginx is ~187MB (includes a full web server, config, libraries), while alpine is just ~7MB (a bare-minimum Linux environment). This is why many Dockerfiles start with `FROM alpine` when size matters.

### Inspect an image in detail

```bash
docker inspect nginx
```

This outputs a JSON blob with everything Docker knows about the image: layers, environment variables, exposed ports, the default command, architecture, and more. Let's highlight a few fields:

```json
"RepoTags": ["nginx:latest"],
"ExposedPorts": {"80/tcp": {}},
"Cmd": [
  "nginx",
  "-g",
  "daemon off;"
],
"Layers": [
  "sha256:a480a496ba95...",
  "sha256:f3ace1b8ce45...",
  ...
]
```

- `ExposedPorts` — the port the app listens on *inside* the container. This is documentation; it doesn't actually publish the port to your host.
- `Cmd` — the default command that runs when you start a container from this image.
- `Layers` — the individual layer hashes that make up this image.

### Compare with alpine

```bash
docker inspect alpine | grep -A5 '"Layers"'
```

You'll see alpine has very few layers — it's a minimal image by design.

### Check image history

```bash
docker history nginx
```

This shows you each layer and the instruction that created it — effectively a reverse-engineered view of the Dockerfile used to build the image. Very useful for debugging why an image is larger than expected.

---

## Containers: The Running Instance

When you run `docker run nginx`, Docker takes the nginx image and creates a **container** from it — a live, running process with its own isolated filesystem, network stack, and process space.

The container gets a **writable layer** on top of the read-only image layers. Anything the running application writes (logs, temp files, database records) goes into that writable layer. When the container is deleted, the writable layer is deleted too. The image underneath is untouched.

This is why containers are called **ephemeral by default** — the data they generate doesn't persist unless you explicitly set up a volume (we'll cover that in Chapter 3).

```
Running Container:
┌─────────────────────────────┐
│  Writable Layer (container) │  ← Unique to this container instance
├─────────────────────────────┤
│  Layer 5 (read-only)        │  ← From the image
│  Layer 4 (read-only)        │
│  Layer 3 (read-only)        │
│  Layer 2 (read-only)        │
│  Layer 1 (read-only)        │
└─────────────────────────────┘
```

---

## Summary

- An **image** is immutable, layered, shareable — the recipe
- A **container** is a running instance of an image — the dish
- Docker Hub is the default public registry for images
- `docker pull` fetches image layers; shared layers are cached
- `docker images` lists your local images with sizes
- `docker inspect` gives you the full JSON metadata for an image or container
- `docker history` shows you what built each layer

Next, let's learn how to work with running containers — the commands you'll use every single day.

**Next lesson:** [Basic Commands](03-basic-commands.md)
