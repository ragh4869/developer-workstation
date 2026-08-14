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


###############################################################################
# Show services for a single platform
###############################################################################

show_platform_services() {

    local PLATFORM="$1"
    shift

    prepare_platform "$PLATFORM"

    print_header "Platform Services: $PLATFORM"

    echo "Platform : $PLATFORM"

    ############################################################################
    # Resolve configured services
    ############################################################################

    mapfile -t ALL_SERVICES < <(
        platform_cd "$PLATFORM" || exit 1
        platform_services
    )

    if [[ ${#ALL_SERVICES[@]} -eq 0 ]]; then
        print_warning "No services found for platform: $PLATFORM"
        return 0
    fi

    ############################################################################
    # Resolve requested services
    ############################################################################

    if [[ $# -eq 0 ]]; then

        TARGET_SERVICES=("${ALL_SERVICES[@]}")

    else

        TARGET_SERVICES=()

        for REQUESTED_SERVICE in "$@"; do

            if ! platform_has_service "$PLATFORM" "$REQUESTED_SERVICE"; then
                print_error "Unknown service: $REQUESTED_SERVICE"
                echo

                print_info "Available Services"

                for SERVICE in "${ALL_SERVICES[@]}"; do
                    echo "  $SERVICE"
                done

                return 1
            fi

            TARGET_SERVICES+=("$REQUESTED_SERVICE")

        done

    fi

    ############################################################################
    # Display selected services
    ############################################################################

    if [[ $# -eq 0 ]]; then
        echo "Services : All"
    else
        SERVICE_DISPLAY="$(IFS=', '; echo "${TARGET_SERVICES[*]}")"
        echo "Services : $SERVICE_DISPLAY"
    fi

    echo

    ############################################################################
    # Table header
    ############################################################################

    printf "%-20s %-40s %-14s %-20s %-15s\n" \
        "Service" \
        "Image" \
        "State" \
        "Health" \
        "Ports"

    printf "%-20s %-40s %-14s %-20s %-15s\n" \
        "--------------------" \
        "----------------------------------------" \
        "--------------" \
        "--------------------" \
        "---------------"

    ############################################################################
    # Service information
    ############################################################################

    TOTAL_COUNT=0
    RUNNING_COUNT=0
    HEALTHY_COUNT=0
    STOPPED_COUNT=0
    UNHEALTHY_COUNT=0

    for SERVICE in "${TARGET_SERVICES[@]}"; do

        [[ -n "$SERVICE" ]] || continue

        TOTAL_COUNT=$((TOTAL_COUNT + 1))

        IMAGE="$(platform_service_image "$PLATFORM" "$SERVICE")"

        STATE="$(platform_service_state "$PLATFORM" "$SERVICE")"

        HEALTH="$(platform_service_health "$PLATFORM" "$SERVICE")"

        PORTS="$(platform_service_ports "$PLATFORM" "$SERVICE")"

        [[ -n "$STATE" ]] || STATE="Not Created"

        [[ -n "$HEALTH" ]] || HEALTH="No healthcheck"

        [[ -n "$PORTS" ]] || PORTS="-"

        case "$STATE" in

            running)
                DISPLAY_STATE="Running"
                RUNNING_COUNT=$((RUNNING_COUNT + 1))
                ;;

            exited)
                DISPLAY_STATE="Exited"
                STOPPED_COUNT=$((STOPPED_COUNT + 1))
                ;;

            created)
                DISPLAY_STATE="Created"
                STOPPED_COUNT=$((STOPPED_COUNT + 1))
                ;;

            restarting)
                DISPLAY_STATE="Restarting"
                ;;

            *)
                DISPLAY_STATE="$STATE"
                ;;

        esac

        case "$HEALTH" in

            healthy)
                DISPLAY_HEALTH="Healthy"
                HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
                ;;

            unhealthy)
                DISPLAY_HEALTH="Unhealthy"
                UNHEALTHY_COUNT=$((UNHEALTHY_COUNT + 1))
                ;;

            starting)
                DISPLAY_HEALTH="Starting"
                ;;

            *)
                DISPLAY_HEALTH="No healthcheck"
                ;;

        esac

        printf "%-20s %-40s %-14s %-20s %-15s\n" \
            "$SERVICE" \
            "$IMAGE" \
            "$DISPLAY_STATE" \
            "$DISPLAY_HEALTH" \
            "$PORTS"

    done

    ############################################################################
    # Summary
    ############################################################################

    echo

    printf "%s\n" \
        "--------------------------------------------------------------------------------"

    echo

    print_info "$TOTAL_COUNT services configured"
    print_info "$RUNNING_COUNT running"
    print_info "$HEALTHY_COUNT healthy"

    if [[ $STOPPED_COUNT -gt 0 ]]; then
        print_warning "$STOPPED_COUNT stopped"
    fi

    if [[ $UNHEALTHY_COUNT -gt 0 ]]; then
        print_error "$UNHEALTHY_COUNT unhealthy"
    fi

    echo
}
