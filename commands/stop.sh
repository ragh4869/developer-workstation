#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

PLATFORM="$1"

prepare_platform "$PLATFORM"

print_header "Stopping $PLATFORM Platform"

if docker compose down; then
    print_success "$PLATFORM stopped successfully."
else
    print_error "Failed to stop $PLATFORM."
    exit 1
fi
