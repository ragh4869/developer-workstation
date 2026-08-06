#!/usr/bin/env bash

set -e

VOLUME=$1
DEST=$2

if [[ -z "$VOLUME" || -z "$DEST" ]]; then
    echo "Usage: backup-volume.sh <volume> <destination>"
    exit 1
fi

echo "Backing up volume: $VOLUME"

docker run --rm \
    -v "$VOLUME":/volume \
    -v "$DEST":/backup \
    alpine \
    tar czf "/backup/${VOLUME}.tar.gz" -C /volume .
