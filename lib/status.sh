#!/usr/bin/env bash

############################################################
# Platform Status Library
############################################################

#
# Returns the total number of services
#
status_total_services() {

    local PLATFORM="$1"

    (
        platform_cd "$PLATFORM"

        docker compose config --services | wc -l
    )
}

############################################################

#
# Returns the number of running services
#
status_running_services() {

    local PLATFORM="$1"

    (
        platform_cd "$PLATFORM"

        docker compose ps --services --filter status=running | wc -l
    )
}

############################################################

#
# Returns number of Docker volumes
#
status_volume_count() {

    local PLATFORM="$1"

    local COMPOSE_FILE

    COMPOSE_FILE="$(get_compose_file "$PLATFORM")"

    discover_volumes "$COMPOSE_FILE" | wc -w
}

############################################################

#
# Returns number of Docker networks
#
status_network_count() {

    local PLATFORM="$1"

    (
        platform_cd "$PLATFORM"

        docker network ls \
            --format '{{.Name}}' \
            | grep "^$(basename "$(pwd)")" \
            | wc -l
    )
}

############################################################

#
# Prints the summary
#
status_summary() {

    local PLATFORM="$1"

    print_field "Status" "Running"

    print_field \
        "Containers" \
        "$(status_running_services "$PLATFORM") / $(status_total_services "$PLATFORM")"

    print_field \
        "Volumes" \
        "$(status_volume_count "$PLATFORM")"

    print_field \
        "Networks" \
        "$(status_network_count "$PLATFORM")"
}

############################################################

#
# Shows docker compose ps
#
status_containers() {

    local PLATFORM="$1"

    (
        platform_cd "$PLATFORM"

        docker compose ps
    )
}
