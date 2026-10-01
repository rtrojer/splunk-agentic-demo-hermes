#!/bin/bash
set -e

PROJECT_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
COMPOSE_FILE="$PROJECT_ROOT/runtime/docker-compose.yml"
COMPOSE_PROJECT=$(basename "$PROJECT_ROOT")

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Docker Compose file not found: $COMPOSE_FILE" >&2
    exit 1
fi

cd "$PROJECT_ROOT"

# Git checks
BRANCH=$(git branch --show-current)
if [ -z "$BRANCH" ]; then
    echo "Could not determine the current Git branch; refusing to purge." >&2
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "Git working tree is not clean. Commit, stash, or otherwise preserve changes before running Phase 4." >&2
    exit 1
fi

UPSTREAM=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)
if [ -z "$UPSTREAM" ]; then
    echo "Branch '$BRANCH' has no configured upstream; refusing to rebase or purge." >&2
    exit 1
fi

UPSTREAM_REMOTE="${UPSTREAM%%/*}"
UPSTREAM_BRANCH="${UPSTREAM#*/}"

if [ -z "$UPSTREAM_REMOTE" ] || [ -z "$UPSTREAM_BRANCH" ] || [ "$UPSTREAM_REMOTE" = "$UPSTREAM" ]; then
    echo "Could not identify the remote and branch from upstream '$UPSTREAM'." >&2
    exit 1
fi

# Docker checks
if ! docker info --format '{{.ServerVersion}}' >/dev/null 2>&1; then
    echo "Docker Engine is unavailable. Start Docker Desktop, then retry Phase 4." >&2
    exit 1
fi

COMPOSE_ARGS=("--project-name" "$COMPOSE_PROJECT")
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    COMPOSE_ARGS+=("--env-file" "$ENV_FILE")
fi
COMPOSE_ARGS+=("-f" "$COMPOSE_FILE")

# Verify resources belong exclusively to this demo
CONTAINER_IDS=$(docker ps -aq --filter "label=com.docker.compose.project=$COMPOSE_PROJECT")
DEMO_CONTAINER_IDS=()

for CONTAINER_ID in $CONTAINER_IDS; do
    # Simply getting the config file name
    CONFIG_FILE_LABEL=$(docker inspect "$CONTAINER_ID" | jq -r '.[0].Config.Labels["com.docker.compose.project.config_files"] // empty')
    
    if [[ "$CONFIG_FILE_LABEL" != *"docker-compose.yml"* ]]; then
        CONTAINER_NAME=$(docker inspect "$CONTAINER_ID" | jq -r '.[0].Name')
        echo "Compose project '$COMPOSE_PROJECT' also contains container '$CONTAINER_NAME' from another configuration; refusing to remove shared project resources." >&2
        exit 1
    fi
    DEMO_CONTAINER_IDS+=("$CONTAINER_ID")
done

NETWORK_IDS=$(docker network ls -q --filter "label=com.docker.compose.project=$COMPOSE_PROJECT")
for NETWORK_ID in $NETWORK_IDS; do
    NETWORK_NAME=$(docker network inspect "$NETWORK_ID" | jq -r '.[0].Labels["com.docker.compose.network"]')
    if [ "$NETWORK_NAME" != "splunk-net" ] && [ "$NETWORK_NAME" != "null" ]; then
        if [ "$NETWORK_NAME" != "null" ]; then
            echo "Compose project '$COMPOSE_PROJECT' contains unexpected network '$NETWORK_NAME'; refusing to remove shared project resources." >&2
            exit 1
        fi
    fi
    
    ATTACHED_CONTAINERS=$(docker network inspect "$NETWORK_ID" | jq -r '.[0].Containers | keys[]')
    for ATTACHED_CONTAINER in $ATTACHED_CONTAINERS; do
        found=false
        for demo_container in "${DEMO_CONTAINER_IDS[@]}"; do
            if [ "$ATTACHED_CONTAINER" = "$demo_container" ]; then
                found=true
                break
            fi
        done
        if [ "$found" = false ]; then
            echo "Network '$NETWORK_NAME' is used by a container outside this demo; refusing to remove it." >&2
            exit 1
        fi
    done
done

# Confirmation prompt
read -r -p "Rebase '$BRANCH' onto '$UPSTREAM' and remove this demo's containers, network, and declared volumes? [y/N] " response
if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "Aborted."
    exit 0
fi

echo "Fetching upstream $UPSTREAM..."
git fetch "$UPSTREAM_REMOTE" "$UPSTREAM_BRANCH" || { echo "Could not fetch '$UPSTREAM'; Docker resources were not removed." >&2; exit 1; }

echo "Rebasing '$BRANCH' onto '$UPSTREAM'..."
git rebase "$UPSTREAM" || { echo "Rebase onto '$UPSTREAM' failed. Resolve the Git state before retrying; Docker resources were not removed." >&2; exit 1; }

echo "Removing Docker Compose resources for '$COMPOSE_PROJECT'..."
docker compose "${COMPOSE_ARGS[@]}" down --volumes --remove-orphans || { echo "Git rebase succeeded, but Docker Compose purge failed. Re-run Phase 4 after inspecting project '$COMPOSE_PROJECT'." >&2; exit 1; }

echo "Phase 4 complete. Git branch '$BRANCH' is rebased onto '$UPSTREAM'; demo Compose resources have been removed."
echo "The Splunk image and host-side project files were retained."