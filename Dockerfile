FROM archlinux:latest

# Mettre à jour et installer archiso et git
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm archiso git

# Copier tous les fichiers locaux dans le conteneur dans /root/archiso
COPY . /root/archiso

# Définir le répertoire de travail
WORKDIR /root/archiso

# Commande par défaut au démarrage du conteneur
CMD ["bash"]
