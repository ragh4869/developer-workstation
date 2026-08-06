#!/usr/bin/env bash

SERVICE=$1

if [ -z "$SERVICE" ]; then
    echo "Usage: update-service.sh <service>"
    exit 1
fi

echo "Updating $SERVICE..."

docker compose pull "$SERVICE"

docker compose up -d "$SERVICE"

echo
echo "Waiting for container..."

sleep 5

docker compose ps "$SERVICE"
