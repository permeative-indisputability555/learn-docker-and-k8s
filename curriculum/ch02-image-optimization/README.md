  ___ _    ___    ___
 / __| |_ |_  )  |_ _|_ __  __ _ __ _ ___ ___
| (__| ' \ / /    | || '  \/ _` / _` / -_|_-<
 \___|_||_/___|  |___|_|_|_\__,_\__, \___/__/
                                |___/

 🏋️ "The 2GB Espresso"

    BEFORE (2.1 GB) 😱         AFTER (23 MB) ✨
    .---------------.          .---------------.
    | ubuntu  750MB |          |               |
    | apt-get 500MB |          | alpine     8MB|
    | go build 800MB|          | binary    15MB|
    | source   50MB |          |               |
    '---------------'          '---------------'

    (-_-) Marcus: "Our cloud bill is insane." 💸

# Chapter 2: The 2GB Espresso

## Story

Marcus walked into the office this morning holding his laptop like it was evidence at a crime scene.

"Sarah." He turned the screen toward you. It was a deploy time chart. The line went up and to the right — not the good kind of up and to the right. "Ten minutes. Every single deploy. Do you know how many times I've had to stall investors saying 'it's almost ready'?"

You nodded slowly. You'd seen this coming ever since the Chapter 1 cliffhanger.

"Also," Marcus continued, pulling up a Slack message from the platform team, "staging is at 94% disk utilization. Apparently our Bean-Tracker image is... two gigabytes?"

It was. You'd helped build it. The guilt was real.

"The cloud bill went up 40% this month," he added. "Dave doesn't know yet. I'd like it to stay that way until you fix it."

You open the Dockerfile. You already know what you're going to find: a 2GB image, no caching strategy, build tools baked into production, and probably a `COPY . .` that's dragging in half the developer's home directory.

Time to make some espresso. The lean kind.

---

## What You'll Learn

By the end of this chapter, you'll be able to:

- Read and write every core Dockerfile instruction confidently
- Understand how Docker layers work and why they affect image size
- Use the build cache strategically to make builds dramatically faster
- Write multi-stage Dockerfiles that separate build tools from production images
- Choose the right base image for the job (ubuntu vs alpine vs distroless vs scratch)
- Use `.dockerignore` to keep your build context clean

---

## Prerequisites

- Chapter 1 completed (you understand what a container is and have run basic Docker commands)
- Docker installed and running
- Basic comfort with the command line

---

## Lessons

| # | Lesson | What you'll learn |
|---|--------|-------------------|
| 01 | [Dockerfile Deep Dive](lessons/01-dockerfile-deep-dive.md) | Every instruction, what it does, and why it exists |
| 02 | [Layer Caching](lessons/02-layer-caching.md) | How the build cache works and how to use it right |
| 03 | [Multi-Stage Builds](lessons/03-multi-stage-builds.md) | Separating build tools from production images |

---

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Optimize a Bloated Image](challenges/01-optimize-bloated-image.md) | Shrink a 2GB image down under 100MB |
| 02 | [Fix the Cache Bug](challenges/02-fix-cache-bug.md) | Repair a Dockerfile with broken caching |
| 03 | [Tame the Build Context](challenges/03-dockerignore.md) | Create a `.dockerignore` to stop sending gigabytes to the daemon |

---

## Verification

Run `challenges/verify.sh` to check all three challenges at once:

```bash
bash curriculum/ch02-image-optimization/challenges/verify.sh
```

---

## The Underlying Concepts

Docker images are built on **UnionFS** (Union Filesystem) — a layered filesystem that stacks read-only layers on top of each other. Each Dockerfile instruction creates a new layer. When you pull an image, Docker only downloads layers it doesn't already have.

This is why:
- Smaller layers = faster pulls from the registry
- Fewer layers with the same content = better cache reuse
- Build tools in the final image = wasted space and a bigger security attack surface

---

## Post-Chapter Cliffhanger

Once you complete all three challenges and the verify script passes, come back here.

You did it. The Bean-Tracker image went from 2GB to under 100MB. Deploys are now under a minute. Marcus sent a thumbs-up emoji, which for Marcus is basically a standing ovation.

Dave messaged: "Great work! Can't we use this for the database container too?" (You can. You won't. Not yet.)

But then your phone buzzes. Customer support ticket. Priority: High.

*"My saved coffee preferences disappeared after yesterday's update. All my favorites are gone. Is this a bug?"*

You stare at the ticket. Then you remember: the database container. Dave restarted it this morning to "free up memory."

You close your laptop. Open it again. Close it.

"Oh no."

See you in Chapter 3: **The Vanishing Beans**.
