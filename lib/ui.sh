#!/usr/bin/env bash

###########################################
#               Colors                    #
###########################################

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

###########################################
#            Output Helpers               #
###########################################

print_header() {
    local title="$1"
    local width=$((${#title} + 6))
    local line

    printf -v line '%*s' "$width" ''
    line=${line// /═}

    echo
    echo -e "${BOLD}${WHITE}╔${line}╗${RESET}"
    echo -e "${BOLD}${WHITE}║   ${title}   ║${RESET}"
    echo -e "${BOLD}${WHITE}╚${line}╝${RESET}"
    echo
}

print_header_old() {
    local title="$1"
    local width=${#title}
    local line

    printf -v line '%*s' "$width" ''
    line=${line// /=}

    echo
    echo -e "${BOLD}${WHITE}${line}${RESET}"
    echo -e "${BOLD}${WHITE}${title}${RESET}"
    echo -e "${BOLD}${WHITE}${line}${RESET}"
    echo
}

print_divider() {
    printf "${GRAY}%0.s-" {1..70}
    echo -e "${RESET}"
}

print_step() {
    echo -e "${BLUE}➤ ${RESET} $1"
}

print_info() {
    echo -e "${CYAN}ℹ ${RESET} $1"
}

print_success() {
    echo -e "${GREEN}✔ ${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

print_error() {
    echo -e "${RED}✘${RESET} $1"
}

print_field() {
    printf "%-13s : %s\n" "$1" "$2"
}

print_progress() {

    local current="$1"
    local total="$2"
    local text="$3"

    printf "\n${BLUE}[%d/%d]${RESET} %s\n" \
        "$current" \
        "$total" \
        "$text"

}

print_summary() {

    local title="$1"

    shift

    print_header "$title"

    while (( "$#" ))
    do

        printf "%-15s : %s\n" "$1" "$2"

        shift 2

    done

}

print_table_row() {

    printf "%-20s %-20s\n" "$1" "$2"

}

###########################################
#               Timers                    #
###########################################

start_timer() {

    TIMER_START=$(date +%s)

}

stop_timer() {

    TIMER_END=$(date +%s)

    format_duration \
        "$((TIMER_END-TIMER_START))"

}

format_duration() {
    local total_seconds="${1:-0}"

    local days=$((total_seconds / 86400))
    local hours=$(((total_seconds % 86400) / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local seconds=$((total_seconds % 60))

    if (( days > 0 )); then
        printf "%dd %02dh %02dm %02ds" \
            "$days" "$hours" "$minutes" "$seconds"

    elif (( hours > 0 )); then
        printf "%dh %02dm %02ds" \
            "$hours" "$minutes" "$seconds"

    elif (( minutes > 0 )); then
        printf "%dm %02ds" \
            "$minutes" "$seconds"

    else
        printf "%ds" "$seconds"
    fi
}

###########################################
#               Logging                   #
###########################################

log_operation() {

    printf \
"%s,%s,%s,%s\n" \
"$(date '+%F %T')" \
"$1" \
"$2" \
"$3" \
>> "$LOGS_DIR/history.log"

}
