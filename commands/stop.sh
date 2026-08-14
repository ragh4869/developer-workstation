#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

PLATFORM="$1"

if [[ -z "$PLATFORM" ]]; then
    print_error "Platform is required."
    exit 1
fi

resolve_platform_targets "$PLATFORM" || exit 1

overall_status=0

for platform in "${PLATFORM_TARGETS[@]}"; do

    prepare_platform "$platform"

    print_header "Stopping $platform Platform"

    if docker compose down; then
        printf "\n"
        print_success "$platform stopped successfully."
    else
        print_error "Failed to stop $platform."
        overall_status=1
    fi

done

exit "$overall_status"
