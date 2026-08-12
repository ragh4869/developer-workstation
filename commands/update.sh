#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

set -e

PLATFORM="$1"
shift

SERVICE=()
AUTO_BACKUP=true
FORCE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in

        --force)
            FORCE=true
            shift
            ;;

        --dry-run)
            DRY_RUN=true
            shift
            ;;

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

###############################################################################
# Dry run
###############################################################################

if [[ "$DRY_RUN" == true ]]; then

    print_header "Dry Run"

    print_info "No changes will be made."
    echo

    print_info "Platform : $PLATFORM"

    if [[ ${#SERVICES[@]} -eq 0 ]]; then
        print_info "Services : All"
    else
        print_info "Services : ${SERVICES[*]}"
    fi

    echo

    print_info "Checking remote image state..."

    UPDATED_SERVICES=()
    UNCHANGED_SERVICES=()
    UNKNOWN_SERVICES=()

    # Resolve the actual services to inspect
    if [[ ${#SERVICES[@]} -eq 0 ]]; then

        mapfile -t TARGET_SERVICES < <(
            platform_cd "$PLATFORM" || exit 1
            platform_services
        )

    else

        TARGET_SERVICES=("${SERVICES[@]}")

    fi

    for SVC in "${TARGET_SERVICES[@]}"; do

        [[ -n "$SVC" ]] || continue

        IMAGE="$(
            platform_cd "$PLATFORM" || exit 1

            docker compose \
                -f "$(get_compose_file "$PLATFORM")" \
                config --format json |
                jq -r --arg svc "$SVC" \
                    '.services[$svc].image // empty'
        )"

        if [[ -z "$IMAGE" ]]; then
            print_warning "$SVC: unable to determine image"
            UNKNOWN_SERVICES+=("$SVC")
            continue
        fi

        LOCAL_DIGEST="$(local_image_digest "$IMAGE" || true)"
        REMOTE_DIGEST="$(remote_image_digest "$IMAGE" || true)"

        if [[ -z "$REMOTE_DIGEST" ]]; then
            print_warning "$SVC: unable to query remote image"
            UNKNOWN_SERVICES+=("$SVC")
            continue
        fi

        if [[ -z "$LOCAL_DIGEST" ]]; then
            print_warning "$SVC: local image digest unavailable"
            UNKNOWN_SERVICES+=("$SVC")
            continue
        fi

        if [[ "$LOCAL_DIGEST" == "$REMOTE_DIGEST" ]]; then
            UNCHANGED_SERVICES+=("$SVC")
        else
            UPDATED_SERVICES+=("$SVC")
        fi

    done

    echo

    ###############################################################################
    # Would update
    ###############################################################################

    if [[ ${#UPDATED_SERVICES[@]} -gt 0 ]]; then

        print_header "Updates Available"

        for SVC in "${UPDATED_SERVICES[@]}"; do
            printf "  "
            printf "✔  %-18s Update available\n" "$SVC"
        done

        echo

    fi

    ###############################################################################
    # Already current
    ###############################################################################

    if [[ ${#UNCHANGED_SERVICES[@]} -gt 0 ]]; then

        print_header "Already Up-to-Date"

        for SVC in "${UNCHANGED_SERVICES[@]}"; do
            printf "  "
            printf "✔  %-18s Already up-to-date\n" "$SVC"
        done

        echo

    fi

    ###############################################################################
    # Unknown
    ###############################################################################

    if [[ ${#UNKNOWN_SERVICES[@]} -gt 0 ]]; then

        print_header "Unable to Determine"

        for SVC in "${UNKNOWN_SERVICES[@]}"; do
            printf "  "
            print_warning "!"
            printf " %-18s Unable to determine remote state\n" "$SVC"
        done

        echo

    fi

    ###############################################################################
    # Summary
    ###############################################################################

    if [[ ${#UPDATED_SERVICES[@]} -gt 0 ]]; then
        print_info "Updates are available for ${#UPDATED_SERVICES[@]} service(s)."
    else
        print_success "All checked services are already up-to-date."
    fi

    echo

    print_success "Dry run completed. No changes were made."
    print_info "No backup was created."
    print_info "No images were pulled."

    exit 0

fi

# Automatic backup
if $AUTO_BACKUP; then

    print_info "Creating backup before update..."

    BACKUP_NAME="$("$SCRIPTS_DIR/backup-platform.sh" "$PLATFORM")"

    BACKUP_PATH="$(latest_backup "$PLATFORM")"

    if [[ -z "$BACKUP_PATH" || ! -d "$BACKUP_PATH" ]]; then
        print_error "Backup completed, but backup path could not be determined."
        exit 1
    else
        print_success "Backup completed."
    fi

    if [[ -n "$BACKUP_NAME" ]]; then
        echo "Backup : $(basename "$BACKUP_NAME")"
    fi

    echo

fi

if [[ "$DRY_RUN" == true ]]; then
    :
elif [[ "$FORCE" == true ]]; then
    print_warning "Force mode enabled. Skipping update confirmation."
else
    read -rp "Update images? (Y/n): " CONFIRM

    [[ "$CONFIRM" =~ ^[Nn]$ ]] && exit 0
fi

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
    platform_snapshot_images "$PLATFORM" "${TARGET_SERVICES[@]}"
)"

###############################################################################
# Pull latest images
###############################################################################

PULL_OUTPUT="$(platform_pull_images "$PLATFORM" "${TARGET_SERVICES[@]}")" || {
    print_error "Failed to pull platform images."
    exit 1
}

###############################################################################
# Snapshot images AFTER pull
###############################################################################

AFTER_IMAGES="$(
    platform_cd "$PLATFORM" || exit 1
    platform_snapshot_images "$PLATFORM" "${TARGET_SERVICES[@]}"
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

            print "  %-18s %s\n" "$svc" "$status"
        done

        echo

        #######################################################################
        # Rollback
        #######################################################################

        if [[ "$AUTO_BACKUP" == true && -n "$BACKUP_PATH" && -d "$BACKUP_PATH" ]]; then

            print_header "Automatic Rollback"

            print_warning "The update failed health checks."
            print_info "Restoring the pre-update backup..."
            echo
            print_info "Backup : $(basename "$BACKUP_PATH")"

            echo

            if "$SCRIPTS_DIR/restore-platform.sh" \
                "$PLATFORM" \
                "$BACKUP_PATH" \
                --yes
            then
                print_success "Rollback completed."

                echo
                print_info "Verifying platform health after rollback..."

                if platform_health "$PLATFORM"; then
                    print_success "Rollback health check passed."
                    print_success "Platform successfully restored to the previous state."
                    return 1
                else
                    print_error "Rollback completed, but the platform is still unhealthy."
                    return 1
                fi

            else
                print_error "Rollback failed."
                print_error "The platform may be left in an unhealthy state."
                return 1
            fi

        else

            print_warning "No automatic backup is available."
            print_warning "Rollback cannot be performed."

            return 1

        fi
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
