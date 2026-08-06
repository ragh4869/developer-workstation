#!/usr/bin/env bash

set -euo pipefail

VOLUME="$1"
BACKUP_PATH="$2"

ARCHIVE="$BACKUP_PATH/${VOLUME}.tar.gz"

docker volume create "$VOLUME" >/dev/null

docker run --rm \
    -v "$VOLUME":/volume \
    -v "$BACKUP_PATH":/backup \
    alpine \
    sh -c "
        find /volume -mindepth 1 -delete
        tar xzf /backup/${VOLUME}.tar.gz -C /volume
    "
