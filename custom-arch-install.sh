#!/bin/bash
set -x

##############################
# Step 1: Disk Selection     #
##############################

# Display current disk struture.
echo "Available Disks:"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

# Request the partition/drive name to be used for the install.
echo "Enter the drive to install Arch on (e.g., /dev/sda, /dev/nvme0n1):"
read disk

# Prompt to zap the drive or not.
echo "Do you want to completely wipe (zap) $disk? This WILL DELETE ALL DATA! (yes/no)"
read zap_choice
if [[ "$zap_choice" == "yes" ]]; then   # If the choice is yes.
    echo "Wiping $disk..."
    sudo gdisk $disk <<EOF
x
z
Y
Y
EOF
    echo "Disk wiped successfully."
else                                    # If the choice is no.
    echo "Skipping disk wipe..."
fi

#####################################
# Step 2: Partitioning Selection    #
#####################################

# Option for desired partitioning methord.
echo "Choose partitioning method:"
echo "1) Recommended (Auto-Partition: EFI + Swap + Root/Home based on choice)"  # Automatic good for beginners.
echo "2) Manual (Launch cgdisk)"                                                # Manual for intermediate to expert users.
read -p "Enter choice (1 or 2): " partition_choice

if [[ "$partition_choice" == "1" ]]; then               # If the choice is 1 (Recommended).
    echo "Setting up recommended partitioning..."

    # Create EFI Boot Partition (1 GiB)
    echo "Creating 1GiB EFI Boot partition..."
    sudo gdisk $disk <<EOF
n


+1G
ef00
w
Y
EOF
    efi_partition="${disk}1"

    # Option for Swap Partition
    echo "Do you want a swap partition? (y/n)"
    read swap_choice
    if [[ "$swap_choice" == "y" ]]; then
        echo "How much RAM do you have? (in GB)"
        read ram_size

        if (( ram_size <= 2 )); then
            swap_size="4G"
        elif (( ram_size <= 8 )); then
            swap_size="8G"
        elif (( ram_size <= 16 )); then
            swap_size="16G"
        elif (( ram_size <= 32 )); then
            swap_size="16G"
        elif (( ram_size <= 48 )); then
            swap_size="24G"
        else
            swap_size="32G"
        fi

        echo "Recommended swap size: $swap_size"
        echo "Enter swap size (or press Enter to accept $swap_size):"
        read user_swap_size
        swap_size=${user_swap_size:-$swap_size}

        echo "Creating Swap partition of size $swap_size..."
        sudo gdisk $disk <<EOF
n


+$swap_size
8200
w
Y
EOF
        swap_partition="${disk}2"
    fi

    # Option for Separate /home Partition
    echo "Do you want a separate /home partition? (y/n)"
    read home_choice
    if [[ "$home_choice" == "y" ]]; then
        echo "Creating 80GiB Root partition and allocating ALL remaining space to /home..."
        sudo gdisk $disk <<EOF
n


+80G
8300
n



8300
w
Y
EOF
    
        if [[ "$swap_choice" == "y" ]]; then    
            root_partition="${disk}3"
            home_partition="${disk}4"
        else
            root_partition="${disk}2"
            home_partition="${disk}3"
        fi
    
    else
        echo "Using remaining space for Root (/)."
        sudo gdisk $disk <<EOF
n



8300
w
Y
EOF
        
        if [[ "$swap_choice" == "y" ]]; then    
            root_partition="${disk}3"
        else
            root_partition="${disk}2"
        fi
        
    fi

elif [[ "$partition_choice" == "2" ]]; then             # If the choice is 2 (Manual).
    echo "Launching cgdisk... Please manually create your partitions."
    sleep 5
    sudo cgdisk $disk

    echo "Updated Disk Layout (After Partitioning):"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT

    echo "Enter the root partition (e.g., /dev/sda2, /dev/nvme0n1p2):"
    read root_partition
    echo "Enter the EFI partition (e.g., /dev/sda1, /dev/nvme0n1p1):"
    read efi_partition
    echo "Enter the swap partition (optional, press Enter to skip):"
    read swap_partition
    echo "Enter the home partition (optional, press Enter to skip):"
    read home_partition
fi

########################################
# Step 3: Format and Mount Partitions  #
########################################

echo "Formatting partitions..."
sudo mkfs.ext4 $root_partition
sudo mkfs.fat -F32 $efi_partition
if [[ -n "$swap_partition" ]]; then
    sudo mkswap $swap_partition
    sudo swapon $swap_partition
fi
if [[ -n "$home_partition" ]]; then
    sudo mkfs.ext4 $home_partition
fi

echo "Mounting partitions..."
sudo mount $root_partition /mnt
sudo mkdir -p /mnt/boot
sudo mount $efi_partition /mnt/boot
if [[ -n "$home_partition" ]]; then
    sudo mkdir -p /mnt/home
    sudo mount $home_partition /mnt/home
fi

echo "Partitions formatted and mounted successfully!"

####################################
# Step 4: Install Base System      #
####################################

echo "Installing base system..."
sudo pacstrap /mnt base linux linux-firmware grub efibootmgr

echo "Generating fstab..."
sudo genfstab -U /mnt >> /mnt/etc/fstab

##########################################################
# Step 5: Collect User Inputs for System Configuration   #
##########################################################

# These inputs are collected before chrooting to avoid issues with here-documents.

echo "Enter a hostname for this machine:"
read hostname

echo "Enter root password:"
read rootpw

echo "Enter a username for your account:"
read username

echo "Enter password for your account:"
read userpw

echo "Available Regions:"
ls /usr/share/zoneinfo/
echo "Enter your region (e.g., America, Europe, Asia):"
read region

# Validate region exists
if [ ! -d "/usr/share/zoneinfo/$region" ]; then
    echo "Region /usr/share/zoneinfo/$region does not exist. Exiting."
    exit 1
fi

echo "Available Cities in $region:"
ls /usr/share/zoneinfo/$region
echo "Enter your city (e.g., New_York, London, Kolkata):"
read city

echo "Available Locales (Press '/' to search, 'q' to exit):"
cat /etc/locale.gen | grep -v '^#' | awk '{print $1}' | less
echo "Enter your preferred locale (e.g., en_US.UTF-8, de_DE.UTF-8, fr_FR.UTF-8):"
read lang_choice

##########################################################
# Step 6: Configure the System in arch-chroot           #
##########################################################

echo "Chrooting into the new system..."
arch-chroot /mnt /bin/bash <<EOT
echo "Setting up system..."

echo "LANG=$lang_choice" > /etc/locale.conf
echo "$lang_choice UTF-8" >> /etc/locale.gen
locale-gen

ln -sf /usr/share/zoneinfo/$region/$city /etc/localtime
hwclock --systohc

echo "$hostname" > /etc/hostname

echo "Setting root password..."
echo "root:$rootpw" | chpasswd

useradd -m -G wheel -s /bin/bash "$username"
echo "Setting password for $username..."
echo "$username:$userpw" | chpasswd
EOT

##################################
# Step 7: Bootloader Installation#
##################################

echo "Installing GRUB bootloader..."
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

###############################
# Step 8: Enable Networking   #
###############################

echo "Enabling networking..."
arch-chroot /mnt systemctl enable NetworkManager

echo "Arch Linux installation complete! Reboot now."
