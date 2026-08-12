#!/usr/bin/env bash

# ============================================================
# Workstation - Health Library
# Generic health functions used across all platforms
# ============================================================

# ------------------------------------------------------------
# Get container ID for a Compose service
# ------------------------------------------------------------

get_service_container() {
    local compose_file="$1"
    local service="$2"

    docker compose \
        -f "$compose_file" \
        ps -q "$service" 2>/dev/null
}


# ------------------------------------------------------------
# Get container state
# ------------------------------------------------------------

get_container_state() {
    local container="$1"

    [[ -z "$container" ]] && {
        echo "not-found"
        return 1
    }

    docker inspect \
        --format '{{.State.Status}}' \
        "$container" 2>/dev/null || echo "not-found"
}


# ------------------------------------------------------------
# Get Docker health status
#
# Possible values:
#   healthy
#   unhealthy
#   starting
#   no-healthcheck
# ------------------------------------------------------------

get_container_health() {
    local container="$1"

    [[ -z "$container" ]] && {
        echo "not-found"
        return 1
    }

    local health

    health=$(
        docker inspect \
            --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
            "$container" 2>/dev/null
    )

    [[ -z "$health" ]] && health="unknown"

    echo "$health"
}


# ------------------------------------------------------------
# Check whether container is running
# ------------------------------------------------------------

is_container_running() {
    local container="$1"

    [[ "$(get_container_state "$container")" == "running" ]]
}


# ------------------------------------------------------------
# Check whether Docker healthcheck exists
# ------------------------------------------------------------

has_container_healthcheck() {
    local container="$1"

    [[ "$(get_container_health "$container")" != "no-healthcheck" ]]
}


# ------------------------------------------------------------
# Convert Docker state into display state
# ------------------------------------------------------------

health_display_state() {
    local container="$1"

    local state
    state="$(get_container_state "$container")"

    case "$state" in
        running)
            echo "Running"
            ;;

        exited)
            echo "Exited"
            ;;

        restarting)
            echo "Restarting"
            ;;

        paused)
            echo "Paused"
            ;;

        created)
            echo "Created"
            ;;

        dead)
            echo "Dead"
            ;;

        *)
            echo "Unknown"
            ;;
    esac
}


# ------------------------------------------------------------
# Convert Docker health status into display value
# ------------------------------------------------------------

health_display_health() {
    local container="$1"

    local health
    health="$(get_container_health "$container")"

    case "$health" in
        healthy)
            echo "Healthy"
            ;;

        unhealthy)
            echo "Unhealthy"
            ;;

        starting)
            echo "Starting"
            ;;

        no-healthcheck)
            echo "No healthcheck"
            ;;

        *)
            echo "Unknown"
            ;;
    esac
}


# ------------------------------------------------------------
# Determine final health result
#
# Result:
#   Healthy
#   Unhealthy
#   Starting
#   Needs check
#   Not running
# ------------------------------------------------------------

health_result() {
    local container="$1"

    local state
    local health

    state="$(get_container_state "$container")"
    health="$(get_container_health "$container")"

    if [[ "$state" != "running" ]]; then
        case "$state" in
            exited)
                echo "Not running"
                ;;

            restarting)
                echo "Restarting"
                ;;

            *)
                echo "Not running"
                ;;
        esac

        return
    fi

    case "$health" in
        healthy)
            echo "Healthy"
            ;;

        unhealthy)
            echo "Unhealthy"
            ;;

        starting)
            echo "Starting"
            ;;

        no-healthcheck)
            echo "Needs check"
            ;;

        *)
            echo "Needs check"
            ;;
    esac
}


# ------------------------------------------------------------
# Locate Compose file for a platform
# ------------------------------------------------------------

health_compose_file() {
    local platform_dir="$1"

    local candidates=(
        "$platform_dir/compose.yml"
        "$platform_dir/compose.yaml"
        "$platform_dir/docker-compose.yml"
        "$platform_dir/docker-compose.yaml"
    )

    local file

    for file in "${candidates[@]}"; do
        if [[ -f "$file" ]]; then
            echo "$file"
            return 0
        fi
    done

    return 1
}


# ------------------------------------------------------------
# Get services defined by Compose
# ------------------------------------------------------------

health_list_services() {
    local compose_file="$1"

    docker compose \
        -f "$compose_file" \
        config --services 2>/dev/null
}


# ------------------------------------------------------------
# Check whether a service exists
# ------------------------------------------------------------

health_service_exists() {
    local compose_file="$1"
    local service="$2"

    health_list_services "$compose_file" |
        grep -Fxq "$service"
}


# ------------------------------------------------------------
# Run health check for one service
#
# Sets:
#   HEALTH_STATE
#   HEALTH_STATUS
#   HEALTH_RESULT
# ------------------------------------------------------------

health_check_service() {
    local compose_file="$1"
    local service="$2"

    HEALTH_STATE="Unknown"
    HEALTH_STATUS="Unknown"
    HEALTH_RESULT="Unknown"

    local container

    container="$(get_service_container "$compose_file" "$service")"

    if [[ -z "$container" ]]; then
        HEALTH_STATE="Not running"
        HEALTH_STATUS="Unavailable"
        HEALTH_RESULT="Not running"
        return 0
    fi

    HEALTH_STATE="$(health_display_state "$container")"
    HEALTH_STATUS="$(health_display_health "$container")"
    HEALTH_RESULT="$(health_result "$container")"
}
