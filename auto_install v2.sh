#!/bin/bash

set -euo pipefail

detect_firmware_type() {
    if [ -d /sys/firmware/efi ]; then
        echo "UEFI"
    else
        echo "BIOS"
    fi
}

detect_disk() {
    disk=$(lsblk -dno NAME,TYPE,SIZE | awk '$2 == "disk" {print $1, $3}' | sort -hrk2 | head -n 1 | awk '{print $1}')
    if [ -z "${disk:-}" ]; then
        echo "Erreur : Aucun disque dur détecté."
        exit 1
    fi

    
}
create_partitions() {

    if [[ $1 == "UEFI" ]]; then
        if [[ $2 == sda ]]; then
            echo "== Création des partitions GPT sur /dev/sda =="
            echo -e "label: gpt\n,1G,U\n,4G,S\n,,L" | sfdisk /dev/sda
            partprobe /dev/sda
        elif [[ $2 == nvme0n1 ]]; then
            echo "== Création des partitions GPT sur /dev/nvme0n1 =="
            echo -e "label: gpt\n,1G,U\n,4G,S\n,,L" | sfdisk /dev/nvme0n1
            partprobe /dev/nvme0n1
        else
            echo "Erreur : disque non reconnu."
            exit 1
        fi
    elif [[ $1 == "BIOS" ]]; then
        if [[ $2 == sda ]]; then
            echo "== Création des partitions MBR sur /dev/sda =="
            echo -e "label: dos\n,4G,82\n,,83,*" | sfdisk /dev/sda
            partprobe /dev/sda
        elif [[ $2 == nvme0n1 ]]; then
            echo "== Création des partitions MBR sur /dev/nvme0n1 =="
            echo -e "label: dos\n,4G,82\n,,83,*" | sfdisk /dev/nvme0n1
            partprobe /dev/nvme0n1
        else
            echo "Erreur : disque non reconnu."
            exit 1
        fi
    fi
}

crypt_and_format_partitions() {
    pacman -Sy --noconfirm cryptsetup lvm2

    if [[ $1 == sda ]]; then
        echo "== Chiffrement de /dev/sda3 =="
        echo -n "azerty123" | cryptsetup luksFormat /dev/sda3 -
        echo -n "azerty123" | cryptsetup open /dev/sda3 cryptlvm -
    elif [[ $1 == nvme0n1 ]]; then
        echo "== Chiffrement de /dev/nvme0n1p3 =="
        echo -n "azerty123" | cryptsetup luksFormat /dev/nvme0n1p3 -
        echo -n "azerty123" | cryptsetup open /dev/nvme0n1p3 cryptlvm -
    else
        echo "Erreur : disque non reconnu."
        exit 1
    fi

    pvcreate /dev/mapper/cryptlvm
    vgcreate volgroup0 /dev/mapper/cryptlvm

    if [[ $2 == "UEFI" ]]; then
        lvcreate -L 30G volgroup0 -n root
        lvcreate -L 10G volgroup0 -n vmsoftware
        lvcreate -l 100%FREE volgroup0 -n home
    elif [[ $2 == "BIOS" ]]; then
        lvcreate -L 30G volgroup0 -n root
        lvcreate -L 10G volgroup0 -n vmsoftware
        lvcreate -l 100%FREE volgroup0 -n home
    fi

    vgchange -ay
}

luks_and_format() {

    if [[ $1 == UEFI ]]; then
        if [[ $1 == sda ]]; then
            mkfs.fat -F32 /dev/sda1
            mkfs.ext4 /dev/volgroup0/root
            mkfs.ext4 /dev/volgroup0/home
            mkfs.ext4 /dev/volgroup0/vmsoftware
            mkswap /dev/sda2
            swapon /dev/sda2

            mount /dev/volgroup0/root /mnt
            mount --mkdir /dev/sda1 /mnt/boot
            mount --mkdir /dev/volgroup0/home /mnt/home
            mount --mkdir /dev/volgroup0/vmsoftware /mnt/vmsoftware
        elif [[ $1 == nvme0n1 ]]; then
            mkfs.fat -F32 /dev/nvme0n1p1
            mkfs.ext4 /dev/volgroup0/root
            mkfs.ext4 /dev/volgroup0/home
            mkfs.ext4 /dev/volgroup0/vmsoftware
            mkswap /dev/nvme0n1p2
            swapon /dev/nvme0n1p2

            mount /dev/volgroup0/root /mnt
            mount --mkdir /dev/nvme0n1p1 /mnt/boot
            mount --mkdir /dev/volgroup0/home /mnt/home
            mount --mkdir /dev/volgroup0/vmsoftware /mnt/vmsoftware
        else
            echo "Erreur : disque non reconnu."
            exit 1
        fi
    elif [[ $1 == BIOS ]]; then
        if [[ $1 == sda ]]; then
            mkfs.ext4 /dev/volgroup0/root
            mkfs.ext4 /dev/volgroup0/home
            mkfs.ext4 /dev/volgroup0/vmsoftware
            mkswap /dev/sda1
            swapon /dev/sda1
            mount /dev/volgroup0/root /mnt
            mkdir -p /mnt/boot
            mount --mkdir /dev/sda2 /mnt/boot
            mount --mkdir /dev/volgroup0/home /mnt/home
            mount --mkdir /dev/volgroup0/vmsoftware /mnt/vmsoftware
        elif [[ $1 == nvme0n1 ]]; then
            mkfs.ext4 /dev/volgroup0/root
            mkfs.ext4 /dev/volgroup0/home
            mkfs.ext4 /dev/volgroup0/vmsoftware
            mkswap /dev/nvme0n1p1
            swapon /dev/nvme0n1p1
            mount /dev/volgroup0/root /mnt
            mkdir -p /mnt/boot
            mount --mkdir /dev/nvme0n1p2 /mnt/boot
            mount --mkdir /dev/volgroup0/home /mnt/home
            mount --mkdir /dev/volgroup0/vmsoftware /mnt/vmsoftware
        else
            echo "Erreur : disque non reconnu."
            exit 1
        fi
    fi
}

