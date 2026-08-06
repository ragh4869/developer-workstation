#!/usr/bin/env bash

####################################
# Validate Backup
####################################

validate_backup() {

    local BACKUP="$1"

    [[ -d "$BACKUP" ]] || return 1
    [[ -f "$BACKUP/metadata.json" ]] || return 1

    return 0
}

####################################
# Read Metadata
####################################

show_backup_metadata() {

    local BACKUP="$1"

    jq . "$BACKUP/metadata.json"
}

####################################
# Confirm Restore
####################################

confirm_restore() {

    echo
    read -rp "Restore this backup? (y/N): " ANSWER

    [[ "$ANSWER" =~ ^[Yy]$ ]]
}

####################################
# Wait For Containers
####################################

wait_for_platform() {

    local PLATFORM="$1"

    echo
    echo "Waiting for containers..."

    sleep 10

    platform health "$PLATFORM"
}
