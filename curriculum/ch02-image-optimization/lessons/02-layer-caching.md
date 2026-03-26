# Lesson 2: Layer Caching

## The Scene

"Okay," you say, refilling your coffee. "The image is 2GB. But honestly? Even if it were 200MB, the *build time* would still drive you crazy. Because right now, every single build reinstalls all the dependencies from scratch."

You pull up the terminal and trigger a build.

"Watch this."

```
[+] Building 4m 23s (8/8) FINISHED
```

"Four minutes. Just to rebuild after changing one line of application code. And the worst part — it doesn't have to be this way."

---

## How Docker's Build Cache Works

Docker is smarter than it looks. When you run `docker build`, Docker doesn't blindly re-execute every instruction. It checks each instruction against its cache.

For each instruction, Docker asks: **"Have I seen this exact instruction with this exact input before?"**

- If **yes**: Docker reuses the cached layer. You see `CACHED` in the output.
- If **no**: Docker executes the instruction and creates a new layer.

**The key rule: once any layer is invalidated (cache miss), all subsequent layers must be rebuilt too.**

This is why order matters so much.

---

## Watching the Cache in Action

Let's build the same image twice and compare:

**First build (no cache):**

```bash
docker build -t learn-ch02-cache-demo .
```

```
[+] Building 47.3s (7/7) FINISHED
 => [1/5] FROM node:20-alpine                              12.4s
 => [2/5] WORKDIR /app                                      0.1s
 => [3/5] COPY package*.json ./                             0.1s
 => [4/5] RUN npm install                                  31.2s
 => [5/5] COPY . .                                          0.2s
```

**Second build (unchanged files, cache warm):**

```bash
docker build -t learn-ch02-cache-demo .
```

```
[+] Building 1.4s (7/7) FINISHED
 => [1/5] FROM node:20-alpine                               0.0s
 => CACHED [2/5] WORKDIR /app                               0.0s
 => CACHED [3/5] COPY package*.json ./                      0.0s
 => CACHED [4/5] RUN npm install                            0.0s
 => CACHED [5/5] COPY . .                                   0.0s
```

Every layer is `CACHED`. Total build time: 1.4 seconds.

**Now let's change one line of application code and rebuild:**

```bash
echo "// a change" >> src/server.js
docker build -t learn-ch02-cache-demo .
```

```
[+] Building 3.1s (7/7) FINISHED
 => CACHED [1/5] FROM node:20-alpine                        0.0s
 => CACHED [2/5] WORKDIR /app                               0.0s
 => CACHED [3/5] COPY package*.json ./                      0.0s
 => CACHED [4/5] RUN npm install                            0.0s
 => [5/5] COPY . .                                          0.2s   <-- rebuilt
```

3.1 seconds. Only the final `COPY . .` was invalidated because that's the first layer that changed. The expensive `npm install` was still cached.

This is the whole game.

---

## The Dependency-Before-Source Pattern

This is the single most impactful caching technique:

**Copy dependency files first, install dependencies, then copy source code.**

```dockerfile
# Good: dependencies cached separately from source
FROM node:20-alpine
WORKDIR /app

COPY package*.json ./     # Only changes when dependencies change
RUN npm install           # Cached unless package.json changed

COPY . .                  # Changes every time code changes
CMD ["node", "src/server.js"]
```

Compare to the naive approach:

```dockerfile
# Bad: dependencies reinstall on every code change
FROM node:20-alpine
WORKDIR /app

COPY . .                  # Changes on every code edit
RUN npm install           # Invalidated every single build
CMD ["node", "src/server.js"]
```

With the bad approach, every time you change one line in `server.js`, Docker sees that `COPY . .` produced different output, invalidates that layer, and then has to re-run `npm install` from scratch.

With the good approach, `npm install` only re-runs when `package.json` or `package-lock.json` actually changes — which happens far less often than code changes.

The same pattern applies to other languages:

