#!/bin/bash

disk_selection() {
    while true; do
        # List available disks
        echo "Available disks:"
        lsblk -dpno NAME,SIZE,MODEL

        # Ask user to select a disk
        read -p "Enter the disk to partition (e.g., /dev/sdX or /dev/nvme0n1): " DISK

        # Confirm selection
        echo "Selected disk: $DISK"
        read -rp "Are you sure? This will erase all data on $DISK! (y/n): " CONFIRM
        CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')      # Convert to lowercase

        case "$CONFIRM" in
            y)
                # Get disk size
                DISK_SIZE=$(parted "$DISK" unit MiB print | awk '/Disk/ {print $3}' | sed 's/MiB//')
                echo "Using Disk: $DISK"
                echo "Disk Size: $DISK_SIZE"
                break
                ;;

            n)
                echo "Aborted."
                exit 1
                ;;

            *)
                echo "Please select correct input yes or no."
                sleep 3
                continue
                ;;

        esac
    done
}
