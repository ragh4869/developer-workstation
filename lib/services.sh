#!/usr/bin/env bash

###############################################################################
# Service inspection helpers
###############################################################################

platform_service_image() {
    local PLATFORM="$1"
    local SERVICE="$2"

    local COMPOSE_FILE
    COMPOSE_FILE="$(get_compose_file "$PLATFORM")"

    platform_cd "$PLATFORM" || return 1

    docker compose \
        -f "$COMPOSE_FILE" \
        config --format json |
        jq -r --arg service "$SERVICE" \
            '.services[$service].image // "N/A"'
}


platform_service_state() {
    local PLATFORM="$1"
    local SERVICE="$2"

    local COMPOSE_FILE
    COMPOSE_FILE="$(get_compose_file "$PLATFORM")"

    platform_cd "$PLATFORM" || return 1

    docker compose \
        -f "$COMPOSE_FILE" \
        ps -a \
        --format json 2>/dev/null |
        jq -r --arg service "$SERVICE" \
            'select(.Service == $service) | .State' |
        head -n 1
}


platform_service_health() {
    local PLATFORM="$1"
    local SERVICE="$2"

    local COMPOSE_FILE
    COMPOSE_FILE="$(get_compose_file "$PLATFORM")"

    platform_cd "$PLATFORM" || return 1

    docker compose \
        -f "$COMPOSE_FILE" \
        ps -a \
        --format json 2>/dev/null |
        jq -r --arg service "$SERVICE" \
            'select(.Service == $service) | .Health' |
        head -n 1
}


platform_service_ports() {
    local PLATFORM="$1"
    local SERVICE="$2"

    local COMPOSE_FILE
    COMPOSE_FILE="$(get_compose_file "$PLATFORM")"

    platform_cd "$PLATFORM" || return 1

    docker compose \
        -f "$COMPOSE_FILE" \
        ps -a \
        --format json 2>/dev/null |
        jq -r --arg service "$SERVICE" \
            'select(.Service == $service) | .Publishers |
             map(
                 if .PublishedPort then
                     (.PublishedPort | tostring) +
                     (if .TargetPort then ":" + (.TargetPort | tostring) else "" end)
                 else
                     ""
                 end
             ) |
             map(select(length > 0)) |
             join(", ")' |
        head -n 1
}
