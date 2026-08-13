#!/usr/bin/env bash

####################################
#       Load configuration         #
####################################

############################################################
# Resolve common library directory
############################################################

if [[ -z "${COMMON_LIB_DIR:-}" ]]; then

    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        COMMON_LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

    elif [[ -n "${ZSH_VERSION:-}" ]]; then
        COMMON_LIB_DIR="$(cd -- "$(dirname -- "${(%):-%x}")" && pwd)"

    else
        COMMON_LIB_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
    fi

    readonly COMMON_LIB_DIR
    readonly LIB_ROOT="$COMMON_LIB_DIR"
    readonly WORKSTATION_ROOT="$(cd -- "$COMMON_LIB_DIR/.." && pwd)"

    readonly CONFIG_DIR="$WORKSTATION_ROOT/config"
    readonly RESTORE_EXCLUDES_CONFIG="$CONFIG_DIR/restore-excludes.conf"
    readonly COMMANDS_DIR="$WORKSTATION_ROOT/commands"
    readonly SCRIPTS_DIR="$WORKSTATION_ROOT/scripts"
    readonly BACKUP_DIR="$WORKSTATION_ROOT/backups"
    readonly INFRASTRUCTURE_ROOT="$HOME/Projects/Infrastructure"

fi

source "$COMMON_LIB_DIR/config.sh" 2>/dev/null
source "$COMMON_LIB_DIR/colors.sh" 2>/dev/null
source "$COMMON_LIB_DIR/ui.sh" 2>/dev/null
source "$COMMON_LIB_DIR/output.sh" 2>/dev/null
source "$COMMON_LIB_DIR/docker.sh" 2>/dev/null
source "$COMMON_LIB_DIR/system.sh" 2>/dev/null
source "$COMMON_LIB_DIR/status.sh" 2>/dev/null
source "$COMMON_LIB_DIR/info.sh" 2>/dev/null
source "$COMMON_LIB_DIR/logs.sh" 2>/dev/null
source "$COMMON_LIB_DIR/backup.sh" 2>/dev/null
source "$COMMON_LIB_DIR/restore.sh" 2>/dev/null
source "$COMMON_LIB_DIR/update.sh" 2>/dev/null
source "$COMMON_LIB_DIR/services.sh" 2>/dev/null
source "$COMMON_LIB_DIR/health.sh" 2>/dev/null
source "$COMMON_LIB_DIR/doctor.sh" 2>/dev/null

####################################
#             Colors               #
####################################

RESET="\033[0m"
BOLD="\033[1m"

BLACK="\033[0;30m"
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[1;37m"
GRAY="\033[0;90m"

####################################
#           Timestamp              #
####################################

timestamp() {

    date +"%Y-%m-%d_%H-%M-%S"
}


############################################################
#                      Platform Helpers                    #
############################################################

platform_exists() {
    local platform="$1"

    grep -q "^${platform}=" "$CONFIG_DIR/platforms.conf"
}

list_platforms() {
    cut -d'=' -f1 "$CONFIG_DIR/platforms.conf"
}

resolve_platform_targets() {
    local target="${1:-}"

    PLATFORM_TARGETS=()

    if [[ -z "$target" ]]; then
        print_error "Platform target is required."
        return 1
    fi

    if [[ "$target" == "all" ]]; then
        while IFS= read -r platform; do
            PLATFORM_TARGETS+=("$platform")
        done < <(list_platforms)
    else
        require_platform "$target"
        PLATFORM_TARGETS=("$target")
    fi

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
#                     Docker Helpers                       #
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
        ls -la "$dir"

        exit 1
    fi
}

get_compose_file() {

    local platform="$1"

    echo "$(get_platform_dir "$platform")/$(get_compose_filename "$platform")"
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

###############################################################################
#                           Backup & Restore Helpers                          #
###############################################################################

select_backup() {

    local platform="$1"
    local backup_root

    backup_root="$(platform_backup_directory "$platform")"

    [[ -d "$backup_root" ]] || {
        print_error "No backups found."
        exit 1
    }

    mapfile -t BACKUPS < <(
        find "$backup_root" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d |
        sort -r
    )

    [[ ${#BACKUPS[@]} -gt 0 ]] || {
        print_error "No backups available."
        exit 1
    }

    while true
    do
        echo >&2
        print_header "Restore Options" >&2

        echo "1) Latest Backup (Recommended)" >&2
        echo "2) Choose Backup" >&2
        echo "3) Cancel" >&2
        echo >&2

        read -rp "Selection [1]: " OPTION
        OPTION=${OPTION:-1}

        case "$OPTION" in

            1)

                if confirm_backup "${BACKUPS[0]}"
                then
                    echo "${BACKUPS[0]}"
                    return
                fi

            ;;

            2)

                local selected

                selected=$(choose_backup "${BACKUPS[@]}")
                if confirm_backup "$selected"
                then
                    echo "$selected"
                    return
                fi
            ;;

            3)

                print_warning "Restore cancelled."

                exit 0
                ;;

            *)

                print_error "Invalid selection."

                ;;

        esac

    done

}

