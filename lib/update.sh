#!/usr/bin/env bash

###############################################################################
# Pull latest images
###############################################################################

platform_pull_images() {
    local platform="$1"
    shift

    platform_cd "$platform" || return 1

    if [[ $# -eq 0 ]]; then
        docker compose pull 2>&1
    else
        docker compose pull "$@" 2>&1
    fi
}

###############################################################################
# List compose services
###############################################################################

platform_services() {

    docker compose config --services
}

###############################################################################
# Get configured image reference for a service
###############################################################################

platform_service_image_old() {
    local service="$1"
    local image

    image="$(
        docker compose config --format json |
        jq -r --arg service "$service" \
            '.services[$service].image // empty'
    )"

    [[ -n "$image" ]] || return 1

    printf '%s\n' "$image"
}

platform_service_image() {
    local platform="$1"
    local service="$2"

    (
        platform_cd "$platform"

        docker compose config --format json |
            jq -r --arg service "$service" \
            '.services[$service].image // empty'
    )
}

###############################################################################
# Get local image ID for a service
###############################################################################

platform_service_image_id() {
    local platform="$1"
    local service="$2"
    local image

    image="$(platform_service_image "$platform" "$service")" || return 1

    docker image inspect "$image" \
        --format '{{.Id}}' 2>/dev/null
}

###############################################################################
# Snapshot current local image IDs
###############################################################################

platform_snapshot_images() {
    local platform="$1"
    shift

    local service

    # No services supplied = all services in the platform
    if [[ $# -eq 0 ]]; then

        while IFS= read -r service
        do
            [[ -z "$service" ]] && continue

            printf "%s=%s\n" \
                "$service" \
                "$(platform_service_image_id "$platform" "$service")"

        done < <(platform_services)

    else

        # One or more specific services supplied
        for service in "$@"
        do
            [[ -z "$service" ]] && continue

            printf "%s=%s\n" \
                "$service" \
                "$(platform_service_image_id "$platform" "$service")"
        done

    fi
}


###############################################################################
# Compare image snapshots
#
# Arguments:
#   $1 - snapshot before pull
#   $2 - snapshot after pull
#
# Outputs:
#   service names whose image IDs changed
###############################################################################

platform_changed_services() {
    local before="$1"
    local after="$2"
    shift 2

    local service
    local before_image
    local after_image

    for service in "$@"
    do
        before_image="$(awk -F= -v s="$service" '$1 == s {print $2}' <<< "$before")"
        after_image="$(awk -F= -v s="$service" '$1 == s {print $2}' <<< "$after")"

        if [[ "$before_image" != "$after_image" ]]; then
            printf '%s\n' "$service"
        fi
    done
}

###############################################################################
# Compare image snapshots and return unchanged services
###############################################################################

platform_unchanged_services() {
    local before="$1"
    local after="$2"
    shift 2

    local service
    local before_image
    local after_image

    for service in "$@"
    do
        before_image="$(awk -F= -v s="$service" '$1 == s {print $2}' <<< "$before")"
        after_image="$(awk -F= -v s="$service" '$1 == s {print $2}' <<< "$after")"

        if [[ "$before_image" == "$after_image" ]]; then
            printf '%s\n' "$service"
        fi
    done
}

###############################################################
# Pull platform images and capture output
###############################################################

platform_pull_images_capture() {

    local platform="$1"

    platform_cd "$platform" || return 1

    docker compose pull 2>&1
}

############################################################
# Pull service image
############################################################

platform_pull_service() {

    local platform="$1"
    local service="$2"

    (
        platform_cd "$platform"

        docker compose pull "$service"
    )
}

############################################################
# Update platform
############################################################

platform_update_all() {

    local platform="$1"

    (
        platform_cd "$platform"

        docker compose up -d
    )
}

############################################################
# Update service
############################################################

platform_update_service() {

    local platform="$1"
    local service="$2"

    (
        platform_cd "$platform"

        docker compose up -d "$service"
    )
}

###############################################################################
# Remote image digest
###############################################################################

remote_image_digest() {
    local image="$1"

    [[ -n "$image" ]] || return 1

    docker buildx imagetools inspect "$image" \
        --format '{{.Manifest.Digest}}' 2>/dev/null
}

###############################################################################
# Local image digest
###############################################################################

local_image_digest() {
    local image="$1"

    [[ -n "$image" ]] || return 1

    docker image inspect "$image" \
        --format '{{index .RepoDigests 0}}' 2>/dev/null |
        sed 's/.*@//'
}

############################################################
# Check if service exists
############################################################

platform_has_service() {

    local platform="$1"
    local service="$2"

    docker compose \
        -f "$(get_compose_file "$platform")" \
        config --services \
    | grep -Fxq -- "$service"
}

################################################################################
# Wait for service health
################################################################################

platform_wait_for_health() {
    local platform="$1"
    shift

    local timeout="${1:-60}"
    shift || true

    local interval=2
    local elapsed=0
    local service
    local container_ids
    local container_id
    local state
    local health

    platform_cd "$platform" || return 1

    while (( elapsed < timeout ))
    do
        local all_healthy=true

        for service in "$@"
        do
            container_ids="$(docker compose ps -q "$service")"

            if [[ -z "$container_ids" ]]; then
                all_healthy=false
                continue
            fi

            while read -r container_id
            do
                [[ -z "$container_id" ]] && continue

                state="$(docker inspect \
                    -f '{{.State.Status}}' \
                    "$container_id" 2>/dev/null)"

                if [[ "$state" != "running" ]]; then
                    all_healthy=false
                    continue
                fi

                health="$(docker inspect \
                    -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
                    "$container_id" 2>/dev/null)"

                case "$health" in
                    healthy|no-healthcheck)
                        ;;
                    starting|unhealthy|*)
                        all_healthy=false
                        ;;
                esac

            done <<< "$container_ids"
        done

        if [[ "$all_healthy" == true ]]; then
            return 0
        fi

        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    return 1
}

platform_service_health_status() {
    local platform="$1"
    local service="$2"

    platform_cd "$platform" || return 1

    local container_id
    local state
    local health

    container_id="$(docker compose ps -q "$service" | head -n 1)"

    if [[ -z "$container_id" ]]; then
        printf '%s\n' "missing"
        return 1
    fi

    state="$(docker inspect \
        -f '{{.State.Status}}' \
        "$container_id" 2>/dev/null)"

    if [[ "$state" != "running" ]]; then
        printf '%s\n' "$state"
        return 1
    fi

    health="$(docker inspect \
        -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
        "$container_id" 2>/dev/null)"

    printf '%s\n' "$health"
}
