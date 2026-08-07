#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

PLATFORM="$1"

prepare_platform "$PLATFORM"

if "$SCRIPT_DIR/../scripts/backup-platform.sh" "$PLATFORM"; then
    print_success "$PLATFORM backup completed successfully."
else
    print_error "Failed to backup $PLATFORM."
    exit 1
fi
