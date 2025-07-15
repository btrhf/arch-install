#!/bin/bash

set -euo pipefail

# Root Check
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root"
    exit 1

fi

# Load all function scripts
for file in ./functions/*.sh; do
    source "$file"
done

# v0.07
# TODO: fix errors in 0.07 (Priority)
# TODO: add systemd, GPU-Drives, etc

disk_selection
wipe_disk
partitioning
format_partitions
mount_partitions
if [[ -n "${SWAP_SIZE:-}" ]]; then
    create_mount_swap
fi
install_base_system
