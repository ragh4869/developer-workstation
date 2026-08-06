#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

PLATFORM="$1"

prepare_platform "$PLATFORM"

print_header "$PLATFORM Health"

print_field "Status" "$(platform_status)"
print_field "Health" "$(platform_health)"
print_field "Running" "$(running_container_count)"
print_field "Containers" "$(container_count)"
print_field "Volumes" "$(volume_count)"
print_field "Networks" "$(network_count)"

echo
docker compose ps
