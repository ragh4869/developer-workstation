#!/bin/bash

docker_running() {

    docker info >/dev/null 2>&1

}

check_container() {

    if docker ps --format '{{.Names}}' | grep -q "^$1$"
    then
        success "$1"
    else
        error "$1"
    fi

}

container_count() {

    docker ps -q | wc -l

}
