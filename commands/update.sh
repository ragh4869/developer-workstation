#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

set -e

PLATFORM="$1"
shift

SERVICE=""
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
            if [[ -z "$SERVICE" ]]; then
                SERVICE="$1"
            else
                print_error "Unexpected argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

prepare_platform "$PLATFORM"

print_header "Platform Update"

echo
echo "Platform : $PLATFORM"

if [[ -n "$SERVICE" ]]; then
    echo "Service  : $SERVICE"
else
    echo "Service  : All"
fi

echo

if [[ -n "$SERVICE" ]]; then

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
fi

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

###############################################################################
# Snapshot images BEFORE pull
###############################################################################

BEFORE_IMAGES="$(
    platform_cd "$PLATFORM" || exit 1
    platform_snapshot_images
)"

###############################################################################
# Pull latest images
###############################################################################

PULL_OUTPUT="$(platform_pull_images_capture "$PLATFORM")" || {
    print_error "Failed to pull platform images."
    return 1
}

###############################################################################
# Snapshot images AFTER pull
###############################################################################

AFTER_IMAGES="$(
    platform_cd "$PLATFORM" || exit 1
    platform_snapshot_images
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
    platform_changed_services "$BEFORE_IMAGES" "$AFTER_IMAGES"
)

while IFS= read -r svc
do
    [[ -n "$svc" ]] && UNCHANGED_SERVICES+=("$svc")
done < <(
    platform_cd "$PLATFORM" || exit 1
    platform_unchanged_services "$BEFORE_IMAGES" "$AFTER_IMAGES"
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

print_info "Updating changed containers..."

if [[ -n "$SERVICE" ]]; then

    # Specific service requested
    SERVICE_CHANGED=false

    for svc in "${UPDATED_SERVICES[@]}"
    do
        if [[ "$svc" == "$SERVICE" ]]; then
            SERVICE_CHANGED=true
            break
        fi
    done

    if [[ "$SERVICE_CHANGED" == true ]]; then
        platform_update_service "$PLATFORM" "$SERVICE"
    else
        print_info "$SERVICE is already up-to-date."
    fi

else

    # No specific service: update only changed services
    if [[ ${#UPDATED_SERVICES[@]} -eq 0 ]]; then

        print_info "All services are already up-to-date."

    else

        for svc in "${UPDATED_SERVICES[@]}"
        do
            platform_update_service "$PLATFORM" "$svc"
        done

    fi

fi

echo

print_info "Running health check..."

platform_health "$PLATFORM"

echo
echo
print_success "Update completed successfully."
