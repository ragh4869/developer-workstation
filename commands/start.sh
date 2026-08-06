#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

PLATFORM="$1"

prepare_platform "$PLATFORM"

print_header "Starting $PLATFORM Platform"

if docker compose up -d; then
    print_success "$PLATFORM started successfully."
else
    print_error "Failed to start $PLATFORM."
    exit 1
fi

