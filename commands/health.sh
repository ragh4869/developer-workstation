#!/usr/bin/env bash

# ============================================================
# Workstation - Platform Health
# Command orchestration
# ============================================================

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# ============================================================
# Arguments
# ============================================================

PLATFORM="${1:-}"
shift || true

REQUESTED_SERVICES=("$@")


# ============================================================
# Header
# ============================================================

print_header "Platform Health"

# ============================================================
# Validate platform
# ============================================================

if [[ -z "$PLATFORM" ]]; then
    printf 'Platform : All\n\n'
    printf '✗ Platform is required.\n'
    exit 1
fi

printf 'Platform : %s\n' "$PLATFORM"

if ! platform_exists "$PLATFORM"; then

    printf '✗ Unknown platform: %s\n\n' "$PLATFORM"

    printf 'ℹ Available Platforms\n'

    list_platforms

    exit 1
fi


# ============================================================
# Resolve platform directory
# ============================================================

PLATFORM_DIR="$(get_platform_dir "$PLATFORM")"

if [[ -z "$PLATFORM_DIR" || ! -d "$PLATFORM_DIR" ]]; then
    printf '✗ Platform directory not found: %s\n' "$PLATFORM_DIR"
    exit 1
fi


# ============================================================
# Resolve Compose file
# ============================================================

COMPOSE_FILE="$(health_compose_file "$PLATFORM_DIR")"

if [[ -z "$COMPOSE_FILE" || ! -f "$COMPOSE_FILE" ]]; then

    printf '✗ No Compose file found for platform: %s\n' "$PLATFORM"

    printf '\nExpected one of:\n'
    printf '  compose.yml\n'
    printf '  compose.yaml\n'
    printf '  docker-compose.yml\n'
    printf '  docker-compose.yaml\n'

    exit 1
fi


# ============================================================
# Discover services
# ============================================================

mapfile -t ALL_SERVICES < <(
    health_list_services "$COMPOSE_FILE"
)

if [[ "${#ALL_SERVICES[@]}" -eq 0 ]]; then
    printf '✗ No services found for platform: %s\n' "$PLATFORM"
    exit 1
fi


# ============================================================
# Determine requested services
# ============================================================

SERVICES=()

if [[ "${#REQUESTED_SERVICES[@]}" -eq 0 ]]; then

    SERVICES=("${ALL_SERVICES[@]}")

else

    for service in "${REQUESTED_SERVICES[@]}"; do

        if ! health_service_exists "$COMPOSE_FILE" "$service"; then

            printf '✗ Unknown service: %s\n\n' "$service"

            printf 'ℹ  Available Services\n'

            printf '%s\n' "${ALL_SERVICES[@]}"

            exit 1
        fi

        SERVICES+=("$service")
    done

fi


# ============================================================
# Display selected services
# ============================================================

if [[ "${#REQUESTED_SERVICES[@]}" -eq 0 ]]; then
    printf 'Services : All\n'
else
    printf 'Services : %s\n' "$(IFS=,; echo "${SERVICES[*]}")"
fi

printf '\n'


# ============================================================
# Table Header
# ============================================================

printf '%-22s %-22s %-28s %-20s\n' \
    "Service" \
    "State" \
    "Health" \
    "Result"

printf '%-22s %-22s %-28s %-20s\n' \
    "----------------------" \
    "----------------------" \
    "----------------------------" \
    "--------------------"


# ============================================================
# Counters
# ============================================================

TOTAL=0
HEALTHY=0
UNHEALTHY=0
STARTING=0
NO_HEALTHCHECK=0
NOT_RUNNING=0
NEEDS_CHECK=0


# ============================================================
# Health orchestration
# ============================================================

for service in "${SERVICES[@]}"; do

    health_check_service "$COMPOSE_FILE" "$service"

    TOTAL=$((TOTAL + 1))

    case "$HEALTH_RESULT" in

        Healthy)
            HEALTHY=$((HEALTHY + 1))
            ;;

        Unhealthy)
            UNHEALTHY=$((UNHEALTHY + 1))
            ;;

        Starting)
            STARTING=$((STARTING + 1))
            ;;

        Needs\ check)
            NEEDS_CHECK=$((NEEDS_CHECK + 1))
            ;;

        Not\ running|Restarting)
            NOT_RUNNING=$((NOT_RUNNING + 1))
            ;;

    esac

    if [[ "$HEALTH_STATUS" == "No healthcheck" ]]; then
        NO_HEALTHCHECK=$((NO_HEALTHCHECK + 1))
    fi

    printf '%-22s %-22s %-28s %-20s\n' \
        "$service" \
        "$HEALTH_STATE" \
        "$HEALTH_STATUS" \
        "$HEALTH_RESULT"

done


# ============================================================
# Summary
# ============================================================

printf '\n'
printf '%s\n' '-----------------------------------------------------------------------------------------------'
printf '\n'

printf 'ℹ  %s services checked\n' "$TOTAL"
printf '✔  %s services healthy\n' "$HEALTHY"

if [[ "$UNHEALTHY" -gt 0 ]]; then
    printf ' ✘ %s services unhealthy\n' "$UNHEALTHY"
fi

if [[ "$STARTING" -gt 0 ]]; then
    printf ' ⚠ %s services still starting\n' "$STARTING"
fi

if [[ "$NO_HEALTHCHECK" -gt 0 ]]; then
    printf ' ⚠ %s services have no healthcheck\n' "$NO_HEALTHCHECK"
fi

if [[ "$NOT_RUNNING" -gt 0 ]]; then
    printf ' ✘ %s services are not running\n' "$NOT_RUNNING"
fi


# ============================================================
# Final platform result
# ============================================================

printf '\n'

if [[ "$UNHEALTHY" -gt 0 || "$NOT_RUNNING" -gt 0 ]]; then

    printf '✘ Platform is unhealthy.\n'
    exit 1

elif [[ "$STARTING" -gt 0 ]]; then

    printf '⚠ Platform is starting; health verification is incomplete.\n'
    exit 1

elif [[ "$NEEDS_CHECK" -gt 0 ]]; then

    printf '⚠ Platform is running, but some services require additional health verification.\n'
    exit 0

else

    printf '✔  Platform is healthy.\n'
    exit 0

fi
