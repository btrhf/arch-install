#!/bin/bash

# Installing base system with fstab auto config
install_base_system() {
    echo "Installing base system with pacstrap..."
    pacstrap /mnt base linux linux-firmware vim nano sudo

    echo "Generating fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab

    echo "Installation complete. You can now chroot using:"
    echo "arch-chroot /mnt"

}
