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
    BACKUP_PATH="$(select_backup "$PLATFORM")"
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

print_header "Backup Information"

jq -r '
[
    ["Platform", .platform],
    ["Created", .created],
    ["Hostname", .hostname],
    ["User", .user],
    ["Docker", .docker_version],
    ["Compose", .compose_version],
    ["Volumes", (.volume_count|tostring)]
]
|
.[] |
@tsv
' "$BACKUP_PATH/metadata.json" |
while IFS=$'\t' read -r key value
do
    printf "%-12s : %s\n" "$key" "$value"
done

SIZE=$(du -sh "$BACKUP_PATH" | cut -f1)
printf "%-12s : %s\n" "Size" "$SIZE"

echo
print_warning "This will overwrite the current platform."

read -rp "Continue and restore this backup? (y/N): " CONFIRM

[[ "$CONFIRM" =~ ^[Yy]$ ]] || {
    print_warning "Restore cancelled."
    exit 0
}

########################################
# Stop platform
########################################

print_step "Stopping platform..."

(
    platform_cd "$PLATFORM"

    docker compose down
)

########################################
# Restore compose configuration
########################################

print_step "Restoring compose configuration..."

cp "$BACKUP_PATH"/compose.* "$SOURCE/" 2>/dev/null || true
cp "$BACKUP_PATH/.env" "$SOURCE/" 2>/dev/null || true

########################################
# Restore folders
########################################

RESTORE_EXCLUDES="$(get_restore_excludes "$PLATFORM")"

IFS=',' read -ra EXCLUDES <<< "$RESTORE_EXCLUDES"

for DIR in homepage prometheus grafana traefik uptime-kuma
do

    [[ ! -d "$BACKUP_PATH/$DIR" ]] && continue

    print_step "Restoring $DIR..."

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

print_step "Restoring Docker volumes..."

COMPOSE_FILE="$(get_compose_file "$PLATFORM")"

PROJECT="$(basename "$SOURCE")"

VOLUMES="$(discover_volumes "$COMPOSE_FILE")"

for VOLUME in $VOLUMES
do

    REAL_VOLUME="${PROJECT}_${VOLUME}"

    [[ ! -f "$BACKUP_PATH/${REAL_VOLUME}.tar.gz" ]] && continue

    print_step "Restoring $REAL_VOLUME..."

    "$SCRIPTS_DIR/restore-volume.sh" \
        "$REAL_VOLUME" \
        "$BACKUP_PATH"

done

########################################
# Start platform
########################################

print_step "Starting platform..."

(
    platform_cd "$PLATFORM"

    docker compose up -d
)

########################################
# Health Check
########################################

print_step "Running health check..."

platform health "$PLATFORM"

########################################
# Finished
########################################

print_success "Restore completed successfully."

echo
echo "Platform : $PLATFORM"
echo "Backup   : $(basename "$BACKUP_PATH")"
echo
