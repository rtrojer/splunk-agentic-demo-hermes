#!/bin/bash
set -e

STARTUP_TIMEOUT_SECONDS=${SPLUNK_DOCKER_STARTUP_TIMEOUT_SECONDS:-300}

if ! [[ "$STARTUP_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [ "$STARTUP_TIMEOUT_SECONDS" -lt 1 ] || [ "$STARTUP_TIMEOUT_SECONDS" -gt 1800 ]; then
    echo "Error: SPLUNK_DOCKER_STARTUP_TIMEOUT_SECONDS must be an integer between 1 and 1800." >&2
    exit 1
fi

test_docker_engine() {
    docker info --format '{{.ServerVersion}}' >/dev/null 2>&1
}

if ! test_docker_engine; then
    DOCKER_DESKTOP_EXE=""
    WINDOWS_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' || true)
    
    CANDIDATES=(
        "/mnt/c/Program Files/Docker/Docker/Docker Desktop.exe"
        "/mnt/c/Program Files (x86)/Docker/Docker/Docker Desktop.exe"
        "/mnt/c/Users/$WINDOWS_USER/AppData/Local/Programs/Docker/Docker/Docker Desktop.exe"
    )

    for cand in "${CANDIDATES[@]}"; do
        if [ -f "$cand" ]; then
            DOCKER_DESKTOP_EXE="$cand"
            break
        fi
    done

    if [ -z "$DOCKER_DESKTOP_EXE" ]; then
        echo "Docker Engine is unavailable and Docker Desktop.exe could not be found. Start Docker Desktop manually." >&2
        exit 1
    fi

    echo "Docker Engine unavailable; starting Docker Desktop..."
    # Execute in background via cmd.exe so it detaches properly from WSL
    cmd.exe /c "start \"\" \"$(wslpath -w "$DOCKER_DESKTOP_EXE")\""
    
    start_time=$(date +%s)
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [ "$elapsed" -ge "$STARTUP_TIMEOUT_SECONDS" ]; then
            echo "Error: Docker Engine did not become ready within $STARTUP_TIMEOUT_SECONDS seconds. Check Docker Desktop and its selected container engine." >&2
            exit 1
        fi
        
        sleep 5
        if test_docker_engine; then
            break
        fi
    done
fi

echo "Docker Desktop is running and the Docker Engine is ready. No Docker Compose command was executed."
