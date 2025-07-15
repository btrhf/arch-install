#!/bin/bash

set_swap_file() {
    while true; do
        RAM_SIZE=$(awk '/MemTotal/ {printf "%.0f", ($2 / 1024 / 1024) + 1}' /proc/meminfo)

        if [[ "$HIBERNATION_REQUIRED" == "y" ]]; then
            SWAP_SIZE="${RAM_SIZE}G"
            break

        elif [[ "$HIBERNATION_REQUIRED" == "n" ]];  then
            if (( RAM_SIZE <= "2" )); then
                SWAP_SIZE="4G"

            elif (( RAM_SIZE <= "8" )); then
                SWAP_SIZE="8G"

            elif (( RAM_SIZE <= "16" )); then
                SWAP_SIZE="16G"

            elif (( RAM_SIZE <= "32" )); then
                SWAP_SIZE="16G"

            elif (( RAM_SIZE <= "48" )); then
                SWAP_SIZE="24G"

            else
                SWAP_SIZE="32G"

            fi
            break
        else
            echo "Please enter correct input y or n."
            sleep 3
            continue

        fi
    done

}
