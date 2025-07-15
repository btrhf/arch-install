#!/bin/bash

# Create HOME partition using parted
create_home_partition() {
    HOME_SIZE="$(( $(parted "$DISK" unit MiB print free | awk '/Free Space/ {e=$2} END {gsub("MiB","",e); print e}') / 1024 ))G"
    echo "Creating Home Partition of size $HOME_SIZE"

    HOME_END="$(parted "$DISK" unit MiB print free | awk '/Free Space/ {e=$2} END {gsub("MiB","",e); print e"M"}')"

    # Create HOME partition using parted
    parted --script "$DISK" mkpart primary ext4 "$ROOT_END" "$HOME_END"
    parted --script "$DISK" name 3 "HOME"

    # Determine partition name
    if [[ "$DISK" =~ nvme ]]; then
        HOME_PARTITION="${DISK}p3"  # NVMe uses p1, p2...

    else
        HOME_PARTITION="${DISK}3"   # Standard disks use 1, 2...

    fi

    echo "Home partition created at: $HOME_PARTITION"

}
