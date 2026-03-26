# Chapter 4 Quiz: The Silent Grinder

> "Before I let you move on, let's make sure the concepts stuck. Five questions. Take your time."
> — Sarah

---

These questions are used by the skip-level protocol. You need 4/5 (80%) to skip this chapter.

---

## Question 1

A container named `api` is running on Docker's default bridge network. Another container tries to connect to it using `curl http://api:3000`. What happens?

**A)** The request succeeds — Docker always supports container name resolution.

**B)** The request fails with `Could not resolve host: api` — the default bridge doesn't support DNS by name.

**C)** The request fails with `Connection refused` — the default bridge blocks all inter-container traffic.

**D)** The request succeeds only if both containers are started with the `--link` flag.

<details>
<summary>Answer</summary>

**B** — The default `bridge` network does not activate Docker's embedded DNS server. Container names are not resolvable on the default bridge. You would get a DNS resolution failure (`getaddrinfo ENOTFOUND api` or similar), not a connection refused. The correct solution is to use a user-defined bridge network, where Docker's embedded DNS at `127.0.0.11` handles name resolution automatically.

</details>

---

## Question 2

Your Dockerfile contains `EXPOSE 3000`. A colleague says "that means the port is now publicly accessible." Are they correct?

**A)** Yes — `EXPOSE` opens the port on the host machine.

**B)** Yes — `EXPOSE` creates a firewall rule that allows inbound traffic on port 3000.

**C)** No — `EXPOSE` is documentation only. It documents intent and enables `-P` (auto-publish), but does not actually publish the port or create any firewall rules.

**D)** No — `EXPOSE` only works inside Docker Compose, not with `docker run`.

<details>
<summary>Answer</summary>

**C** — `EXPOSE` is metadata. It documents that a container intends to listen on a port, and it makes the port available to `docker run -P` (which auto-assigns a random host port). It does not create iptables rules, does not open any host port, and does not make the service reachable from outside the container. You must still use `-p host_port:container_port` to actually publish a port.

</details>

---

## Question 3

A containerized Node.js app is started with `docker run -p 8080:3000 myapp`. The container is running, the logs show "Server listening on 127.0.0.1:3000", but `curl http://localhost:8080` fails with `Connection refused`. What is the most likely cause?

**A)** The port mapping is backwards — it should be `-p 3000:8080`.

**B)** The app inside the container is binding to `127.0.0.1` (the container's loopback), but Docker's port forwarding sends traffic to the container's `eth0` interface. The app never sees the forwarded traffic.

**C)** `curl` cannot be used to test Docker port mappings. Use `docker exec` instead.

**D)** The container needs to be on a user-defined network for port mapping to work.

<details>
<summary>Answer</summary>

**B** — This is the classic container binding trap. Docker's iptables DNAT rule forwards traffic arriving on host port 8080 to the container's `eth0` interface IP (e.g., `172.17.0.2:3000`). But the Node.js app is bound to `127.0.0.1:3000` inside the container — that's the loopback interface, completely separate from `eth0`. The forwarded packets arrive on `eth0`, find no listener, and are refused. The fix is to change the app to bind to `0.0.0.0:3000` (all interfaces).

</details>

---

## Question 4

You want to run a database container that is accessible to other containers on a specific Docker network, but should NOT be accessible from the host machine or any other host on the network. Which `docker run` approach achieves this?

**A)** `docker run --network myapp-net -p 5432:5432 postgres`

**B)** `docker run --network myapp-net postgres` (no `-p` flag)

**C)** `docker run --network none -p 5432:5432 postgres`

**D)** `docker run --network myapp-net -p 127.0.0.1:5432:5432 postgres`

<details>
<summary>Answer</summary>

**B** — Without `-p`, no host port is published. The container is reachable only by other containers on `myapp-net` (using the container name or alias). The host machine and external machines have no route to the container's port. Option D (`127.0.0.1:5432:5432`) would make it accessible from the host's localhost only, which is better than `0.0.0.0` but still exposes it on the host. Option A exposes it publicly. Option C with `--network none` would prevent any container-to-container connectivity at all.

</details>

---

## Question 5

You have three containers: `frontend`, `backend`, and `database`. You want `frontend` to talk to `backend`, and `backend` to talk to `database`, but `frontend` must NOT be able to reach `database` directly. Which approach achieves this?

**A)** Put all three on the same network, then use iptables rules inside each container to block direct connections.

**B)** Create two networks: `frontend-net` (frontend + backend) and `backend-net` (backend + database). Connect backend to both networks; frontend and database are on separate networks with no overlap.

**C)** Use `--network host` for all containers — the host's firewall will handle isolation.

**D)** This is not possible in Docker without a third-party network plugin.

<details>
<summary>Answer</summary>

**B** — Docker's network isolation model enforces this cleanly. Containers on different networks with no overlap cannot communicate. The backend, connected to both networks simultaneously, acts as the only bridge between tiers. The frontend has no network path to the database. This is the standard multi-tier architecture pattern. Option A would work in theory but is complex and fragile. Option C (`--network host`) removes all container isolation. Option D is incorrect — this is a core Docker feature.

</details>

---

## Score

| Score | Result |
|-------|--------|
| 5/5 | Perfect. Sarah is impressed. |
| 4/5 | Pass — you can skip this chapter. |
| 3/5 or below | Review the chapter lessons before moving on. |
