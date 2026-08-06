#!/usr/bin/env bash

PLATFORM=$1

if [[ -z "$PLATFORM" ]]; then

    echo
    echo "Usage:"
    echo
    echo "platform restore operations"
    echo

    exit 1

fi

~/Projects/Workstation/scripts/restore-platform.sh "$PLATFORM"
