#!/bin/bash

get_container_state() {

    docker inspect \
        --format '{{.State.Status}}' \
        "$1" 2>/dev/null

}

get_container_health() {

    docker inspect \
        --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}N/A{{end}}' \
        "$1" 2>/dev/null

}

is_container_running() {

    [[ "$(get_container_state "$1")" == "running" ]]

}
