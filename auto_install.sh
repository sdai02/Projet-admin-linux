#!/bin/bash 

# manipule et affiche les partitions du disque /dev/sda

echo -e "label: gpt\n,1G,U\n,,L" |sfdisk /dev/sda


# chiffrement de la partition dev/sda2
cryptsetup luksFormat --batch-mode /dev/sda2
echo "azerty123" | cryptsetup open --type luks /dev/sda2 lvm

# creation d'un volume physique pour lvm
pvcreate /dev/mapper/lvm
vgcreate volgroup0 /dev/mapper/lvm

# Root 30G
lvcreate -L 30GB volgroup0 -n root

# VirtualBox 10G
lvcreate -L 10G volgroup0 -n vmsoftware

# Dossier partagé 5G
lvcreate -L 5G volgroup0 -n share

# Partition  chiffrée (LUKS) 10G
lvcreate -L 10G volgroup0 -n private

# Swap
lvcreate -L 4G volgroup0 -n swap

# Home
lvcreate -L 20G volgroup0 -n home

# chiffrement LUKS de private
cryptsetup luksFormat --batch-mode /dev/volgroup0/private

echo "azerty123" | cryptsetup open --type luks /dev/volgroup0/private secretproject

mkfs.ext4 /dev/mapper/secretproject


# Active les modules nécessaires
modprobe dm_mod
vgscan
vgchange -ay

# Formatatage des partitions
mkfs.fat -F 32 /dev/sda1
mkfs.ext4 /dev/volgroup0/root
mkfs.ext4 /dev/volgroup0/home
mkfs.ext4 /dev/volgroup0/vmsoftware
mkfs.ext4 /dev/volgroup0/share

# Montage des partitions
mount /dev/volgroup0/root /mnt
mkdir -p /mnt/boot /mnt/vmsoftware /mnt/share 
mount /dev/sda1 /mnt/boot
mount /dev/volgroup0/home /mnt/home
mount /dev/volgroup0/vmsoftware /mnt/vmsoftware
mount /dev/volgroup0/share /mnt/share

# Active le swap
mkswap /dev/volgroup0/swap
swapon /dev/volgroup0/swap

# Installation des paquets essentiels
pacstrap -i /mnt base linux linux-firmware

# Configuration du système
genfstab -U /mnt >> /mnt/etc/fstab

# Utilisation de EOF pour exécuter des programmes sur une seul block
arch-chroot /mnt <<EOF

# ajout du fuseau horaire

ls -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

hwclock --systohc

# configuration de la langue
locale-gen
echo "LANG=fr.UTF-8" > /etc/locale.conf


# configuration du hostname

echo "pc_de_travail" > /etc/hostname

# installation des paquets

pacman -S --noconfirm grub efibootmgr sudo networkmanager openssh vim wim git wget curl lightdm lightdm-gtk-greeter i3 dmenu xorg xorg-xinit xterm nitrogen picom rofi alacritty iproute2 firefox virtualbox virtualbox-host-modules-arch



grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 

grub-mkconfig -o /boot/grub/grub.cfg

# Création des utilisateurs et définir les droits d'acces

useradd -m -G wheel -s /bin/bash user
echo "user:azerty123" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

useradd -m -s /bin/bash study
echo "study:azerty123" | chpasswd


mkdir -p /mnt/share
chown user:study /mnt/share
chmod 770 /mnt/share
chown user:user /mnt/vmsoftware
chmod 700 /mnt/vmsoftware
usermod -aG vboxusers user

# Configuration de openssh
echo -e "Port 6769\nPermitRootLogin no\nPubkeyAuthentication yes\nPasswordAuthentication no" >> /etc/ssh/sshd_config.d/ssh.conf

ssh-keygen -t ed25519 

systemctl enable NetworkManager
systemctl enable sshd
systemctl start sshd

# Configuration de i3

mkdir -p /home/user/.config/i3 
cp /etc/i3/config /home/user/.config/i3/config
chown -R user:user /home/user/.config/i3

echo "exec i3" > /home/user/.xinitrc
chown user:user /home/user/.xinitrc

systemctl enable lightdm

sudo pacman -Syu

EOF

umount -R /mnt
swapoff -a
reboot