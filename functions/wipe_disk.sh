#!/bin/bash

wipe_disk() {
    echo "wiping $DISK..."

    # Create a new partition table (GPT format)
    parted --script "$DISK" mklabel gpt

    echo "Disk wiped successfully"

}