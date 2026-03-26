# Lesson 2: DNS and Service Discovery

> "Every time you type `google.com` in a browser, your machine asks a DNS server: 'Hey, what's the IP for this name?' Docker does the exact same thing — but it runs its own private DNS server inside every user-defined network."
> — Sarah

---

## What Is DNS?

DNS stands for Domain Name System. It's the internet's phone book.

When a container runs `curl http://backend:3000`, it doesn't know what IP address `backend` maps to. It needs to look it up. Here's what happens:

1. The container checks its `/etc/resolv.conf` to find a DNS server
2. It sends a query: "What is the IP for `backend`?"
3. The DNS server responds with an A record: `backend -> 172.18.0.3`
4. The container makes the TCP connection to that IP

In a user-defined Docker network, Docker runs this DNS server automatically. You don't configure anything — it just works.

---

## Docker's Embedded DNS Server

Docker's embedded DNS server listens at **127.0.0.11**.

This is a fixed address in Docker's reserved range. You'll see it inside every container that's on a user-defined network:

```bash
# Create a network and a container on it:
docker network create \
  --label app=learn-docker-k8s --label chapter=ch04 \
  learn-ch04-dns-demo

docker run -d --name learn-ch04-resolver \
  --network learn-ch04-dns-demo \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 120

# Check the DNS config inside the container:
docker exec learn-ch04-resolver cat /etc/resolv.conf
# nameserver 127.0.0.11
# options ndots:0

# Clean up after:
# docker rm -f learn-ch04-resolver
# docker network rm learn-ch04-dns-demo
```

The `127.0.0.11` entry is Docker's DNS stub resolver. When a container queries it, Docker looks up the container name in its internal registry and returns the container's current IP.

**Why this is powerful:** Even if you restart a container and it gets a new IP, the DNS name still works. The DNS server always returns the current, live IP.

---

## Watching DNS Resolution in Action

Let's run two containers and watch them find each other:

```bash
# Set up the network:
docker network create \
  --label app=learn-docker-k8s --label chapter=ch04 \
  learn-ch04-dns-demo

# Start a "backend" container:
docker run -d --name learn-ch04-backend \
  --network learn-ch04-dns-demo \
  --label app=learn-docker-k8s --label chapter=ch04 \
  nginx:alpine

# Start a "frontend" container:
docker run -d --name learn-ch04-frontend \
  --network learn-ch04-dns-demo \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 120

# From the frontend, resolve the backend by name:
docker exec learn-ch04-frontend nslookup learn-ch04-backend
# Server:    127.0.0.11
# Address 1: 127.0.0.11
#
# Name:      learn-ch04-backend
# Address 1: 172.18.0.3 learn-ch04-backend.learn-ch04-dns-demo

# Ping by name — works!
docker exec learn-ch04-frontend ping -c 3 learn-ch04-backend
# PING learn-ch04-backend (172.18.0.3): 56 data bytes
# 64 bytes from 172.18.0.3: seq=0 ttl=64 time=0.143 ms
# 64 bytes from 172.18.0.3: seq=1 ttl=64 time=0.118 ms
# 64 bytes from 172.18.0.3: seq=2 ttl=64 time=0.127 ms

# HTTP request by name — also works:
docker exec learn-ch04-frontend wget -qO- http://learn-ch04-backend
# <!DOCTYPE html>... (nginx response)
```

No hardcoded IPs. No config files. Just the container name.

---

## What Happens on the Default Bridge?

Compare the same setup, but on Docker's default bridge:

```bash
docker run -d --name learn-ch04-default-a \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 60

docker run -d --name learn-ch04-default-b \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 60

# Try DNS resolution — it fails:
docker exec learn-ch04-default-a nslookup learn-ch04-default-b
# nslookup: can't resolve 'learn-ch04-default-b'

# Check /etc/resolv.conf — no Docker DNS:
docker exec learn-ch04-default-a cat /etc/resolv.conf
# nameserver 192.168.65.7  (or your host's DNS, not 127.0.0.11)

# Clean up:
docker rm -f learn-ch04-default-a learn-ch04-default-b
```

The default bridge uses your host's DNS resolver — which has no idea what `learn-ch04-default-b` is.

---

## DNS Record Types (Background)

You'll encounter these in job interviews and real debugging:

| Record Type | Maps | Example |
|-------------|------|---------|
| A | hostname → IPv4 address | `backend → 172.18.0.3` |
| AAAA | hostname → IPv6 address | `backend → ::1` |
| CNAME | alias → canonical name | `www → backend` |
| PTR | IP → hostname (reverse lookup) | `172.18.0.3 → backend` |

Docker's embedded DNS returns **A records** for container names.

---

## Network Aliases

Sometimes you want a container to be reachable under a different name — for example, to match what your app code expects without renaming the container.

Network aliases solve this:

```bash
docker network create \
  --label app=learn-docker-k8s --label chapter=ch04 \
  learn-ch04-alias-demo

# The container is named 'learn-ch04-postgres-v14'
# but the app expects to reach 'db'
docker run -d --name learn-ch04-postgres-v14 \
  --network learn-ch04-alias-demo \
  --network-alias db \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 120

docker run -d --name learn-ch04-app \
  --network learn-ch04-alias-demo \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 120

# The app can reach it as 'db':
docker exec learn-ch04-app nslookup db
# Name:      db
# Address 1: 172.19.0.2 learn-ch04-postgres-v14.learn-ch04-alias-demo

# And also as the full container name:
docker exec learn-ch04-app nslookup learn-ch04-postgres-v14
# Same result

# Clean up:
docker rm -f learn-ch04-postgres-v14 learn-ch04-app
docker network rm learn-ch04-alias-demo
```

Network aliases are additive — a container can have multiple aliases, and multiple containers can share the same alias (Docker will round-robin between them, giving you basic load balancing).

---

## Connecting to Multiple Networks

A container can be on more than one network simultaneously. This is how you architect service tiers:

```bash
# A backend that can talk to both the frontend network and the DB network:
docker run -d --name learn-ch04-backend \
  --network learn-ch04-frontend-net \
  --label app=learn-docker-k8s --label chapter=ch04 \
  nginx:alpine

# Later, attach it to the DB network too:
docker network connect learn-ch04-backend-net learn-ch04-backend

# Now it has two IPs — one on each network:
docker inspect learn-ch04-backend \
  --format '{{json .NetworkSettings.Networks}}' | python3 -m json.tool
```

You'll use exactly this technique in Challenge 3.

---

## The `--link` Flag (Historical Footnote)

You might see older tutorials using `--link`:

```bash
# Old way — don't do this:
docker run --link other-container:alias myapp
```

`--link` was the original way to connect containers before user-defined networks existed. It modified `/etc/hosts` inside the container. It's deprecated, doesn't scale, doesn't support dynamic reconnection, and breaks in subtle ways.

**Forget it exists.** Use user-defined networks.

---

## Key Takeaways

1. Docker's embedded DNS lives at `127.0.0.11` — only active on user-defined networks
2. On a user-defined network, any container is reachable by its name from any other container on that network
3. If you restart a container, DNS still works — no IP hunting needed
4. Network aliases let you decouple the container name from the service name your app expects
5. The default bridge has no DNS — it's a footgun for beginners and a source of 2 AM pages

---

**Next:** `lessons/03-port-mapping-deep-dive.md` — What `-p 8080:80` actually does under the hood
