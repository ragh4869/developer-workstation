#!/usr/bin/env bash

# ============================================================
# Workstation - Doctor Library
# Generic diagnostic functions used across platforms
# ============================================================


# ============================================================
# Check Docker daemon
# ============================================================

doctor_check_docker() {

    if ! command -v docker >/dev/null 2>&1; then
        echo "FAIL|Docker is not installed"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        echo "FAIL|Docker daemon is not running"
        return 1
    fi

    echo "PASS|Docker daemon available"
    return 0
}


# ============================================================
# Check platform
# ============================================================

doctor_check_platform() {

    local platform="$1"

    if ! platform_exists "$platform"; then
        echo "FAIL|Unknown platform: $platform"
        return 1
    fi

    local platform_dir
    platform_dir="$(get_platform_dir "$platform")"

    if [[ ! -d "$platform_dir" ]]; then
        echo "FAIL|Platform directory not found: $platform_dir"
        return 1
    fi

    echo "PASS|Platform directory exists"
    return 0
}


# ============================================================
# Check Compose file
# ============================================================

doctor_check_compose() {

    local platform_dir="$1"

    local compose_file
    compose_file="$(health_compose_file "$platform_dir")"

    if [[ -z "$compose_file" || ! -f "$compose_file" ]]; then
        echo "FAIL|Compose file not found"
        return 1
    fi

    echo "PASS|$(basename "$compose_file") found"
    return 0
}

# ============================================================
# Check services
# ============================================================

doctor_check_services() {

    local compose_file="$1"

    local services
    mapfile -t services < <(
        health_list_services "$compose_file"
    )

    if [[ "${#services[@]}" -eq 0 ]]; then
        echo "FAIL|No services defined"
        return 1
    fi

    echo "PASS|${#services[@]} services defined"

    return 0
}


# ============================================================
# Check running containers
# ============================================================

doctor_check_running() {

    local compose_file="$1"

    local total=0
    local running=0

    local services
    mapfile -t services < <(
        health_list_services "$compose_file"
    )

    for service in "${services[@]}"; do

        ((total++))

        local container
        container="$(get_service_container "$compose_file" "$service")"

        if [[ -n "$container" ]] &&
           [[ "$(get_container_state "$container")" == "running" ]]; then
            ((running++))
        fi

    done

    if (( running == total )); then
        echo "PASS|$running/$total services running"
        return 0
    fi

    echo "FAIL|$running/$total services running"
    return 1
}


# ============================================================
# Check healthchecks
# ============================================================

doctor_check_healthchecks() {

    local compose_file="$1"

    local services
    mapfile -t services < <(
        health_list_services "$compose_file"
    )

    local total=0
    local configured=0

    for service in "${services[@]}"; do

        ((total++))

        local container
        container="$(get_service_container "$compose_file" "$service")"

        [[ -z "$container" ]] && continue

        if has_container_healthcheck "$container"; then
            ((configured++))
        fi

    done

    if (( configured == total )); then
        echo "PASS|$configured/$total services have healthchecks"
        return 0
    fi

    echo "WARN|$configured/$total services have healthchecks"
    return 2
}


# ============================================================
# Check service health
# ============================================================

doctor_check_health() {

    local compose_file="$1"

    local services
    mapfile -t services < <(
        health_list_services "$compose_file"
    )

    local total=0
    local healthy=0

    for service in "${services[@]}"; do

        ((total++))

        health_check_service "$compose_file" "$service"

        if [[ "$HEALTH_RESULT" == "Healthy" ]]; then
            ((healthy++))
        fi

    done

    if (( healthy == total )); then
        echo "PASS|$healthy/$total services healthy"
        return 0
    fi

    echo "FAIL|$healthy/$total services healthy"
    return 1
}


# ============================================================
# Main platform doctor
# ============================================================

