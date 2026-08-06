#!/usr/bin/env bash

set -e

echo
echo "=========================================="
echo "       Updating Operations Platform       "
echo "=========================================="
echo

SERVICES=(
traefik
prometheus
grafana
homepage
uptime-kuma
)

UPDATED=0

for SERVICE in "${SERVICES[@]}"
do
    echo "----------------------------------------"
    echo "Updating: $SERVICE"
    echo

    docker compose pull "$SERVICE"
    docker compose up -d "$SERVICE"

    UPDATED=$((UPDATED+1))

    echo
done

echo
echo "Waiting for platform..."
sleep 8

echo
docker compose ps

echo
echo "Running Health Check..."
echo

platform health operations

echo
echo "Cleaning unused images..."

docker image prune -f >/dev/null

echo
echo "=========================================="
echo "            Update Complete               "
echo "=========================================="
echo

echo "Services Updated : $UPDATED"
