#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

PLATFORM="$1"

prepare_platform "$PLATFORM"

print_header "Restarting $PLATFORM Platform"

if docker compose restart; then
    print_success "$PLATFORM restarted successfully."
else
    print_error "Failed to restart $PLATFORM."
    exit 1
fi
