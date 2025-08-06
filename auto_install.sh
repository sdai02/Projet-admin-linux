#!/bin/bash

set -euo pipefail

create_partitions() {
    echo "== Création des partitions GPT sur /dev/sda =="
    echo -e "label: gpt\n,1G,U\n,4G,S\n,,L" | sfdisk /dev/sda
    partprobe /dev/sda
}

crypt_and_format_partitions() {
    echo "== Installation de cryptsetup et lvm2 =="
    pacman -Sy --noconfirm cryptsetup lvm2

    echo "== Chiffrement de /dev/sda3 =="
    echo -n "azerty123" | cryptsetup luksFormat /dev/sda3 -
    echo -n "azerty123" | cryptsetup open /dev/sda3 cryptlvm -

    echo "== Initialisation de LVM =="
    pvcreate /dev/mapper/cryptlvm
    vgcreate volgroup0 /dev/mapper/cryptlvm

    echo "== Création des volumes logiques =="
    lvcreate -L 30G volgroup0 -n root
    lvcreate -L 10G volgroup0 -n vmsoftware
    lvcreate -L 5G volgroup0 -n share
    lvcreate -L 10G volgroup0 -n private
    lvcreate -l 100%FREE volgroup0 -n home

    vgchange -ay
}

luks_and_format_private() {
    echo -n "azerty123" | cryptsetup luksFormat /dev/volgroup0/private -
    echo -n "azerty123" | cryptsetup open /dev/volgroup0/private secretproject -

    echo "== Formatage =="
    mkfs.fat -F32 /dev/sda1
    mkfs.ext4 /dev/volgroup0/root
    mkfs.ext4 /dev/volgroup0/home
    mkfs.ext4 /dev/volgroup0/vmsoftware
    mkfs.ext4 /dev/volgroup0/share
    mkfs.ext4 /dev/mapper/secretproject
    mkswap /dev/sda2
    swapon /dev/sda2

    echo "== Montage =="
    mount /dev/volgroup0/root /mnt
    mkdir -p /mnt/boot
    mount /dev/sda1 /mnt/boot
    mkdir -p /mnt/{home,vmsoftware,share}
    mount /dev/volgroup0/home /mnt/home
    mount /dev/volgroup0/vmsoftware /mnt/vmsoftware
    mount /dev/volgroup0/share /mnt/share
    mkdir -p /mnt/home/private
    mount /dev/mapper/secretproject /mnt/home/private
}

mirroring() {
    echo "== Configuration des miroirs =="
    pacman -Sy --noconfirm reflector
    reflector -c France -a 6 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Syyy --noconfirm
}

config() {
    echo "== Installation des paquets de base =="
    pacstrap -K /mnt base linux linux-firmware systemd lvm2 efibootmgr networkmanager sudo openssh

    echo "== Génération de fstab =="
    genfstab -U /mnt >> /mnt/etc/fstab

    # Récupération des UUID avant chroot
    CRYPT_UUID=$(blkid -s UUID -o value /dev/sda3)
    ROOT_UUID=$(blkid -s UUID -o value /dev/mapper/volgroup0-root)

    # Passage des variables dans l'environnement chroot
    arch-chroot /mnt /bin/bash -c "
export CRYPT_UUID='$CRYPT_UUID'
export ROOT_UUID='$ROOT_UUID'

echo '== Configuration système =='
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
echo 'fr_FR.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG=fr_FR.UTF-8' > /etc/locale.conf
echo 'KEYMAP=fr' > /etc/vconsole.conf
echo 'pc_de_travail' > /etc/hostname

echo '== mkinitcpio HOOKS =='
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -p linux

echo '== Installation du bootloader =='
bootctl install

cat > /boot/loader/loader.conf <<BOOTEOF
default arch
timeout 3
editor no
BOOTEOF

cat > /boot/loader/entries/arch.conf <<ENTRYEOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options cryptdevice=UUID=\$CRYPT_UUID:cryptlvm root=UUID=\$ROOT_UUID rw
ENTRYEOF

mkdir -p /boot/EFI/BOOT
cp /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/BOOT/BOOTX64.EFI

echo '== Environnement graphique =='
pacman -S --noconfirm lightdm lightdm-gtk-greeter xorg i3 dmenu xterm xorg-xinit vim git wget curl nitrogen picom rofi alacritty iproute2 firefox virtualbox virtualbox-host-modules-arch mtools

echo '== Utilisateurs =='
useradd -m -G wheel -s /bin/bash admin
echo 'admin:azerty123' | chpasswd
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

useradd -m -s /bin/bash study
echo 'study:azerty123' | chpasswd

mkdir -p /share
chown admin:study /share
chmod 770 /share

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

echo '== Services =='
systemctl enable lightdm
systemctl enable NetworkManager
systemctl enable sshd
"
}


reboot_system() {
    echo "== Démontage et redémarrage =="
    umount -R /mnt
    reboot
}

# == EXÉCUTION == #
create_partitions
crypt_and_format_partitions
luks_and_format_private
mirroring
config
reboot_system

echo "✅ Installation Arch Linux terminée sans erreur !"
