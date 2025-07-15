#!/bin/bash

# Mount patitions to respective locations
mount_partitions() {
    echo "Mounting filesystems..."
    mount "$ROOT_PARTITION" /mnt
    mkdir /mnt/boot
    mount "$EFI_PARTITION" /mnt/boot

    if [[ -n "${HOME_PARTITION:-}" ]]; then
        mkdir /mnt/home
        mount "$HOME_PARTITION" /mnt/home

    fi

}