```dockerfile
# Python
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

```dockerfile
# Go
COPY go.mod go.sum ./
RUN go mod download
COPY . .
```

```dockerfile
# Ruby
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY . .
```

---

## The Stale apt-get Bug

This one is famous. It has burned a lot of people, including me during a 3 AM deploy that I'd rather not relive.

Here's the dangerous pattern:

```dockerfile
# DO NOT DO THIS
RUN apt-get update
RUN apt-get install -y curl nginx
```

Can you see the problem?

When Docker builds this the first time, both layers get cached. Now imagine it's six months later and you need to add `wget` to the install list:

```dockerfile
RUN apt-get update
RUN apt-get install -y curl nginx wget    # changed this line
```

Docker rebuilds from the changed line. But `apt-get update` was *not* changed — so Docker reuses its cached layer from six months ago. You're now running `apt-get install` against a six-month-old package index, trying to install versions of packages that may no longer exist in the repos.

The build fails with something like:

```
E: Unable to locate package curl
```

Or worse, it succeeds but installs outdated packages with known security vulnerabilities.

**The fix: always chain `apt-get update` and `apt-get install` in a single RUN:**

```dockerfile
# Correct
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    curl \
    nginx \
    wget \
    && rm -rf /var/lib/apt/lists/*
```

Now when you add `wget`, the entire line changes, the cache is invalidated, and `apt-get update` runs again before the install. Fresh package index every time.

The `--no-install-recommends` flag keeps apt from pulling in suggested packages you didn't ask for. The `rm -rf /var/lib/apt/lists/*` at the end removes the package index cache from the layer — you don't need it at runtime, so don't waste image space on it.

---

## What Invalidates the Cache?

For a `RUN` instruction:
- The instruction text itself changed

For a `COPY` or `ADD` instruction:
- The content of any copied file changed (Docker checksums the files)
- The instruction text changed

For `FROM`:
- The base image's digest changed (i.e., the image was updated upstream)

**Things that do NOT invalidate the cache:**
- File timestamps (Docker uses content checksums, not mtimes)
- File permissions on files you haven't COPYed yet

---

## Real Build Output: Reading the Cache Status

```bash
docker build --progress=plain -t learn-ch02-cache-test .
```

The `--progress=plain` flag gives you verbose output. Look for these markers:

```
#5 [3/5] RUN npm install
#5 CACHED
```

versus:

```
#5 [3/5] RUN npm install
#5 0.412 npm warn deprecated ...
#5 12.345 added 142 packages in 12s
```

The first is a cache hit. The second is a rebuild.

---

## Cache Control Options

Sometimes you *want* to bust the cache — for example, to force a fresh `apt-get update`:

```bash
# Disable cache entirely for this build
docker build --no-cache -t my-image .
```

```bash
# Invalidate from a specific stage (less common)
docker build --cache-from my-image:previous -t my-image .
```

Use `--no-cache` when you know upstream dependencies have changed and you need a genuinely fresh build. Don't use it by default or you'll lose all the benefits we just discussed.

---

## A Common Mistake: ENV Before COPY

Here's a subtle one:

```dockerfile
FROM node:20-alpine
WORKDIR /app
ENV BUILD_DATE=2024-01-15   # If you change this date...
COPY package*.json ./       # ...this and everything after gets invalidated
RUN npm install
```

If you put a frequently-changing `ENV` variable before a `COPY` and `RUN`, it busts the cache for everything that follows. Keep `ENV` variables that change often near the end of the Dockerfile, after the expensive steps.

---

## Summary: The Caching Rules

1. **Order matters.** Stable things go first, frequently-changing things go last.
2. **Copy dependency manifests separately** from source code.
3. **Chain `apt-get update && apt-get install`** in a single RUN to avoid the stale index bug.
4. **Invalidation cascades.** A cache miss on one layer busts all layers below it.
5. **`ENV` variables are layers too.** Changing one invalidates everything after it.

---

## Try It Yourself

1. Take the Dockerfile you built in Lesson 1
2. Make the deliberate mistake: move `COPY . .` to *before* `RUN npm install`
3. Build it once to warm the cache
4. Change a line in your `hello.js`
5. Build again and time it
6. Now fix the order (copy dependency files first, then install, then copy source)
7. Rebuild once to warm the cache
8. Change a line in `hello.js` again
9. Build again and compare the time

The difference will be obvious. Even for a small `npm install`, you'll notice. For a real project with hundreds of dependencies, the difference is the gap between "I can iterate quickly" and "I get coffee while I wait."

---

Next up: Lesson 3, where we tackle the biggest size reduction technique available — multi-stage builds. This is where we'll turn the Bean-Tracker image from a 2GB monster into something that would make Marcus smile.
