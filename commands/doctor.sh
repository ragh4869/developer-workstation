#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

source "$HOME/Projects/Workstation/lib/colors.sh"
source "$HOME/Projects/Workstation/lib/output.sh"
source "$HOME/Projects/Workstation/lib/docker.sh"
source "$HOME/Projects/Workstation/lib/system.sh"

echo
echo "================================================="
echo "           AI Engineering Workstation            "
echo "================================================="
echo

print_header "AI Engineering Workstation"

echo "System"

echo
show_cpu

echo
show_memory

echo
show_disk

require_docker

if docker_running
then
    print_success "Docker Running"
else
    print_error "Docker Not Running"
fi

echo
echo "Containers:"
echo

check_container traefik
check_container homepage
check_container grafana
check_container prometheus
check_container uptime-kuma

check_container portainer

check_container n8n
check_container flowise
check_container minio

check_container postgres
check_container redis
check_container mongodb
check_container mysql

check_container open-webui
check_container chromadb
check_container qdrant
