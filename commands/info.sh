#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

PLATFORM="$1"

prepare_platform "$PLATFORM"

print_header "Platform Information"

print_field "Name" "$PLATFORM"
print_field "Directory" "$(pwd)"
print_field "Compose File" "$(get_compose_filename)"

echo

print_field "Containers" "$(container_count)"
print_field "Volumes" "$(volume_count)"
print_field "Networks" "$(network_count)"
print_field "Health" "$(platform_health)"
print_field "Status" "$(platform_status)"
