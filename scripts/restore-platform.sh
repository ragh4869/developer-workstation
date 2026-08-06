#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/volumes.sh"

PLATFORM="${1:-}"
BACKUP_PATH="${2:-}"

require_platform "$PLATFORM"
require_docker

SOURCE="$(get_platform_dir "$PLATFORM")"

if [[ -z "$BACKUP_PATH" ]]; then
    BACKUP_PATH="$(latest_backup "$PLATFORM")"
fi

if [[ ! -d "$BACKUP_PATH" ]]; then
    print_error "Backup not found."
    exit 1
fi

print_header "Restoring $PLATFORM"

print_info "Platform : $PLATFORM"
print_info "Source   : $SOURCE"
print_info "Backup   : $BACKUP_PATH"

echo

########################################
# Validate backup
########################################

for FILE in metadata.json
do
    [[ -f "$BACKUP_PATH/$FILE" ]] || {
        print_error "Missing $FILE"
        exit 1
    }
done

print_success "Backup is valid."

echo

cat "$BACKUP_PATH/metadata.json"

echo

read -rp "Restore this backup? (y/N): " CONFIRM

[[ "$CONFIRM" =~ ^[Yy]$ ]] || {
    print_warning "Restore cancelled."
    exit 0
}

########################################
# Stop platform
########################################

print_info "Stopping platform..."

(
    platform_cd "$PLATFORM"

    docker compose down
)

########################################
# Restore compose configuration
########################################

print_info "Restoring compose configuration..."

cp "$BACKUP_PATH"/compose.* "$SOURCE/" 2>/dev/null || true
cp "$BACKUP_PATH/.env" "$SOURCE/" 2>/dev/null || true

########################################
# Restore folders
########################################

for DIR in homepage prometheus grafana traefik uptime-kuma
do

    [[ ! -d "$BACKUP_PATH/$DIR" ]] && continue

    print_info "Restoring $DIR..."

    mkdir -p "$SOURCE/$DIR"

    RSYNC_ARGS=(-a --delete)

    for EXCLUDE in "${EXCLUDES[@]}"
    do
        [[ -n "$EXCLUDE" ]] && RSYNC_ARGS+=(--exclude="${EXCLUDE}/")
    done

    rsync \
        "${RSYNC_ARGS[@]}" \
        "$BACKUP_PATH/$DIR/" \
        "$SOURCE/$DIR/"

done

########################################
# Restore Docker volumes
########################################

print_info "Restoring Docker volumes..."

COMPOSE_FILE="$(get_compose_file "$PLATFORM")"

PROJECT="$(basename "$SOURCE")"

VOLUMES="$(discover_volumes "$COMPOSE_FILE")"

for VOLUME in $VOLUMES
do

    REAL_VOLUME="${PROJECT}_${VOLUME}"

    [[ ! -f "$BACKUP_PATH/${REAL_VOLUME}.tar.gz" ]] && continue

    print_info "Restoring $REAL_VOLUME..."

    "$SCRIPTS_DIR/restore-volume.sh" \
        "$REAL_VOLUME" \
        "$BACKUP_PATH"

done

########################################
# Start platform
########################################

print_info "Starting platform..."

(
    platform_cd "$PLATFORM"

    docker compose up -d
)

########################################
# Health Check
########################################

print_info "Running health check..."

platform health "$PLATFORM"

########################################
# Finished
########################################

print_success "Restore completed successfully."

echo
echo "Platform : $PLATFORM"
echo "Backup   : $(basename "$BACKUP_PATH")"
echo
