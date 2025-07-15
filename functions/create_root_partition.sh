#!/bin/bash

# Create ROOT partition using parted
create_root_partition() {
    while true; do
        if [[ "$SEPARATE_HOME_PARTITION" == "y" ]]; then
            ROOT_SIZE="120G"
            read -rp "Please enter the size for your root partition. (default: 120G)" ROOT_RESPONSE

            if [[ -n "$ROOT_RESPONSE" ]]; then
                if [[ "$ROOT_RESPONSE" =~ ^[0-9]+M$ ]]; then
                    ROOT_SIZE="$ROOT_RESPONSE"
                    ROOT_END="$ROOT_RESPONSE"                                   # User entered MB, no conversion needed
                    break

                elif [[ "$ROOT_RESPONSE" =~ ^[0-9]+G$ ]]; then
                    ROOT_SIZE="$ROOT_RESPONSE"
                    ROOT_END="$(( ${ROOT_RESPONSE%G} * 1024 ))M"     # Convert GB to MB
                    break

                else
                    echo "Invalid size format! Please enter a number followed by 'M' (MB) or 'G' (GB) (e.g., 512M, 1G)."
                    sleep 3
                    continue

                fi
            else
                ROOT_END="$(( ${ROOT_SIZE%G} * 1024 ))M"              # Convert GB to MB
                break

            fi
        elif [[ "$SEPARATE_HOME_PARTITION" == "n" ]]; then
            ROOT_END=$(parted "$DISK" unit MiB print free | awk '/Free Space/ {e=$2} END {gsub("MiB","",e); print e}')
            FREE_SIZE=$(parted "$DISK" unit MiB print free | awk '/Free Space/ {s=$3} END {gsub("MiB","",s); print s}')
            ROOT_SIZE="$(( (FREE_SIZE - ${EFI_END//M/}) / 1024 ))G"
            break

        fi
    done

    echo "Creating Root Partition of size $ROOT_SIZE"

    # Create ROOT partition using parted
    parted --script "$DISK" mkpart primary ext4 "$EFI_END" "$ROOT_END"
    parted --script "$DISK" name 2 "ROOT"

    # Determine partition name
    if [[ "$DISK" =~ nvme ]]; then
        ROOT_PARTITION="${DISK}p2"  # NVMe uses p1, p2...

    else
        ROOT_PARTITION="${DISK}2"   # Standard disks use 1, 2...

    fi

    echo "Root partition created at: $ROOT_PARTITION"

}
