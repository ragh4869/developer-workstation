#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

set -e

PLATFORM="$1"
shift || true

if [[ -z "$PLATFORM" ]]; then
    print_error "Platform is required."
    echo
    echo "Usage:"
    echo "  platform services <platform> [service ...]"
    exit 1
fi

###############################################################################
# Resolve platform targets
###############################################################################

resolve_platform_targets "$PLATFORM" || exit 1

###############################################################################
# Execute
###############################################################################

if [[ "$PLATFORM" == "all" ]]; then

    if [[ $# -gt 0 ]]; then
        print_error "Service selection is not supported with 'all'."
        echo
        echo "Use:"
        echo "  platform services all"
        echo "  platform services <platform> <service ...>"
        exit 1
    fi

    for TARGET_PLATFORM in "${PLATFORM_TARGETS[@]}"; do

        show_platform_services "$TARGET_PLATFORM"

    done

else

    show_platform_services "$PLATFORM" "$@"

fi
