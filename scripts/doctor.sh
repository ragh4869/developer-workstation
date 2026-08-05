#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
BLUE="\033[1;34m"
NC="\033[0m"

check_container () {

if docker ps --format '{{.Names}}' | grep -q "^$1$"
then
    printf "${GREEN}✓${NC} %-25s Running\n" "$1"
else
    printf "${RED}✗${NC} %-25s Not Running\n" "$1"
fi

}

echo
echo "System"

echo "CPU:"
nproc

echo

echo "Memory:"
free -h

echo

echo "Disk:"
df -h /
