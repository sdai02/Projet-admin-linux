#!/bin/bash

set -euo pipefail

# == FONCTIONS == #

create_partitions() {
    echo "== Mise à jour de la base de données des paquets =="
    pacman -Syy --noconfirm

    if [ -e /dev/sda1 ] && [ -e /dev/sda2 ] && [ -e /dev/sda3 ]; then
        echo "Les partitions existent déjà. Ignorer la création."
        return 0
    fi

    echo "== Création des partitions GPT sur /dev/sda =="
    echo -e "label: gpt\n,1G,U\n,4G,S\n,,L" | sfdisk /dev/sda
    partprobe /dev/sda
}

crypt_and_format_partitions() {
    echo "== Installation de cryptsetup et lvm2 =="
    pacman -Sy cryptsetup lvm2 --noconfirm

    echo "== Chiffrement de /dev/sda3 =="
    echo -n "azerty123" | cryptsetup luksFormat /dev/sda3 -
    echo -n "azerty123" | cryptsetup open /dev/sda3 lvm -

    echo "== Initialisation de LVM =="
    pvcreate /dev/mapper/lvm
    vgcreate volgroup0 /dev/mapper/lvm

    echo "== Création des volumes logiques =="
    lvcreate -L 30G volgroup0 -n root
    lvcreate -L 10G volgroup0 -n vmsoftware
    lvcreate -L 5G volgroup0 -n share
    lvcreate -L 10G volgroup0 -n private
    lvcreate -l 100%FREE volgroup0 -n home

    vgchange -ay
}

luks_and_format_private() {
    echo "== Chiffrement de volgroup0/private =="
    echo -n "azerty123" | cryptsetup luksFormat /dev/volgroup0/private -
    echo -n "azerty123" | cryptsetup open /dev/volgroup0/private secretproject -

    echo "== Formatage des partitions =="
    mkfs.fat -F32 /dev/sda1
    mkfs.ext4 /dev/volgroup0/root
    mkfs.ext4 /dev/volgroup0/home
    mkfs.ext4 /dev/volgroup0/vmsoftware
    mkfs.ext4 /dev/volgroup0/share
    mkfs.ext4 /dev/mapper/secretproject

    echo "== Configuration du swap =="
    mkswap /dev/sda2
    swapon /dev/sda2

    echo "== Montage des partitions =="
    mount /dev/volgroup0/root /mnt
    mkdir -p /mnt/{boot/efi,home,vmsoftware,share}
    mount /dev/sda1 /mnt/boot/efi
    mount /dev/volgroup0/home /mnt/home
    mount /dev/volgroup0/vmsoftware /mnt/vmsoftware
    mount /dev/volgroup0/share /mnt/share

    mkdir -p /mnt/home/private
    mount /dev/mapper/secretproject /mnt/home/private
}

mirroring() {
    echo "== Installation et configuration de reflector =="
    pacman -Sy reflector --noconfirm
    reflector --country France --protocol https --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
}

config() {
    echo "== Installation des paquets de base =="
    pacstrap -K /mnt base linux linux-firmware --noconfirm

    echo "== Génération de fstab =="
    genfstab -U /mnt >> /mnt/etc/fstab

    arch-chroot /mnt /bin/bash << 'EOF'

echo "== Configuration système =="
pacman -Syy --noconfirm

# Configuration clavier AZERTY pour initramfs
echo "KEYMAP=fr" > /etc/vconsole.conf

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf

echo "pc_de_travail" > /etc/hostname

echo "== Création des utilisateurs =="
useradd -m -G wheel -s /bin/bash admin
echo "admin:azerty123" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

useradd -m -s /bin/bash study
echo "study:azerty123" | chpasswd

mkdir -p /share
chown admin:study /share
chmod 770 /share

echo "== Installation de paquets complémentaires =="
pacman -S --noconfirm \
    grub efibootmgr sudo networkmanager openssh \
    vim git wget curl lightdm lightdm-gtk-greeter \
    i3 dmenu xorg xorg-xinit xterm nitrogen picom rofi \
    alacritty iproute2 firefox virtualbox virtualbox-host-modules-arch mtools

echo "== Configuration SSH =="
echo -e "Port 6769\nPermitRootLogin no\nPubkeyAuthentication yes\nPasswordAuthentication no" >> /etc/ssh/sshd_config
mkdir -p /home/admin/.ssh
ssh-keygen -t ed25519 -f /home/admin/.ssh/id_ed25519 -N ""
chown -R admin:admin /home/admin/.ssh

echo "== Configuration i3 =="
mkdir -p /home/admin/.config/i3
cp /etc/i3/config /home/admin/.config/i3/config
echo "exec i3" > /home/admin/.xinitrc
chown -R admin:admin /home/admin/.config /home/admin/.xinitrc

echo "== mkinitcpio HOOKS =="
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf

echo "== Regénération de l'initramfs =="
mkinitcpio -P

echo "== Configuration GRUB =="
sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT=".*"|GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=/dev/sda3:volgroup0 root=/dev/mapper/volgroup0-root"|' /etc/default/grub
echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
echo 'GRUB_TERMINAL_INPUT=console' >> /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --recheck
grub-mkconfig -o /boot/grub/grub.cfg

echo "== Activation des services =="
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

# == EXECUTION == #

create_partitions
crypt_and_format_partitions
luks_and_format_private
mirroring
config
reboot_system # <- Décommente ceci si tu veux rebooter à la fin automatiquement

echo "✅ Installation terminée avec succès !"
