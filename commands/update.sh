#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

set -e

PLATFORM="$1"
shift

SERVICE=()
AUTO_BACKUP=true

while [[ $# -gt 0 ]]; do
    case "$1" in

        --no-backup)
            AUTO_BACKUP=false
            shift
            ;;

        -*)
            print_error "Unknown option: $1"
            exit 1
            ;;

        *)
            SERVICES+=("$1")
            shift
            ;;
    esac
done

prepare_platform "$PLATFORM"

print_header "Platform Update"

echo
echo "Platform : $PLATFORM"

if [[ ${#SERVICES[@]} -gt 0 ]]; then
    SERVICE_DISPLAY="$(IFS=', '; echo "${SERVICES[*]}")"
    echo "Service  : $SERVICE_DISPLAY"
else
    echo "Service  : All"
fi

echo

# Validate requested services
if [[ ${#SERVICES[@]} -gt 0 ]]; then

    for SERVICE in "${SERVICES[@]}"; do

        if ! platform_has_service "$PLATFORM" "$SERVICE"; then

            print_error "Unknown service: $SERVICE"
            echo

            print_info "Available Services"

            docker compose \
                -f "$(get_compose_file "$PLATFORM")" \
                config --services \
                | nl -w1 -s") "

            exit 1
        fi

    done

fi

# Automatic backup
if $AUTO_BACKUP; then

    print_info "Creating backup before update..."

    BACKUP_NAME="$("$SCRIPTS_DIR/backup-platform.sh" "$PLATFORM")"

    print_success "Backup completed."

    if [[ -n "$BACKUP_NAME" ]]; then
        echo "Backup : $(basename "$BACKUP_NAME")"
    fi

    echo

fi

read -rp "Update images? (Y/n): " CONFIRM

[[ "$CONFIRM" =~ ^[Nn]$ ]] && exit 0

echo

print_info "Checking for image updates..."

# Resolve the actual services to process
if [[ ${#SERVICES[@]} -eq 0 ]]; then
    # No service specified = ALL services
    mapfile -t TARGET_SERVICES < <(
        platform_cd "$PLATFORM" || exit 1
        platform_services
    )
else
    # Specific services requested
    TARGET_SERVICES=("${SERVICES[@]}")
fi

###############################################################################
# Snapshot images BEFORE pull
###############################################################################

BEFORE_IMAGES="$(
    platform_cd "$PLATFORM" || exit 1
    platform_snapshot_images "${TARGET_SERVICES[@]}"
)"

###############################################################################
# Pull latest images
###############################################################################

PULL_OUTPUT="$(platform_pull_images_capture "$PLATFORM" "${TARGET_SERVICES[@]}")" || {
    print_error "Failed to pull platform images."
    return 1
}

###############################################################################
# Snapshot images AFTER pull
###############################################################################

AFTER_IMAGES="$(
    platform_cd "$PLATFORM" || exit 1
    platform_snapshot_images "${TARGET_SERVICES[@]}"
)"

###############################################################################
# Detect changed / unchanged services
###############################################################################

UPDATED_SERVICES=()
UNCHANGED_SERVICES=()

while IFS= read -r svc
do
    [[ -n "$svc" ]] && UPDATED_SERVICES+=("$svc")
done < <(
    platform_cd "$PLATFORM" || exit 1
    platform_changed_services \
        "$BEFORE_IMAGES" \
        "$AFTER_IMAGES" \
        "${TARGET_SERVICES[@]}"
)

while IFS= read -r svc
do
    [[ -n "$svc" ]] && UNCHANGED_SERVICES+=("$svc")
done < <(
    platform_cd "$PLATFORM" || exit 1
    platform_unchanged_services \
        "$BEFORE_IMAGES" \
        "$AFTER_IMAGES" \
        "${TARGET_SERVICES[@]}"
)

for svc in "${UPDATED_SERVICES[@]}"
do
    printf " "
    printf "✔ %-18s Updated\n" "$svc"
done

for svc in "${UNCHANGED_SERVICES[@]}"
do
    printf " "
    printf "ℹ  %-18s Already up-to-date\n" "$svc"
done

echo

###############################################################################
# Update changed services
###############################################################################

if [[ ${#UPDATED_SERVICES[@]} -eq 0 ]]; then

    if [[ ${#SERVICES[@]} -gt 0 ]]; then
        print_info "All requested services are already up-to-date."
    else
        print_info "All services are already up-to-date."
    fi

else

    print_info "Updating changed containers..."

    for svc in "${UPDATED_SERVICES[@]}"
    do
        platform_update_service "$PLATFORM" "$svc"
    done

fi

echo

if [[ ${#UPDATED_SERVICES[@]} -gt 0 ]]; then
    print_info "Waiting for service health..."

    if ! platform_wait_for_health \
        "$PLATFORM" \
        60 \
        "${UPDATED_SERVICES[@]}"
    then
        print_error "One or more updated services failed to become healthy."

        for svc in "${UPDATED_SERVICES[@]}"
        do
            status="$(platform_service_health_status "$PLATFORM" "$svc")"

            printf "  %-18s %s\n" "$svc" "$status"
        done

        return 1
    fi

    for svc in "${UPDATED_SERVICES[@]}"
    do
        status="$(platform_service_health_status "$PLATFORM" "$svc")"

        case "$status" in
            healthy|no-healthcheck)
                printf " "
                print_success "✓"
                printf " %-18s %s\n" "$svc" "Healthy"
                ;;
            *)
                printf " "
                print_error "✗"
                printf " %-18s %s\n" "$svc" "$status"
                ;;
        esac
    done
else
    print_info "No changed services require health verification."
fi

echo

print_info "Running health check..."

platform_health "$PLATFORM"

echo
echo
print_success "Update completed successfully."
