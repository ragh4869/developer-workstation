#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/volumes.sh"

PLATFORM="${1:-}"

require_platform "$PLATFORM"
require_docker

SOURCE="$(get_platform_dir "$PLATFORM")"
COMPOSE_FILE="$(get_compose_filename "$PLATFORM")"
DEST="$(backup_destination "$PLATFORM")"

mkdir -p "$DEST"

print_header "Backing Up $PLATFORM"

print_info "Platform : $PLATFORM"
print_info "Source   : $SOURCE"
print_info "Backup   : $DEST"

echo

############################################################
# Copy compose configuration
############################################################

print_step "Copying compose configuration..."

cp "$COMPOSE_FILE" "$DEST/" 2>/dev/null || true
cp "$SOURCE/.env" "$DEST/" 2>/dev/null || true

############################################################
# Copy platform folders
############################################################

for DIR in homepage prometheus grafana traefik uptime-kuma
do
    [[ ! -d "$SOURCE/$DIR" ]] && continue

    print_step "Copying $DIR..."

    if [[ "$DIR" == "homepage" ]]; then

        mkdir -p "$DEST/homepage"

        rsync -a \
            --exclude logs \
            "$SOURCE/homepage/" \
            "$DEST/homepage/"

    else

        cp -R "$SOURCE/$DIR" "$DEST/"

    fi

done

############################################################
# Backup Docker volumes
############################################################

print_step "Discovering Docker volumes..."

VOLUMES="$(discover_volumes "$COMPOSE_FILE")"

PROJECT="$(basename "$SOURCE")"

for VOLUME in $VOLUMES
do

    REAL_VOLUME="${PROJECT}_${VOLUME}"

    if docker volume inspect "$REAL_VOLUME" >/dev/null 2>&1
    then

        print_step "Backing up $REAL_VOLUME..."

        "$SCRIPTS_DIR/backup-volume.sh" \
            "$REAL_VOLUME" \
            "$DEST"

    else

        print_warning "Skipping $REAL_VOLUME"

    fi

done

############################################################
# Metadata
############################################################

cat > "$DEST/metadata.json" <<EOF
{
    "platform": "$PLATFORM",
    "created": "$(date --iso-8601=seconds)",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "docker_version": "$(docker --version | sed 's/"/\\"/g')",
    "compose_version": "$(docker compose version | sed 's/"/\\"/g')",
    "volume_count": $(echo "$VOLUMES" | wc -w)
}
EOF

############################################################
# Finished
############################################################

print_success "Backup completed successfully."

echo
echo "Backup location:"
echo "  $DEST"
echo
