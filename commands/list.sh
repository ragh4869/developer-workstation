#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$SCRIPT_DIR/../lib/common.sh"

echo

echo "Available Platforms"

echo

for PLATFORM in $(list_platforms)
do

    DIR=$(get_platform_dir "$PLATFORM")

    printf "%-15s %s\n" "$PLATFORM" "$DIR"

done

echo
