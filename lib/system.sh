#!/bin/bash

show_cpu() {

    echo "CPU:"
    nproc
    echo

}

show_memory() {

    echo "Memory:"
    free -h
    echo

}

show_disk() {

    echo "Disk:"
    df -h /
    echo

}
