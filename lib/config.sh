#!/usr/bin/env bash

####################################
# Load Configuration
####################################

WORKSTATION_DIR="$HOME/Projects/Workstation"

PLATFORM_CONFIG="$WORKSTATION_DIR/config/platforms.conf"

####################################
# Configuration Helpers
####################################

get_backup_directory() {

    echo "$BACKUP_DIR"
}

get_workstation_directory() {

    echo "$WORKSTATION_DIR"
}

get_compose_filename() {

    echo "$COMPOSE_FILE"
}

get_keep_backups() {

    echo "$KEEP_BACKUPS"
}

platform_cd() {
    cd "$(get_platform_dir "$1")" || exit 1
}

list_platforms() {
    cut -d= -f1 "$PLATFORM_CONFIG"
}

get_platform_dir() {

    local platform="$1"

    grep "^${platform}=" "$PLATFORM_CONFIG" \
        | cut -d'=' -f2- \
        | sed "s|\$HOME|$HOME|g" \
        | tr -d '"'
}

platform_exists() {

    local PLATFORM="$1"

}

require_platform() {

    local PLATFORM="$1"

    platform_exists "$PLATFORM"
    RESULT=$?

    if [ "$RESULT" -ne 0 ]; then
        echo
        echo "Unknown platform: $PLATFORM"
        echo
        echo "Available platforms:"
        list_platforms
        exit 1
    fi
}
