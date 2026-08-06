#!/bin/bash

source "$HOME/Projects/Workstation/lib/colors.sh"

header() {
    echo
    echo -e "${BLUE}========================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}!${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

section() {

    echo
    echo "----------------------------------------"
    echo "$1"
    echo "----------------------------------------"

}
