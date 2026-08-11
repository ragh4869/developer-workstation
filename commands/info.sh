#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

############################################################
# Platform Information
############################################################

PLATFORM="$1"

require_platform "$PLATFORM"

print_header "Platform Information"

print_field "Platform" "$PLATFORM"
print_field "Directory" "$(get_platform_dir "$PLATFORM")"
print_field "Compose File" "$(info_compose_file "$PLATFORM")"
print_field "Services" "$(info_service_count "$PLATFORM")"
print_field "Volumes" "$(info_volume_count "$PLATFORM")"
print_field "Networks" "$(info_network_count "$PLATFORM")"

echo

LATEST_BACKUP="$(info_latest_backup "$PLATFORM")"

if [[ -n "$LATEST_BACKUP" ]]; then
    print_field "Latest Backup" "$(basename "$LATEST_BACKUP")"
else
    print_field "Latest Backup" "None"
fi

print_field "Backup Size" \
    "$(info_backup_size "$PLATFORM")"

echo

print_field "Restore Excludes" \
    "$(info_restore_excludes "$PLATFORM")"

echo

print_field "Docker Version" \
    "$(info_docker_version)"

print_field "Compose Version" \
    "$(info_compose_version)"
