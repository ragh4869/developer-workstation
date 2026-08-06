#!/usr/bin/env bash

discover_volumes() {

    COMPOSE_FILE="$1"

    docker compose \
        -f "$COMPOSE_FILE" \
        config --volumes

}
