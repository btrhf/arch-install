#!/bin/bash

set -euo pipefail

# Root Check
if [[ $EUID -ne 0 ]]; then
    echo "Please run as root"
    exit 1

fi

# v0.07
# TODO: fix errors in 0.07 (Priority)
# TODO: add systemd, GPU-Drives, etc

# Installing base system with fstab auto config
install_base_system() {
    echo "Installing base system with pacstrap..."
    pacstrap /mnt base linux linux-firmware vim nano sudo

    echo "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab

    if [[ -f /mnt/swapfile ]]; then
        echo "/swapfile none swap defaults 0 0" >> /mnt/etc/fstab
    fi

    echo "Installation complete. You can now chroot using:"
    echo "arch-chroot /mnt"

}

# Formatting partitions with a filesystem
format_filesystems_and_mount() {
    echo "Formatting filesystems..."

    mkfs.ext4 -F -L ROOT "$ROOT_PARTITION"
    mount "$ROOT_PARTITION" /mnt

    mkfs.fat -F32 -n EFI "$EFI_PARTITION"
    mkdir /mnt/boot
    mount "$EFI_PARTITION" /mnt/boot

    if [[ -n "${HOME_PARTITION:-}" ]]; then
        mkfs.ext4 -F -L HOME "$HOME_PARTITION"
        mkdir /mnt/home
        mount "$HOME_PARTITION" /mnt/home

    fi

    if [[ -n "${SWAP_SIZE:-}" ]]; then
        echo "Creating SWAP partition..."

        echo "Creating swap partition of ${SWAP_SIZE%G} GB"

        fallocate -l "$SWAP_SIZE" /mnt/swapfile
        chmod 600 /mnt/swapfile
        mkswap /mnt/swapfile
        swapon /mnt/swapfile
    
    fi
}

# Create HOME partition using parted
create_home_partition() {
    HOME_SIZE="$(( $(parted "$DISK" unit MiB print free | awk '/Free Space/ {e=$2} END {gsub("MiB","",e); print e}') / 1024 ))G"
    echo "Creating Home Partition of size $HOME_SIZE"

    HOME_END="$(parted "$DISK" unit MiB print free | awk '/Free Space/ {e=$2} END {gsub("MiB","",e); print e"M"}')"

    # Create HOME partition using parted
    parted --script "$DISK" mkpart primary ext4 "$ROOT_END" "$HOME_END"
    parted --script "$DISK" --name 3 "HOME"

    # Determine partition name
    if [[ $DISK =~ nvme ]]; then
        HOME_PARTITION="${DISK}p3"  # NVMe uses p1, p2...

    else
        HOME_PARTITION="${DISK}3"   # Standard disks use 1, 2...

    fi

    echo "Home partition created at: $HOME_PARTITION"

}

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
    if [[ $DISK =~ nvme ]]; then
        ROOT_PARTITION="${DISK}p2"  # NVMe uses p1, p2...

    else
        ROOT_PARTITION="${DISK}2"   # Standard disks use 1, 2...

    fi

    echo "Root partition created at: $ROOT_PARTITION"

}

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
    parted --script "$DISK" --name 1 "EFI"

    # Determine partition name
    if [[ $DISK =~ nvme ]]; then
        EFI_PARTITION="${DISK}p1"  # NVMe uses p1, p2...

    else
        EFI_PARTITION="${DISK}1"   # Standard disks use 1, 2...

    fi

    echo "EFI partition created at: $EFI_PARTITION"

}

partitioning() {
    local SWAP_CHOICE ROOT_CHOICE
    SEPARATE_HOME_PARTITION="n"

    echo "Starting partitioning..."

    # Creating EFI Partition
    create_efi_partition

    # Option to create swap partition
    while true; do
        read -rp "Do you want a swap partition? (y/n): " SWAP_CHOICE
        SWAP_CHOICE=$(echo "$SWAP_CHOICE" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase

        case "$SWAP_CHOICE" in
            y)
                echo "Creating swap partition..."
                while true; do
                    read -rp "Is hibernation required? (y/n, default: n): " HIBERNATION_REQUIRED
                    HIBERNATION_REQUIRED=$HIBERNATION_REQUIRED
                    case "$HIBERNATION_REQUIRED" in
                        y|n)
                            break
                            ;;

                        *)
                            echo "Invalid input. Please enter y or n."
                            sleep 3
                            continue
                            ;;

                    esac
                done
                set_swap_file
                break
                ;;

            n)
                echo "Skipping swap partition..."
                break
                ;;

            *)
                echo "Invalid input. Please enter y or n."
                sleep 3
                continue
                ;;

        esac
    done

    # Creating Root Partition
    while true; do
        read -rp "Do you want a combined root and home partition? (y/n): " ROOT_CHOICE
        ROOT_CHOICE=$(echo "$ROOT_CHOICE" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
        case "$ROOT_CHOICE" in
            y)
                echo "Creating root and home combined partition..."
                create_root_partition
                break
                ;;

            n)
                echo "Creating root partition..."
                read -rp "Do you want a home partition? (y/n): " SEPARATE_HOME_PARTITION
                SEPARATE_HOME_PARTITION=$(echo "$SEPARATE_HOME_PARTITION" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase

                create_root_partition

                while true; do
                    case "$SEPARATE_HOME_PARTITION" in
                        y)
                            echo "Creating home partition..."
                            create_home_partition
                            break
                            ;;

                        n)
                            echo "Do you want to select a home partition from pervious Install? (y/n): " 
                            echo "Skipping home partition..."
                            break
                            ;;

                        *)
                            echo "Invalid input. Please enter y or n."
                            sleep 3
                            continue
                            ;;

                    esac
                done
                break
                ;;

            *)
                echo "Invalid input. Please enter y or n."
                sleep 3
                continue
                ;;

        esac
    done

    echo "Partitioning Complete"
    lsblk -dpno NAME,SIZE,TYPE,MOUNTPOINT,LABEL
    sleep 3

}

wipe_disk() {
    echo "wiping $DISK..."

    # Create a new partition table (GPT format)
    parted --script "$DISK" mklabel gpt

    echo "Disk wiped successfully"

}

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

disk_selection
wipe_disk
partitioning
format_filesystems_and_mount
install_base_system
