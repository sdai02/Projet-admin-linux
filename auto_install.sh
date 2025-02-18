#!/bin/bash 



loadkeys fr

timedatectl set-ntp true


# manipule et affiche les partitions du disque /dev/sda

echo -e "label: gpt\n,1G,ef00\n,4G,S\n,,L" |sfdisk /dev/sda


# chiffrement de la partition dev/sda3
cryptsetup luksFormat --batch-mode /dev/sda3
echo "azerty123" | cryptsetup open --type luks /dev/sda3 lvm

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

# Home
lvcreate -l 100%FREE volgroup0 -n home

# chiffrement LUKS de private
cryptsetup luksFormat --batch-mode /dev/volgroup0/private

echo "azerty123" | cryptsetup open --type luks /dev/volgroup0/private secretproject



# Formatatage des partitions
mkfs.fat -F 32 /dev/sda1
mkfs.ext4 /dev/volgroup0/root
mkfs.ext4 /dev/volgroup0/home
mkfs.ext4 /dev/volgroup0/vmsoftware
mkfs.ext4 /dev/volgroup0/share
mkfs.ext4 /dev/mapper/secretproject





# Montage des partitions
mount /dev/volgroup0/root /mnt
mkdir -p  /mnt/vmsoftware /mnt/share /mnt/home /mnt/private
mount /dev/volgroup0/home /mnt/home
mount /dev/volgroup0/vmsoftware /mnt/home/admin/vmsoftware
mount /dev/volgroup0/share /mnt/home/share
mount /dev/volgroup0/private /mnt/home/private


# Active le swap
mkswap /dev/sda2
swapon /dev/sda2

# Installation des paquets essentiels
pacstrap /mnt base --noconfirm

# Configuration du système
genfstab -U -p /mnt >> /mnt/etc/fstab

# Utilisation de EOF pour exécuter des programmes sur une seul block
arch-chroot /mnt <<EOF

# ajout du fuseau horaire

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime

hwclock --systohc

# configuration de la langue
locale-gen
echo "LANG=fr.UTF-8" > /etc/locale.conf


# configuration du hostname

echo "pc_de_travail" > /etc/hostname

# Création des utilisateurs et définir les droits d'acces

useradd -m -G wheel -s /bin/bash admin
echo "admin:azerty123" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

useradd -m -s /bin/bash study
echo "study:azerty123" | chpasswd

mkdir -p /mnt/home/share
chown admin:study /mnt/home/share
chmod 770 /mnt/share


# installation des paquets

pacman -S --noconfirm grub efibootmgr sudo networkmanager openssh vim git wget curl lightdm lightdm-gtk-greeter i3 dmenu xorg xorg-xinit xterm nitrogen picom rofi alacritty iproute2 firefox virtualbox virtualbox-host-modules-arch



# Configuration de openssh
echo -e "Port 6769\nPermitRootLogin no\nPubkeyAuthentication yes\nPasswordAuthentication no" >> /etc/ssh/sshd_config.d/ssh.conf

ssh-keygen -t ed25519 



# Configuration de i3

mkdir -p /home/user/.config/i3 
cp /etc/i3/config /home/user/.config/i3/config
chown -R admin:admin /home/user/.config/i3


echo "exec i3" > /home/user/.xinitrc
chown admin:admin /home/user/.xinitrc

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf


pacman -S linux linux-headers linux-lts linux-lts-headers


mkinitcpio -P

sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="cryptdevice=\/dev\/sda3:volgroup0"/' /etc/default/grub


mkdir /boot/EFI

mount /dev/sda1 /boot/EFI

grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=grub_uefi --recheck

echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/defautlt/grub

grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable lightdm
systemctl enable NetworkManager
systemctl enable sshd
systemctl start sshd

EOF

umount -a
reboot