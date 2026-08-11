#!/usr/bin/env bash

############################################################
# Logs Library
############################################################

logs_services() {

    local PLATFORM="$1"

    (
        platform_cd "$PLATFORM"

        docker compose config --services
    )
}

############################################################

logs_service_exists() {

    local PLATFORM="$1"
    local SERVICE="$2"

    logs_services "$PLATFORM" | grep -Fxq "$SERVICE"

}

############################################################

logs_show() {

    local PLATFORM="$1"
    local SERVICE="$2"
    local TAIL="$3"
    local SINCE="$4"
    local FOLLOW="$5"

    (
        platform_cd "$PLATFORM"

        local ARGS=()

        [[ -n "$TAIL" ]] &&
            ARGS+=(--tail "$TAIL")

        [[ -n "$SINCE" ]] &&
            ARGS+=(--since "$SINCE")

        [[ "$FOLLOW" == true ]] &&
            ARGS+=(-f)

        if [[ -n "$SERVICE" ]]
        then

            if ! logs_service_exists "$PLATFORM" "$SERVICE"
            then

                print_error "Unknown service: $SERVICE"

                echo

                print_info "Available Services"

                logs_print_services "$PLATFORM"

                return 1

            fi

            docker compose logs "${ARGS[@]}" "$SERVICE"

        else

            docker compose logs "${ARGS[@]}"

        fi
    )
}

############################################################

logs_print_services() {

    local PLATFORM="$1"

    local COUNT=1

    while read -r SERVICE
    do

        printf " %2d) %s\n" "$COUNT" "$SERVICE"

        ((COUNT++))

    done < <(logs_services "$PLATFORM")

}

############################################################

resolve_since() {

    local INPUT="$*"

    case "${INPUT,,}" in
        today)
            date -d "today 00:00" --iso-8601=seconds
            ;;

        yesterday)
            date -d "yesterday 00:00" --iso-8601=seconds
            ;;

        last-week)
            date -d "7 days ago" --iso-8601=seconds
            ;;

        last-month)
            date -d "1 month ago" --iso-8601=seconds
            ;;

        last-year)
            date -d "1 year ago" --iso-8601=seconds
            ;;

        *)
            # Convert "2 days" -> "2 days ago"
            if [[ "$INPUT" =~ ^[0-9]+[[:space:]]+[A-Za-z]+$ ]]; then
                date -d "$INPUT ago" --iso-8601=seconds

            elif date -d "$INPUT" >/dev/null 2>&1; then
                date -d "$INPUT" --iso-8601=seconds

            else
                # Docker-native durations (2h, 30m, 15s, RFC3339, etc.)
                echo "$INPUT"
            fi
            ;;

    esac
}
