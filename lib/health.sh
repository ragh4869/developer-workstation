#!/usr/bin/env bash

# ============================================================
# Health Functions
# ============================================================

# Return the container state.
# Example: running, exited, paused, created, etc.
get_container_state() {
    local container="$1"

    docker inspect \
        --format '{{.State.Status}}' \
        "$container" 2>/dev/null
}


# Return the Docker health status.
#
# Possible results:
#   healthy
#   unhealthy
#   starting
#   no-healthcheck
#
get_container_health() {
    local container="$1"

    local health_status

    health_status="$(
        docker inspect \
            --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
            "$container" 2>/dev/null
    )"

    if [[ -z "$health_status" ]]; then
        printf '%s\n' "unknown"
    else
        printf '%s\n' "$health_status"
    fi
}


# Return success if the container is running.
is_container_running() {
    local container="$1"

    [[ "$(get_container_state "$container")" == "running" ]]
}
