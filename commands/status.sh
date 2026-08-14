#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

############################################################
# Platform Status
############################################################

PLATFORM="$1"

if [[ -z "$PLATFORM" ]]; then
    print_error "Platform is required."
    exit 1
fi

resolve_platform_targets "$PLATFORM" || exit 1

for platform in "${PLATFORM_TARGETS[@]}"; do

    print_header "Platform Status: $platform"

    print_field "Platform" "$platform"
    print_field "Source" "$(get_platform_dir "$platform")"

    echo

    status_summary "$platform"

    echo

    status_containers "$platform"

done
