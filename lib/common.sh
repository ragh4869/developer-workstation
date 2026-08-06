#!/usr/bin/env bash

####################################
#       Load configuration         #
####################################

readonly COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_ROOT="$COMMON_LIB_DIR"
readonly WORKSTATION_ROOT="$(cd "$COMMON_LIB_DIR/.." && pwd)"

readonly CONFIG_DIR="$WORKSTATION_ROOT/config"
readonly RESTORE_EXCLUDES_CONFIG="$CONFIG_DIR/restore-excludes.conf"
readonly COMMANDS_DIR="$WORKSTATION_ROOT/commands"
readonly SCRIPTS_DIR="$WORKSTATION_ROOT/scripts"
readonly BACKUP_DIR="$WORKSTATION_ROOT/backups"
readonly INFRASTRUCTURE_ROOT="$HOME/Projects/Infrastructure"

source "$COMMON_LIB_DIR/config.sh" 2>/dev/null
source "$COMMON_LIB_DIR/colors.sh" 2>/dev/null
source "$COMMON_LIB_DIR/output.sh" 2>/dev/null
source "$COMMON_LIB_DIR/docker.sh" 2>/dev/null
source "$COMMON_LIB_DIR/system.sh" 2>/dev/null
source "$COMMON_LIB_DIR/backup.sh" 2>/dev/null
source "$COMMON_LIB_DIR/restore.sh" 2>/dev/null

####################################
#            Colours               #
####################################

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
NC="\033[0m"

####################################
#            Printing              #
####################################

print_header() {

    echo
    echo "================================================="
    echo "$1"
    echo "================================================="
    echo
}

print_success() {

    echo -e "${GREEN}✓${NC} $1"
}

print_error() {

    echo -e "${RED}✗${NC} $1"
}

print_warning() {

    echo -e "${YELLOW}!${NC} $1"
}

print_field() {

    printf "%-13s : %s\n" "$1" "$2"
}

print_info() {
    echo -e "${BLUE}{NC} $1"
}

####################################
#           Timestamp              #
####################################

timestamp() {

    date +"%Y-%m-%d_%H-%M-%S"
}


############################################################
# Platform Helpers
############################################################

platform_exists() {
    local platform="$1"

    grep -q "^${platform}=" "$CONFIG_DIR/platforms.conf"
}

list_platforms() {
    cut -d'=' -f1 "$CONFIG_DIR/platforms.conf"
}

require_platform() {
    local platform="$1"

    if ! platform_exists "$platform"; then
        print_error "Unknown platform: $platform"

        echo
        print_warning "Available platforms:"

        list_platforms

        exit 1
    fi
}

get_platform_dir() {

    local platform="$1"

    grep "^${platform}=" "$CONFIG_DIR/platforms.conf" \
        | cut -d'=' -f2- \
        | cut -d'|' -f1 \
        | sed "s|\$HOME|$HOME|g" \
        | tr -d '"'
}

platform_cd() {

    local dir

    dir=$(get_platform_dir "$1")

    cd "$dir" || exit 1
}

platform_status() {

    local total running

    total=$(container_count)
    running=$(running_container_count)

    if (( total == 0 )); then
        echo "Stopped"
    elif (( running == total )); then
        echo "Running"
    elif (( running == 0 )); then
        echo "Stopped"
    else
        echo "Partial"
    fi
}

platform_health() {

    printf "%s / %s" \
        "$(running_container_count)" \
        "$(container_count)"
}

prepare_platform() {

    local platform="$1"

    require_docker
    require_platform "$platform"
    platform_cd "$platform"
}


############################################################
# Docker Helpers
############################################################

get_compose_filename() {

    local platform="${1:-}"
    local dir="."

    if [[ -n "$platform" ]]; then
        dir="$(get_platform_dir "$platform")"
    fi

    if [[ -f "$dir/docker-compose.yml" ]]; then
        echo docker-compose.yml
    elif [[ -f "$dir/compose.yml" ]]; then
        echo compose.yml
    elif [[ -f "$dir/docker-compose.yaml" ]]; then
        echo docker-compose.yaml
    elif [[ -f "$dir/compose.yaml" ]]; then
        echo compose.yaml
    else
        print_error "No compose file found in $dir."
        exit 1
    fi
}

get_compose_file() {

    local platform="$1"

    echo "$(get_platform_dir "$platform")/$(get_compose_filename)"
}

require_docker() {

    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running."
        exit 1
    fi
}


##############################################
#               Other Helpers                #
##############################################

container_count() {

    docker compose ps -q | wc -l | tr -d ' '
}

running_container_count() {

    docker compose ps \
        --status running \
        -q | wc -l | tr -d ' '
}

volume_count() {

    docker compose config \
        --volumes | wc -l | tr -d ' '
}

network_count() {

    docker compose config \
        --networks | wc -l | tr -d ' '
}

backup_directory() {

    echo "$BACKUP_DIR"

}

backup_destination() {
    local platform="$1"

    echo "$BACKUP_DIR/$platform/$(timestamp)"
}

latest_backup() {

    local platform="$1"

    ls -dt "$BACKUP_DIR/$platform"/* 2>/dev/null | head -1

}

get_restore_excludes() {

    local platform="$1"

    [[ ! -f "$RESTORE_EXCLUDES_CONFIG" ]] && return

    grep "^${platform}=" "$RESTORE_EXCLUDES_CONFIG" \
        | cut -d= -f2- \

}