mirroring() {
    pacman -Sy --noconfirm reflector
    reflector -c France -a 6 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Syyy --noconfirm
}

config() {
    pacstrap -K /mnt base linux linux-firmware systemd lvm2 efibootmgr networkmanager sudo openssh

    genfstab -U /mnt >> /mnt/etc/fstab


    if [[ $1 == UEFI ]]; then
        if [[ $2 == sda ]]; then
            CRYPT_UUID=$(blkid -s UUID -o value /dev/sda3)
        elif [[ $2 == nvme0n1 ]]; then
            CRYPT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p3)
        else
            echo "Erreur : disque non reconnu."
            exit 1
        fi
    elif [[ $1 == BIOS ]]; then
        if [[ $2 == sda ]]; then
            CRYPT_UUID=$(blkid -s UUID -o value /dev/sda2)
        elif [[ $2 == nvme0n1 ]]; then
            CRYPT_UUID=$(blkid -s UUID -o value /dev/nvme0n1p2)
        else
            echo "Erreur : disque non reconnu."
            exit 1
        fi
    fi

    arch-chroot /mnt /bin/bash <<EOF
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
echo 'fr_FR.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG=fr_FR.UTF-8' > /etc/locale.conf
echo 'KEYMAP=fr' > /etc/vconsole.conf
echo 'pc_de_travail' > /etc/hostname

echo '== crypttab =='
echo "cryptlvm UUID=$CRYPT_UUID none luks" > /etc/crypttab

echo '== mkinitcpio HOOKS =='
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck shutdown)/' /etc/mkinitcpio.conf
mkinitcpio -P

echo '== Bootloader systemd-boot =='
bootctl install

cat > /boot/loader/loader.conf <<LOADER
default arch
timeout 3
editor no
LOADER

cat > /boot/loader/entries/arch.conf <<ENTRY
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options cryptdevice=UUID=$CRYPT_UUID:cryptlvm root=/dev/mapper/volgroup0-root rw
ENTRY

echo '== Environnement graphique =='
pacman -S --noconfirm lightdm lightdm-gtk-greeter xorg i3 dmenu xterm xorg-xinit vim git wget curl nitrogen picom rofi alacritty iproute2 firefox virtualbox virtualbox-host-modules-arch mtools

echo '== Utilisateurs =='
useradd -m -G wheel -s /bin/bash admin
echo 'admin:azerty123' | chpasswd

echo 'root:azerty123' | chpasswd
chsh -s /bin/bash root

echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers


echo '== SSH =='
echo -e 'Port 6769\nPermitRootLogin no\nPubkeyAuthentication yes\nPasswordAuthentication no' >> /etc/ssh/sshd_config
mkdir -p /home/admin/.ssh
ssh-keygen -t ed25519 -f /home/admin/.ssh/id_ed25519 -N ''
chown -R admin:admin /home/admin/.ssh

echo '== Config i3 =='
mkdir -p /home/admin/.config/i3
cp /etc/i3/config /home/admin/.config/i3/config
echo 'exec i3' > /home/admin/.xinitrc
chown -R admin:admin /home/admin/.config /home/admin/.xinitrc

systemctl enable lightdm
systemctl enable NetworkManager
systemctl enable sshd
EOF
}

reboot_system() {
    echo "== Démontage et redémarrage =="
    umount -R /mnt
    reboot
}

# === EXÉCUTION ===
disks=$(detect_disk)
firmware_type=$(detect_firmware_type)
create_partitions "$firmware_type" "$disks"
crypt_and_format_partitions "$firmware_type" "$disks"
luks_and_format "$firmware_type" "$disks"
mirroring
config "$firmware_type" "$disks"
reboot_system

echo "✅ Installation Arch Linux terminée avec succès !"
