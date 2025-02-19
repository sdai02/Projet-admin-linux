# Installation et Configuration d'Arch Linux avec LVM, Chiffrement LUKS, VirtualBox, et i3

## Introduction

Ce script automatise l'installation et la configuration d'Arch Linux avec les éléments suivants :

- **Partitionnement GPT** du disque `/dev/sda`.
- **Chiffrement LUKS** de la partition pour la sécurité.
- **LVM** pour gérer dynamiquement les partitions.
- **Installation de VirtualBox** et des modules nécessaires.
- **Installation de l'environnement de bureau i3** avec `lightdm`.
- **Configuration d'un serveur SSH** sécurisé et d'un réseau avec `NetworkManager`.
- **Création de deux utilisateurs** avec des permissions spécifiques.

## Prérequis

Avant de commencer l'installation, assurez-vous que :

- Vous avez une image ISO d'Arch Linux démarrée en mode UEFI.
- Vous avez une connexion Internet fonctionnelle.
- Vous êtes à l'aise avec l'utilisation de la ligne de commande.

## Explication du script

Le script réalise les étapes suivantes :

### 1. **Partitionnement et chiffrage du disque**
   - Le disque `/dev/sda` est partitionné en GPT avec une partition de 1 Go pour le boot et le reste pour le système.
   - La partition `/dev/sda2` est chiffrée avec LUKS pour assurer la confidentialité des données.
   
### 2. **Création des volumes logiques avec LVM**
   - Un volume physique est créé sur la partition chiffrée, puis un groupe de volumes (`volgroup0`) est formé.
   - Plusieurs volumes logiques sont créés :
     - **root** (30 Go)
     - **vmsoftware** (10 Go, pour VirtualBox)
     - **share** (5 Go, pour les dossiers partagés)
     - **private** (10 Go, partition chiffrée)
     - **swap** (4 Go)
     - **home** (20 Go)

### 3. **Formater les partitions**
   - Les partitions sont formatées avec `ext4` (sauf la partition de démarrage qui est en `FAT32`).

### 4. **Installation des paquets nécessaires**
   - Le script installe les paquets de base pour Arch Linux (`base`, `linux`, `linux-firmware`).
   - Ensuite, il installe les paquets suivants :
     - **grub** pour l'installation du chargeur de démarrage.
     - **lightdm** et **i3** pour l'environnement graphique.
     - **NetworkManager** pour la gestion du réseau.
     - **VirtualBox** et ses modules pour l'hôte.
     - **OpenSSH**, **vim**, **git**, **wget**, **curl** pour les outils essentiels.
   
### 5. **Configuration du système**
   - Configuration du fuseau horaire, de la langue et du nom d'hôte.
   - Installation et configuration de `grub` pour le démarrage.
   - Création des utilisateurs `user` et `study` avec des permissions spécifiques.
   - Configuration sécurisée de SSH (port 7649, authentification par clé publique uniquement).
   
### 6. **Activation des services**
   - Activation de `NetworkManager`, `sshd` et `lightdm` pour démarrer automatiquement.
   - Ajout de l'utilisateur `user` au groupe `vboxusers` pour qu'il puisse utiliser VirtualBox sans problème.
   
### 7. **Redémarrage du système**
   - Une fois le script terminé, le système est redémarré pour appliquer les modifications.

## Instructions d'utilisation

### 1. **Téléchargement et préparation du script**
   - Téléchargez l'image ISO d'Arch Linux.
   - Démarrez à partir du live USB ou du support d'installation d'Arch Linux.
   - Copiez ce script sur votre système (`/root/arch_install.sh`).

### 2. **Exécution du script**
   - Connectez-vous en tant que root et exécutez le script :

     ```bash
     chmod +x /root/arch_install.sh
     /root/arch_install.sh
     ```

   Le script se chargera de tout, y compris la partition de votre disque, la configuration du système, l'installation de paquets et la configuration des utilisateurs.

### 3. **Redémarrage du système**
   - Une fois le script terminé, le système sera redémarré. Vous pourrez ensuite vous connecter avec les utilisateurs `admin` et `study`.

## Post-installation

### 1. **Accès SSH**
   - Le serveur SSH sera accessible sur le port 7649, avec une connexion par clé publique uniquement.
   - Générez une clé SSH avec `ssh-keygen -t ed25519` et copiez-la dans `~/.ssh/authorized_keys` sur l'utilisateur cible pour vous connecter.

### 2. **Utilisation de VirtualBox**
   - Après avoir ajouté l'utilisateur `admin` au groupe `vboxusers`, l'utilisateur pourra utiliser VirtualBox pour créer des machines virtuelles.
   
### 3. **Lancement de l'environnement i3**
   - Une fois que vous vous connectez en tant que `admin`, vous pouvez lancer l'environnement de bureau i3 en utilisant `startx` ou via le gestionnaire de connexion `lightdm`.

## Remarque importante

Assurez-vous de tester le script dans un environnement contrôlé (par exemple, une machine virtuelle ou un disque secondaire) avant de l'utiliser sur votre système principal. Le script partitionne et formate le disque, ce qui entraînera la perte de toutes les données existantes.

---

## Contributions

Si vous souhaitez améliorer ce script, n'hésitez pas à soumettre une **pull request** ou à signaler des problèmes via le système de suivi des problèmes.

