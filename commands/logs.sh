#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

############################################################
# Platform Logs
############################################################

PLATFORM="$1"
shift

require_platform "$PLATFORM"

SERVICE=""
DEFAULT_LOG_TAIL=50
TAIL_SET=""
TAIL="$DEFAULT_LOG_TAIL"
SINCE=""
FOLLOW=false

while [[ $# -gt 0 ]]
do
    case "$1" in
        --tail)
            TAIL="$2"
            TAIL_SET=true
            shift 2
            ;;
        --since)
            shift

            SINCE_ARGS=()

            while [[ $# -gt 0 && "$1" != --* ]]
            do
                SINCE_ARGS+=("$1")
                shift
            done

            SINCE="$(resolve_since "${SINCE_ARGS[@]}")"
            ;;

        -f|--follow)
            FOLLOW=true
            shift
            ;;
        *)
            if [[ -z "$SERVICE" ]]; then
                SERVICE="$1"
            else
                print_error "Unknown option: $1"
                exit 1
            fi
            shift
            ;;
    esac
done


print_header "Platform Logs"

print_field "Platform" "$PLATFORM"

if [[ -n "$SERVICE" ]]; then
    print_field "Service" "$SERVICE"
else
    print_field "Service" "All"
fi

[[ -n "$SINCE" ]] && \
print_field "Since" "$SINCE"

[[ -n "$TAIL_SET" ]] && \
print_field "Tail" "$TAIL"


[[ "$FOLLOW" == true ]] && \
print_field "Mode" "Follow"

echo

logs_show \
    "$PLATFORM" \
    "$SERVICE" \
    "$TAIL" \
    "$SINCE" \
    "$FOLLOW"
