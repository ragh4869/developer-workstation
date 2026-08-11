#!/usr/bin/env bash

###############################################################################
# Pull latest images
###############################################################################

platform_pull_images() {

    local platform="$1"

    platform_cd "$platform" || return 1

    docker compose pull
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

platform_service_image() {
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

###############################################################################
# Get local image ID for a service
###############################################################################

platform_service_image_id() {
    local service="$1"
    local image

    image="$(platform_service_image "$service")" || return 1

    docker image inspect "$image" \
        --format '{{.Id}}' 2>/dev/null
}

###############################################################################
# Snapshot current local image IDs
###############################################################################

platform_snapshot_images() {
    local service
    local image_id

    while IFS= read -r service
    do
        [[ -n "$service" ]] || continue

        image_id="$(platform_service_image_id "$service" 2>/dev/null || true)"

        printf '%s=%s\n' \
            "$service" \
            "$image_id"

    done < <(platform_services)
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

    declare -A before_images
    declare -A after_images

    local service
    local image_id

    while IFS='=' read -r service image_id
    do
        [[ -n "$service" ]] || continue
        before_images["$service"]="$image_id"
    done <<< "$before"

    while IFS='=' read -r service image_id
    do
        [[ -n "$service" ]] || continue
        after_images["$service"]="$image_id"
    done <<< "$after"

    while IFS= read -r service
    do
        [[ -n "$service" ]] || continue

        if [[ "${before_images[$service]:-}" != "${after_images[$service]:-}" ]]
        then
            printf '%s\n' "$service"
        fi

    done < <(platform_services)
}

###############################################################################
# Compare image snapshots and return unchanged services
###############################################################################

platform_unchanged_services() {
    local before="$1"
    local after="$2"

    declare -A before_images
    declare -A after_images

    local service
    local image_id

    while IFS='=' read -r service image_id
    do
        [[ -n "$service" ]] || continue
        before_images["$service"]="$image_id"
    done <<< "$before"

    while IFS='=' read -r service image_id
    do
        [[ -n "$service" ]] || continue
        after_images["$service"]="$image_id"
    done <<< "$after"

    while IFS= read -r service
    do
        [[ -n "$service" ]] || continue

        if [[ "${before_images[$service]:-}" == "${after_images[$service]:-}" ]]
        then
            printf '%s\n' "$service"
        fi

    done < <(platform_services)
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

###############################################################
# Parse updated services from docker compose pull
###############################################################

get_updated_services() {

    local pull_output="$1"

    while IFS= read -r line
    do
        printf 'LINE=<%q>\n' "$line" >&2

        if [[ "$line" =~ Image[[:space:]]+(.+)[[:space:]]+(Pulled|Downloaded|Updated)$ ]]; then
            echo "MATCH=[${BASH_REMATCH[1]}]" >&2
            echo "${BASH_REMATCH[1]}"
        fi

    done <<< "$pull_output"
}

###############################################################
# Parse unchanged services
###############################################################

get_unchanged_services() {

    local pull_output="$1"
    local image

    while IFS= read -r line
    do
        [[ "$line" != Image* ]] && continue

        image=$(awk '{print $2}' <<< "$line")

        if [[ "$line" == *"Already up to date"* ]]; then
            echo "$image"
        fi

    done <<< "$pull_output"
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
