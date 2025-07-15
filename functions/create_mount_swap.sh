#!/bin/bash

# Creates a swap file and activates it
create_mount_swap() {
    echo "Creating SWAP partition..."

    echo "Creating swap partition of ${SWAP_SIZE%G} GB"

    fallocate -l "$SWAP_SIZE" /mnt/swapfile
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
    swapon /mnt/swapfile

}
