#!/bin/bash
# Cleanup all learn-* Docker resources
# Safe: only removes resources with the learn-docker-k8s label

set -uo pipefail

echo "=== Learn Docker & K8s: Cleanup ==="
echo ""

# Stop and remove containers
CONTAINERS=$(docker ps -a --filter "label=app=learn-docker-k8s" -q 2>/dev/null)
if [ -n "$CONTAINERS" ]; then
    COUNT=$(echo "$CONTAINERS" | wc -l | tr -d ' ')
    echo "Stopping and removing $COUNT containers..."
    docker stop $CONTAINERS 2>/dev/null
    docker rm $CONTAINERS 2>/dev/null
    echo "  Done."
else
    echo "No containers to remove."
fi

# Remove networks
NETWORKS=$(docker network ls --filter "label=app=learn-docker-k8s" -q 2>/dev/null)
if [ -n "$NETWORKS" ]; then
    COUNT=$(echo "$NETWORKS" | wc -l | tr -d ' ')
    echo "Removing $COUNT networks..."
    docker network rm $NETWORKS 2>/dev/null
    echo "  Done."
else
    echo "No networks to remove."
fi

# Remove volumes
VOLUMES=$(docker volume ls --filter "label=app=learn-docker-k8s" -q 2>/dev/null)
if [ -n "$VOLUMES" ]; then
    COUNT=$(echo "$VOLUMES" | wc -l | tr -d ' ')
    echo "Removing $COUNT volumes..."
    docker volume rm $VOLUMES 2>/dev/null
    echo "  Done."
else
    echo "No volumes to remove."
fi

# Remove images with the learn-docker-k8s label
IMAGES=$(docker images --filter "label=app=learn-docker-k8s" -q 2>/dev/null)
if [ -n "$IMAGES" ]; then
    COUNT=$(echo "$IMAGES" | wc -l | tr -d ' ')
    echo "Removing $COUNT images..."
    docker rmi $IMAGES 2>/dev/null
    echo "  Done."
else
    echo "No images to remove."
fi

# K8s cleanup (if kubectl available)
if command -v kubectl &> /dev/null; then
    echo ""
    NAMESPACES=$(kubectl get namespaces -o name 2>/dev/null | grep "^namespace/learn-ch0" || true)
    if [ -n "$NAMESPACES" ]; then
        echo "Removing Kubernetes namespaces..."
        for ns in $NAMESPACES; do
            kubectl delete "$ns" --timeout=60s 2>/dev/null
        done
        echo "  Done."
    else
        echo "No Kubernetes namespaces to remove."
    fi
fi

echo ""
echo "Cleanup complete!"
