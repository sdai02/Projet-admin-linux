#!/bin/bash

set -euo pipefail

create_partitions() {
    echo "== Création des partitions GPT sur /dev/sda =="
    echo -e "label: gpt\n,1G,U\n,4G,S\n,,L" | sfdisk /dev/sda
    partprobe /dev/sda
}

crypt_and_format_partitions() {
    pacman -Sy --noconfirm cryptsetup lvm2

    echo "== Chiffrement de /dev/sda3 =="
    echo -n "azerty123" | cryptsetup luksFormat /dev/sda3 -
    echo -n "azerty123" | cryptsetup open /dev/sda3 cryptlvm -

    pvcreate /dev/mapper/cryptlvm
    vgcreate volgroup0 /dev/mapper/cryptlvm

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

    mkfs.fat -F32 /dev/sda1
    mkfs.ext4 /dev/volgroup0/root
    mkfs.ext4 /dev/volgroup0/home
    mkfs.ext4 /dev/volgroup0/vmsoftware
    mkfs.ext4 /dev/volgroup0/share
    mkfs.ext4 /dev/mapper/secretproject
    mkswap /dev/sda2
    swapon /dev/sda2

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
    pacman -Sy --noconfirm reflector
    reflector -c France -a 6 --sort rate --save /etc/pacman.d/mirrorlist
    pacman -Syyy --noconfirm
}

config() {
    pacstrap -K /mnt base linux linux-firmware systemd lvm2 efibootmgr networkmanager sudo openssh

    genfstab -U /mnt >> /mnt/etc/fstab

    CRYPT_UUID=$(blkid -s UUID -o value /dev/sda3)
    PRIVATE_UUID=$(blkid -s UUID -o value /dev/volgroup0/private)

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
echo "secretproject UUID=$PRIVATE_UUID none luks" >> /etc/crypttab

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
useradd -m -s /bin/bash study
echo 'study:azerty123' | chpasswd

echo 'root:azerty123' | chpasswd
chsh -s /bin/bash root

echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

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
create_partitions
crypt_and_format_partitions
luks_and_format_private
mirroring
config
reboot_system

echo "✅ Installation Arch Linux terminée avec succès !"
