#!/usr/bin/env bash

PLATFORM=$1

case "$PLATFORM" in

operations)

cd ~/Projects/Infrastructure/operations-platform

~/Projects/Workstation/scripts/update-platform.sh
;;

monitoring)

cd ~/Projects/Infrastructure/monitoring-platform

docker compose pull

docker compose up -d
;;

*)

echo "Usage:"
echo
echo "platform update operations"
echo "platform update monitoring"
;;

esac
