  ___ _   _ _    _  _     _                  _
 / __| |_| | |  | \| |___| |_ __ _____ _ _| | _____
| (__| ' \_  _| | .` / -_)  _\ V  V / _ \ '_| / /(_-<
 \___|_||_||_|  |_|\_\___|\__|\_/\_/\___/_| |_\_\/__/

 🔌 "The Silent Grinder"

    Default Bridge (broken) ❌     User-Defined Bridge (fixed!) ✅
    .---------------------.        .-------------------------.
    | frontend   backend  |        | frontend ----> backend  |
    |    ?           ?    |        |   OK    (DNS)    OK     |
    | "Host not found!"   |        | "Connected!"            |
    '---------------------'        '-------------------------'

    (-_-) Marcus: "Demo is in 2 hours." ⏰
    (^_^) Sarah:  "We've got this." 💪

# Chapter 4: The Silent Grinder

## Story

The demo went so well yesterday — until it didn't.

You walk in to find Sarah staring at her laptop, two empty coffee cups beside her. It's 10:03 AM. The investor demo is at noon.

"Frontend is up," she says without looking away from the screen. "Database is running. Data persists. Everything we fixed last chapter — still working. But..." She turns the laptop toward you.

```
Error: getaddrinfo ENOTFOUND backend
    at GetAddrInfoReqWrap.onlookupall [as oncomplete] (node:dns:118:26)
```

"The frontend can't find the backend. They're on the same machine. Same Docker host. But Docker's default network doesn't do DNS by name. So they can't see each other."

Dave pokes his head in. "Can't we just... hardcode the IP?"

Sarah closes her eyes for a moment. "Dave. The IP changes every time you restart a container."

"Oh." He retreats.

"Okay," Sarah says, looking at you. "I need you to fix this. Two hours. Let's learn networking."

---

## What You'll Learn

- How Docker's networking model works under the hood
- The difference between the default `bridge` network and user-defined bridges
- Why name resolution (DNS) is the right solution — not hardcoded IPs
- How port mapping works and what `-p` actually does
- How to architect network isolation between services

---

## Lessons

| # | File | Topic |
|---|------|--------|
| 1 | `lessons/01-network-drivers.md` | Network drivers: bridge, host, none, overlay, macvlan |
| 2 | `lessons/02-dns-and-discovery.md` | Docker DNS, name resolution, network aliases |
| 3 | `lessons/03-port-mapping-deep-dive.md` | Port mapping internals, iptables, binding addresses |

---

## Challenges

| # | File | Goal |
|---|------|------|
| 1 | `challenges/01-fix-dns.md` | Fix the "host not found" error using a user-defined network |
| 2 | `challenges/02-fix-binding.md` | Fix a container that can't be reached from the host |
| 3 | `challenges/03-network-isolation.md` | Build a secure multi-tier network architecture |

---

## Verification

Run `challenges/verify.sh` after completing all three challenges.

---

## Post-Chapter Debrief

Once you pass verification, Sarah has something to say:

> "The demo went perfectly. Marcus nearly cried. Dave said 'I knew containers would work out' — I will never let him live that down.
>
> But here's the thing: every new developer we hire spends three days just getting this environment running. They have to remember which networks to create, which order to start things, which env vars to set...
>
> What if we could launch everything with one command?
>
> Meet me in Chapter 5. We're writing a Compose file."

---

## Resources Used

- Docker resource prefix: `learn-ch04-`
- Labels: `--label app=learn-docker-k8s --label chapter=ch04`
- Networks created: `learn-ch04-frontend-net`, `learn-ch04-backend-net`
- Containers used: `learn-ch04-frontend`, `learn-ch04-backend`, `learn-ch04-db`
