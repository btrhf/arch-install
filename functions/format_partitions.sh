#!/bin/bash

# Formatting partitions with a filesystem
format_partitions() {
    echo "Formatting filesystems..."

    mkfs.ext4 -F -L ROOT "$ROOT_PARTITION"

    mkfs.fat -F32 -n EFI "$EFI_PARTITION"
    

    if [[ -n "${HOME_PARTITION:-}" ]]; then
        mkfs.ext4 -F -L HOME "$HOME_PARTITION"

    fi

}
