#!/bin/bash

# Create EFI partition using parted
create_efi_partition() {
    EFI_SIZE="1G"  # Default EFI size is 1G if not provided

    echo "Creating EFI partition..."
    while true; do
        read -rp "Do you wanna set a custom size of EFI Partition? (Default: 1G): " EFI_RESPONSE

        if [[ -n "$EFI_RESPONSE" ]]; then
            if [[ "$EFI_RESPONSE" =~ ^[0-9]+M$ ]]; then
                EFI_SIZE="$EFI_RESPONSE"
                EFI_END="$EFI_RESPONSE"                        # User entered MB, no conversion needed
                break

            elif [[ "$EFI_RESPONSE" =~ ^[0-9]+G$ ]]; then
                EFI_SIZE="$EFI_RESPONSE"
                EFI_END="$(( ${EFI_RESPONSE%G} * 1024 ))M"     # Convert GB to MB
                break

            else
                echo "Invalid size format! Please enter a number followed by 'M' (MB) or 'G' (GB) (e.g., 512M, 1G)."
                sleep 3
                continue

            fi
        else
            EFI_END="$(( ${EFI_SIZE%G} * 1024 ))M"              # Convert GB to MB
            break

        fi
    done

    echo "Creating EFI Partition of size $EFI_SIZE"

    # Create EFI partition using parted
    parted --script "$DISK" mkpart ESP fat32 1MiB "$EFI_END"
    parted --script "$DISK" set 1 esp on
    parted --script "$DISK" name 1 "EFI"

    # Determine partition name
    if [[ "$DISK" =~ nvme ]]; then
        EFI_PARTITION="${DISK}p1"  # NVMe uses p1, p2...

    else
        EFI_PARTITION="${DISK}1"   # Standard disks use 1, 2...

    fi

    echo "EFI partition created at: $EFI_PARTITION"

}
