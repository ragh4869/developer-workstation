#!/usr/bin/env bash

############################################################
# Platform Information Library
############################################################

#
# Returns the compose filename
#
info_compose_file() {

    local PLATFORM="$1"

    basename "$(get_compose_file "$PLATFORM")"
}

############################################################

#
# Returns number of services
#
info_service_count() {

    local PLATFORM="$1"

    (
        platform_cd "$PLATFORM"

        docker compose config --services | wc -l
    )
}

############################################################

#
# Returns number of volumes
#
info_volume_count() {

    local PLATFORM="$1"

    local COMPOSE_FILE

    COMPOSE_FILE="$(get_compose_file "$PLATFORM")"

    discover_volumes "$COMPOSE_FILE" | wc -w
}

############################################################

#
# Returns number of networks
#
info_network_count() {

    local PLATFORM="$1"

    (
        platform_cd "$PLATFORM"

        docker network ls \
            --format '{{.Name}}' |
            grep "^$(basename "$(pwd)")" |
            wc -l
    )
}

############################################################

#
# Latest backup
#
info_latest_backup() {

    local PLATFORM="$1"

    latest_backup "$PLATFORM"
}

############################################################

#
# Latest backup size
#
info_backup_size() {

    local PLATFORM="$1"

    local BACKUP

    BACKUP="$(latest_backup "$PLATFORM")"

    [[ -z "$BACKUP" ]] && {
        echo "N/A"
        return
    }

    du -sh "$BACKUP" | cut -f1
}

############################################################

#
# Docker version
#
info_docker_version() {

    docker version \
        --format '{{.Server.Version}}'
}

############################################################

#
# Docker Compose version
#
info_compose_version() {

    docker compose version \
        --short
}

############################################################

#
# Restore excludes
#
info_restore_excludes() {

    local PLATFORM="$1"

    get_restore_excludes "$PLATFORM"
}
