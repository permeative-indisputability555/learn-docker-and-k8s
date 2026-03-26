---
name: cleanup
description: Clean up Docker resources created by the Learn Docker & K8s game. Removes all learn-* containers, networks, volumes, and images. Use when the user wants to clean up, reset, or free disk space.
disable-model-invocation: true
argument-hint: "[chapter|all]"
---

# Cleanup Game Resources

This is a destructive operation. Always confirm with the player first.

## Step 1: Show What Exists

```bash
echo "=== Containers ==="
docker ps -a --filter "label=app=learn-docker-k8s" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo ""
echo "=== Networks ==="
docker network ls --filter "label=app=learn-docker-k8s" --format "table {{.Name}}\t{{.Driver}}"
echo ""
echo "=== Volumes ==="
docker volume ls --filter "label=app=learn-docker-k8s" --format "table {{.Name}}\t{{.Driver}}"
echo ""
echo "=== Images ==="
docker images --filter "reference=learn-*" --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"
```

## Step 2: Confirm

Show the player what will be removed and ask for confirmation.

If `$ARGUMENTS` is a specific chapter (e.g., "ch01", "ch03"):
- Only remove resources with the matching chapter label
- Tell them: "I'll only remove Chapter X resources. Everything else stays."

If `$ARGUMENTS` is "all" or empty:
- Run `bash engine/cleanup.sh`
- Also check for kind clusters: `kind get clusters 2>/dev/null | grep learn`

## Step 3: Clean

After confirmation, execute the cleanup and report what was removed.

If they're in the middle of a chapter, warn them: "You have in-progress work in Chapter X. Cleaning up means you'll need to redo the challenges. Continue?"

## Step 4: Update Progress (if needed)

If cleaning a specific chapter, update `.player/progress.yaml`:
- Reset that chapter's challenges to empty
- Set status back to "in-progress" (keep lesson progress)
