#!/bin/bash 


lsblk -f
cat /etc/passwd /etc/group /etc/fstab /etc/mtab
echo $HOSTNAME
grep -i installed /var/log/pacman.log