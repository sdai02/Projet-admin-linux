#!/bin/bash 

# liste le type de stockage present sur le pc

lsblk

# manipule et affiche les partitions du disque /dev/sda

fdisk /dev/sda

g

# boot 1G

n 

1



+1G



# LVM (chiffré avec LUKS) Tout le reste

n

/
/
/

# Change de type de partition

# partition 3
t
/
44

# partition 2

t 
2
82

# partition 1 
t
1
1

# formater les partitions 

w

# Le reste de la portition 

cryptsetup luksFormat /dev/sda3

YES

azerty123

# ouvrir le /dev/sda3

cryptsetup open --type luks /dev/sda3 lvm

# creation d'un volume physique pour lvm

pvcreate /dev/mapper/lvm
vgcreate volgroup0 /dev/mapper/lvm



# root 35G

lvcreate -L 40GB volgroup0 -n root

# virtualBox 10G

lvcreate -L 10G volgroup0 -n vb

# Dossier partagé 5G

lvcreate -L 5G volgroup0 -n share

# Partition  chiffrée (LUKS) 10G

lvcreate -L 10G volgroup0 -n private

# swap

lvcreate -L 4G volgroup0 -n swap

modprobe dm_mod
vgscan
vgchange -ay

# boot

mkfs.fat -F 32 /dev/sda1

mkfs.ext4 /dev/volgroup0/root

mkfs.ext4 /dev/volgroup0/home

mkfs.ext4 /dev/volgroupe/vmsoftware

mkfs.ext4 /dev/volgroupe/share

mkfs.ext4 /dev/volgroupe/private



mount /dev/volgroup0/root /mnt

mkdir -p /mnt/boot /mnt/vmsoftware /mnt/share /mnt/swap

mount /dev/sda1 /mnt/boot
mount /dev/volgroup0/home /mnt/home
mount /dev/volgroup0/vmsoftware /mnt/vmsoftware
mount /dev/volgroup0/share /mnt/share

cryptsetup luksFormat /dev/volgroup0/private

YES

azerty123
cryptsetup open --type luks /dev/sda3 secretproject

mkfs.ext4 /dev/mapper/secretproject


mkswap /dev/volgroup0/swap
swapon /dev/volgroup0/swap



pacstrap -i /mnt base linux linux-firmware

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