doctor_platform() {

    local platform="$1"

    local failures=0
    local warnings=0

    printf '%s\n' '------------------------------------------------------------'

    printf '%-28s %-8s %s\n' \
        "Check" \
        "Status" \
        "Details"

    printf '%s\n' '------------------------------------------------------------'


    # --------------------------------------------------------
    # Docker
    # --------------------------------------------------------

    local result
    local status
    local details

    result="$(doctor_check_docker)"
    status="${result%%|*}"
    details="${result#*|}"

    printf '%-28s %-8s %s\n' \
        "Docker daemon" \
        "$status" \
        "$details"

    [[ "$status" == "FAIL" ]] && ((failures++))


    # --------------------------------------------------------
    # Platform
    # --------------------------------------------------------

    result="$(doctor_check_platform "$platform")"
    status="${result%%|*}"
    details="${result#*|}"

    printf '%-28s %-8s %s\n' \
        "Platform" \
        "$status" \
        "$details"

    if [[ "$status" == "FAIL" ]]; then
        ((failures++))
        printf '\n'
        printf '✗ Platform doctor failed.\n'
        return 1
    fi


    local platform_dir
    platform_dir="$(get_platform_dir "$platform")"


    # --------------------------------------------------------
    # Compose
    # --------------------------------------------------------

    result="$(doctor_check_compose "$platform_dir")"
    status="${result%%|*}"
    details="${result#*|}"

    printf '%-28s %-8s %s\n' \
        "Compose" \
        "$status" \
        "$details"

    [[ "$status" == "FAIL" ]] && ((failures++))


    # --------------------------------------------------------
    # Compose configuration
    # --------------------------------------------------------

    local compose_file="$platform_dir/compose.yaml"
    local compose_config_cmd=()

    if [[ -f "$platform_dir/.env" ]]; then
        compose_config_cmd=(
            docker compose
            --env-file "$platform_dir/.env"
            -f "$compose_file"
            config
        )
    else
        compose_config_cmd=(
            docker compose
            -f "$compose_file"
            config
        )
    fi

    if [[ $compose_status -ne 0 ]]; then

        printf '%-28s %-8s %s\n' \
            "Compose configuration" \
            "FAIL" \
            "configuration is invalid"

        ((failures++))

    else

        printf '%-28s %-8s %s\n' \
            "Compose configuration" \
            "PASS" \
            "configuration is valid"

    fi


    # --------------------------------------------------------
    # Services
    # --------------------------------------------------------

    local compose_file
    compose_file="$(health_compose_file "$platform_dir")"

    if [[ -n "$compose_file" && -f "$compose_file" ]]; then

        result="$(doctor_check_services "$compose_file")"
        status="${result%%|*}"
        details="${result#*|}"

        printf '%-28s %-8s %s\n' \
            "Services" \
            "$status" \
            "$details"

        [[ "$status" == "FAIL" ]] && ((failures++))


        # ----------------------------------------------------
        # Running
        # ----------------------------------------------------

        result="$(doctor_check_running "$compose_file")"
        status="${result%%|*}"
        details="${result#*|}"

        printf '%-28s %-8s %s\n' \
            "Containers running" \
            "$status" \
            "$details"

        [[ "$status" == "FAIL" ]] && ((failures++))


        # ----------------------------------------------------
        # Healthchecks
        # ----------------------------------------------------

        result="$(doctor_check_healthchecks "$compose_file")"
        status="${result%%|*}"
        details="${result#*|}"

        printf '%-28s %-8s %s\n' \
            "Healthchecks" \
            "$status" \
            "$details"

        if [[ "$status" == "FAIL" ]]; then
            ((failures++))
        elif [[ "$status" == "WARN" ]]; then
            ((warnings++))
        fi


        # ----------------------------------------------------
        # Health
        # ----------------------------------------------------

        result="$(doctor_check_health "$compose_file")"
        status="${result%%|*}"
        details="${result#*|}"

        printf '%-28s %-8s %s\n' \
            "Service health" \
            "$status" \
            "$details"

        [[ "$status" == "FAIL" ]] && ((failures++))

    fi


    # --------------------------------------------------------
    # Final result
    # --------------------------------------------------------

    printf '%s\n' '------------------------------------------------------------'
    printf '\n'

    if (( failures > 0 )); then

        printf '✘ Platform %s requires attention.\n' "$platform"
        printf '\n'
        printf 'Failures : %s\n' "$failures"
        printf 'Warnings : %s\n' "$warnings"

        return 1

    elif (( warnings > 0 )); then

        printf '⚠ Platform %s has warnings.\n' "$platform"
        printf '\n'
        printf 'Failures : %s\n' "$failures"
        printf 'Warnings : %s\n' "$warnings"

        return 0

    else

        printf '✔  No problems detected.\n'
        printf '✔  Platform %s is ready.\n' "$platform"

        return 0

    fi
}
