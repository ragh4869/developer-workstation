#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

############################################################
# Platform Status
############################################################

PLATFORM="$1"

require_platform "$PLATFORM"

print_header "Platform Status"

print_field "Platform" "$PLATFORM"
print_field "Source" "$(get_platform_dir "$PLATFORM")"

echo

status_summary "$PLATFORM"

echo

status_containers "$PLATFORM"
