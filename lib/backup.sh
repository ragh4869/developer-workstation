#!/usr/bin/env bash

####################################
# Discover Docker Volumes
####################################

discover_volumes() {

    local COMPOSE_FILE="$1"

    docker compose \
        -f "$COMPOSE_FILE" \
        config \
        --volumes
}

####################################
# Docker Volume Exists
####################################

volume_exists() {

    docker volume inspect "$1" >/dev/null 2>&1
}

####################################
# Compose Project Name
####################################

compose_project() {

    local COMPOSE_FILE="$1"

    docker compose \
        -f "$COMPOSE_FILE" \
        config \
        --format json \
        | jq -r '.name'
}

####################################
# Full Docker Volume Name
####################################

full_volume_name() {

    local PROJECT="$1"
    local VOLUME="$2"

    echo "${PROJECT}_${VOLUME}"
}

####################################
# Backup Metadata
####################################

create_metadata() {

    local DEST="$1"
    local PLATFORM="$2"
    local VOLUME_COUNT="$3"

    cat > "$DEST/metadata.json" <<EOF
{
    "platform": "$PLATFORM",
    "created": "$(date --iso-8601=seconds)",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "docker_version": "$(docker --version)",
    "compose_version": "$(docker compose version)",
    "volume_count": $VOLUME_COUNT
}
EOF
}
