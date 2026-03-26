# Chapter 01 Quiz: "It Works on My Machine"

This quiz is used for **skip-level assessment**. Score 4/5 or higher to skip Chapter 1.

Answer each question before looking at the answers at the bottom.

---

## Questions

**Q1.** You run `docker run nginx` and the container starts successfully. You open `http://localhost:80` in your browser and get "connection refused." What is the most likely cause?

- A) The nginx image is corrupted
- B) No port mapping was specified with `-p`, so nginx is only reachable inside the container
- C) nginx uses port 8080 by default, not port 80
- D) You need to run `docker start nginx` before it serves requests

---

**Q2.** What is the key difference between a Docker image and a Docker container?

- A) Images run on Linux; containers run on any OS
- B) An image is a running process; a container is a static file stored on disk
- C) An image is an immutable template; a container is a running instance created from that template
- D) Images are stored in the cloud; containers are stored locally

---

**Q3.** You run `docker ps` and see no output. You know you started a container 5 minutes ago. What command shows you whether that container still exists in a stopped state?

- A) `docker images`
- B) `docker ps -a`
- C) `docker inspect all`
- D) `docker container status`

---

**Q4.** Which two Linux kernel features does Docker rely on to isolate containers and limit their resource usage?

- A) SELinux and AppArmor
- B) iptables and nftables
- C) Namespaces and cgroups
- D) chroot and systemd

---

**Q5.** You want to run a container in the background, name it `my-app`, and map port 3000 on your host to port 3000 in the container. Which command is correct?

- A) `docker run my-app -background -port 3000:3000 node`
- B) `docker run -d --name my-app -p 3000:3000 node`
- C) `docker start --name my-app --port 3000 node`
- D) `docker run -d --name my-app --expose 3000 node`

---

## Answers

| # | Answer | Explanation |
|---|--------|-------------|
| Q1 | **B** | `EXPOSE` in a Dockerfile documents the port but does not publish it. Only `-p HOST:CONTAINER` makes a port accessible from the host. Without `-p`, nginx is running inside the container's isolated network namespace and is not reachable from outside. |
| Q2 | **C** | An image is a read-only, layered template — think "recipe." A container is a live running instance of that image, with a writable layer on top. You can run many containers from one image simultaneously. |
| Q3 | **B** | `docker ps` only shows *running* containers. `docker ps -a` shows all containers regardless of state, including stopped ones. New Docker users often run dozens of stopped containers and wonder where their disk space went. |
| Q4 | **C** | **Namespaces** provide isolation — each container gets its own view of the process tree, network stack, filesystem, and more. **cgroups** (control groups) enforce resource limits — maximum CPU, memory, I/O. These two kernel features are the foundation Docker is built on. |
| Q5 | **B** | `-d` runs detached (background), `--name my-app` sets the name, `-p 3000:3000` maps host port 3000 to container port 3000. Option D uses `--expose`, which only documents the port (same as `EXPOSE` in a Dockerfile) — it does not publish it to the host. |

---

## Scoring

- **5/5** — Skip approved. You've got this down solid.
- **4/5** — Skip approved. Review the explanation for your missed question.
- **3/5 or below** — Work through the lessons. They're short and you'll come out much stronger for it.
