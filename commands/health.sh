#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

set -e

PLATFORM="$1"
shift || true

if [[ -z "$PLATFORM" ]]; then
    print_error "Platform is required."
    echo
    echo "Usage:"
    echo "  platform health <platform> [service ...]"
    exit 1
fi

prepare_platform "$PLATFORM"

print_header "Platform Health"

echo "Platform : $PLATFORM"

###############################################################################
# Resolve configured services
###############################################################################

mapfile -t ALL_SERVICES < <(
    platform_cd "$PLATFORM" || exit 1
    platform_services
)

if [[ ${#ALL_SERVICES[@]} -eq 0 ]]; then
    print_warning "No services found for platform: $PLATFORM"
    exit 0
fi

###############################################################################
# Resolve requested services
###############################################################################

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

            exit 1
        fi

        TARGET_SERVICES+=("$REQUESTED_SERVICE")

    done

fi

###############################################################################
# Display selected services
###############################################################################

if [[ $# -eq 0 ]]; then
    echo "Services : All"
else
    SERVICE_DISPLAY="$(IFS=', '; echo "${TARGET_SERVICES[*]}")"
    echo "Services : $SERVICE_DISPLAY"
fi

echo

###############################################################################
# Health table
###############################################################################

printf "%-20s %-16s %-22s %-15s\n" \
    "Service" \
    "State" \
    "Health" \
    "Result"

printf "%-20s %-16s %-22s %-15s\n" \
    "--------------------" \
    "----------------" \
    "----------------------" \
    "---------------"

###############################################################################
# Counters
###############################################################################

TOTAL_COUNT=0
HEALTHY_COUNT=0
NO_HEALTHCHECK_COUNT=0
UNHEALTHY_COUNT=0
STOPPED_COUNT=0
RESTARTING_COUNT=0

###############################################################################
# Inspect services
###############################################################################

for SERVICE in "${TARGET_SERVICES[@]}"; do

    [[ -n "$SERVICE" ]] || continue

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    STATE="$(platform_service_state "$PLATFORM" "$SERVICE")"
    HEALTH="$(platform_service_health "$PLATFORM" "$SERVICE")"

    [[ -n "$STATE" ]] || STATE="not created"

    [[ -n "$HEALTH" ]] || HEALTH=""

    case "$STATE" in

        running)

            DISPLAY_STATE="Running"

            case "$HEALTH" in

                healthy)
                    DISPLAY_HEALTH="Healthy"
                    RESULT="Healthy"
                    HEALTHY_COUNT=$((HEALTHY_COUNT + 1))
                    ;;

                unhealthy)
                    DISPLAY_HEALTH="Unhealthy"
                    RESULT="Unhealthy"
                    UNHEALTHY_COUNT=$((UNHEALTHY_COUNT + 1))
                    ;;

                starting)
                    DISPLAY_HEALTH="Starting"
                    RESULT="Starting"
                    ;;

                *)
                    DISPLAY_HEALTH="No healthcheck"
                    RESULT="Needs check"
                    NO_HEALTHCHECK_COUNT=$((NO_HEALTHCHECK_COUNT + 1))
                    ;;

            esac
            ;;

        exited)
            DISPLAY_STATE="Exited"
            DISPLAY_HEALTH="Unavailable"
            RESULT="Stopped"
            STOPPED_COUNT=$((STOPPED_COUNT + 1))
            ;;

        restarting)
            DISPLAY_STATE="Restarting"
            DISPLAY_HEALTH="Unavailable"
            RESULT="Restarting"
            RESTARTING_COUNT=$((RESTARTING_COUNT + 1))
            ;;

        created)
            DISPLAY_STATE="Created"
            DISPLAY_HEALTH="Unavailable"
            RESULT="Not running"
            STOPPED_COUNT=$((STOPPED_COUNT + 1))
            ;;

        *)
            DISPLAY_STATE="$STATE"
            DISPLAY_HEALTH="Unavailable"
            RESULT="Unavailable"
            STOPPED_COUNT=$((STOPPED_COUNT + 1))
            ;;

    esac

    printf "%-20s %-16s %-22s %-15s\n" \
        "$SERVICE" \
        "$DISPLAY_STATE" \
        "$DISPLAY_HEALTH" \
        "$RESULT"

done

###############################################################################
# Summary
###############################################################################

echo
printf "%s\n" \
    "--------------------------------------------------------------------------------"

echo

print_info "$TOTAL_COUNT services checked"

if [[ $HEALTHY_COUNT -gt 0 ]]; then
    print_success "$HEALTHY_COUNT services healthy"
fi

if [[ $NO_HEALTHCHECK_COUNT -gt 0 ]]; then
    print_warning "$NO_HEALTHCHECK_COUNT services have no healthcheck"
fi

if [[ $UNHEALTHY_COUNT -gt 0 ]]; then
    print_error "$UNHEALTHY_COUNT services unhealthy"
fi

if [[ $STOPPED_COUNT -gt 0 ]]; then
    print_error "$STOPPED_COUNT services stopped or not running"
fi

if [[ $RESTARTING_COUNT -gt 0 ]]; then
    print_warning "$RESTARTING_COUNT services restarting"
fi

echo

###############################################################################
# Overall result
###############################################################################

if [[ $UNHEALTHY_COUNT -gt 0 ||
      $STOPPED_COUNT -gt 0 ||
      $RESTARTING_COUNT -gt 0 ]]; then

    print_error "Platform health check failed."
    exit 1

elif [[ $NO_HEALTHCHECK_COUNT -gt 0 ]]; then

    print_warning "Platform is running, but some services require additional health verification."
    exit 0

else

    print_success "All checked services are healthy."
    exit 0

fi
