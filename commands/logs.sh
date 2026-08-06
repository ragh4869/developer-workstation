#!/bin/bash

source "$HOME/Projects/Workstation/lib/output.sh"

SERVICE="$1"

if [ -z "$SERVICE" ]; then
    error "Usage: platform logs <container-name>"
    exit 1
fi

header "Logs: $SERVICE"

docker logs --tail=100 -f "$SERVICE"
