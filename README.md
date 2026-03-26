# Learn Docker & Kubernetes

An interactive, AI-driven learning game where you master Docker, Linux, networking, and Kubernetes through realistic work scenarios.

**No web app. No video courses. Just you, your AI editor, and hands-on challenges.**

## How It Works

1. Clone this repo
2. Open it in [Claude Code](https://claude.ai/code), [Cursor](https://cursor.com), or any AI-powered editor
3. Type "let's play"
4. Learn by doing — your AI becomes a mentor who guides you through real-world scenarios

The AI reads the game files and becomes **Sarah**, your senior DevOps engineer mentor at **CloudBrew** (a coffee subscription startup). She guides you through 7 chapters of increasingly complex challenges, from running your first container to managing a Kubernetes cluster in production.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running
- [Docker Compose](https://docs.docker.com/compose/install/) v2
- An AI-powered code editor ([Claude Code](https://claude.ai/code) recommended)
- For Chapters 6-7: [kubectl](https://kubernetes.io/docs/tasks/tools/) and [kind](https://kind.sigs.k8s.io/)

## The Story

You just joined **CloudBrew**, a fast-growing coffee subscription startup. Things are... a bit chaotic:

| Chapter | Title | What You'll Learn |
|---------|-------|-------------------|
| 1 | **It Works on My Machine** | Containers, images, basic Docker commands |
| 2 | **The 2GB Espresso** | Dockerfile optimization, multi-stage builds, caching |
| 3 | **The Vanishing Beans** | Volumes, bind mounts, data persistence |
| 4 | **The Silent Grinder** | Docker networking, DNS, service discovery |
| 5 | **The Symphony of Steam** | Docker Compose, health checks, secrets |
| 6 | **The Giant Roaster** | Kubernetes intro, Pods, Deployments, Services |
| 7 | **The Great Latte Leak** | K8s production ops, rolling updates, autoscaling |

Each chapter weaves in **Linux fundamentals** and **networking concepts** naturally — you'll learn subnets, DNS, NAT, process isolation, and more, all through Docker.

## Commands

If using Claude Code, these skills are available:

| Command | What It Does |
|---------|-------------|
| `/play` | Start or resume the game |
| `/env-check` | Verify your environment is ready |
| `/progress` | See your current progress |
| `/hint` | Get a hint for the current challenge |
| `/verify` | Check if your challenge solution is correct |
| `/next` | Move to the next lesson or challenge |
| `/skip-to 4` | Jump to a specific chapter (with quiz) |
| `/cleanup` | Remove game Docker resources |

Or just talk naturally — "I'm stuck", "check my work", "what's next" all work.

## What Makes This Different

- **AI as game engine** — No web app needed. The prompt files ARE the game code
- **Story-driven** — Every chapter has characters, stakes, and humor
- **Real environments** — You run actual Docker/K8s commands on your machine
- **Challenge mode** — The AI won't give you answers, only progressive hints
- **Cross-learning** — Docker teaches you Linux and networking fundamentals along the way
- **Safe sandbox** — All resources use `learn-` prefix, easy cleanup, no host damage

## Project Structure

```
.
├── CLAUDE.md              # AI entry point (Claude Code)
├── .cursorrules           # AI entry point (Cursor)
├── .claude/skills/        # Game commands (play, hint, verify, etc.)
├── engine/                # Game engine rules and scripts
│   ├── rules.md           # AI behavior: teaching vs challenge mode
│   ├── narrator.md        # Story, characters, tone guide
│   ├── validation.md      # How challenges are verified
│   ├── environment-check.sh
│   └── cleanup.sh
├── curriculum/
│   ├── ch01-containers/
│   │   ├── README.md      # Chapter story + objectives
│   │   ├── lessons/       # Teaching content
│   │   ├── challenges/    # Hands-on challenges + verify.sh
│   │   └── quiz.md        # Skip-level assessment
│   ├── ch02-image-optimization/
│   ├── ch03-persistence/
│   ├── ch04-networking/
│   ├── ch05-compose/
│   ├── ch06-k8s-intro/
│   └── ch07-k8s-production/
└── .player/
    └── progress.yaml      # Your progress (AI-managed)
```

## Contributing

This is an open-source project. Contributions welcome:

- **New challenges** — Add challenges to existing chapters
- **New chapters** — Extend beyond K8s (Helm, ArgoCD, monitoring)
- **Translations** — Translate lesson content (keep technical terms in English)
- **Bug fixes** — Fix verify.sh scripts or challenge instructions
- **Platform support** — Add entry points for other AI editors

## License

MIT
