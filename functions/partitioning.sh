#!/bin/bash

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
                            # TODO: Implement logic to select previous /home partition manually
                            # read -rp "Do you want to select a home partition from previous Install? (y/n): " HOME_PARTITION
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