confirm_backup() {

    local backup="$1"

    get_backup_metadata "$backup"

    {
        echo
        print_header "Selected Backup"

        printf "%-12s : %s\n" "Name" "$BACKUP_NAME"
        printf "%-12s : %s\n" "Host" "$BACKUP_HOST"
        printf "%-12s : %s\n" "Platform" "$BACKUP_PLATFORM"
        printf "%-12s : %s\n" "Volumes" "$BACKUP_VOLUMES"
        printf "%-12s : %s\n" "Size" "$BACKUP_SIZE"

        echo
    } >&2

    read -rp "Continue with this backup? (Y/n): " ANSWER

    ANSWER=${ANSWER:-Y}

    [[ "$ANSWER" =~ ^[Yy]$ ]]
}

choose_backup() {

    local BACKUPS=("$@")
    local choice

    echo >&2
    print_header "Available Backups" >&2

    local i=1

    for BACKUP in "${BACKUPS[@]}"
    do

        get_backup_metadata "$BACKUP"

        printf "%2d) %-22s (Host: %s) (Volumes: %s) (%s)\n" \
            "$i" \
            "$BACKUP_NAME" \
            "$BACKUP_HOST" \
            "$BACKUP_VOLUMES" \
            "$BACKUP_SIZE" >&2

        ((i++))

    done

    echo >&2

    while true
    do

        read -rp "Select backup [1-${#BACKUPS[@]}]: " choice

        [[ "$choice" =~ ^[0-9]+$ ]] || continue

        if (( choice >= 1 && choice <= ${#BACKUPS[@]} ))
        then
            echo "${BACKUPS[$((choice-1))]}"
            return
        fi

    done

}


get_backup_metadata() {

    local backup="$1"

    BACKUP_NAME=$(basename "$backup")
    BACKUP_SIZE=$(du -sh "$backup" | cut -f1)

    BACKUP_HOST="Unknown"
    BACKUP_PLATFORM="Unknown"
    BACKUP_VOLUMES="-"

    if [[ -f "$backup/metadata.json" ]]; then

        BACKUP_HOST=$(jq -r '.hostname // "Unknown"' "$backup/metadata.json")
        BACKUP_PLATFORM=$(jq -r '.platform // "Unknown"' "$backup/metadata.json")
        BACKUP_VOLUMES=$(jq -r '.volume_count // "-"' "$backup/metadata.json")

    fi
}



backup_directory() {

    echo "$BACKUP_DIR"

}

platform_backup_directory() {
    local platform="$1"
    echo "$BACKUP_DIR/$platform"
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

    [[ ! -f "$RESTORE_EXCLUDES_CONFIG" ]] && {
        echo ""
        return
    }

    grep "^${platform}=" "$RESTORE_EXCLUDES_CONFIG" \
        | cut -d= -f2- \

}
