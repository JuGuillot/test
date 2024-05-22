#!/bin/bash

# Mettre à jour les paquets
apt-get update

# Installer les paquets nécessaires
apt-get install -y apache2 mysql-server php php-mysql php-curl php-gd php-xmlrpc php-mbstring

# Créer la base de données GLPI
mysql -u root -pAzerty1* -e "CREATE DATABASE glpidb;"
mysql -u root -pAzerty1* -e "GRANT ALL PRIVILEGES ON glpidb.* TO 'glpiuser'@'localhost' IDENTIFIED BY 'Azerty1*';"
mysql -u root -pAzerty1* -e "FLUSH PRIVILEGES;"

# Télécharger et extraire la dernière version de GLPI
GLPI_VERSION=$(wget -q -O - https://github.com/glpi-project/glpi/releases/latest | grep -Po '(?<=href=")[^"]*' | grep -Po '(?<=tag/)[^"]*')
cd /var/www/html/
wget -O glpi-$GLPI_VERSION.tgz https://github.com/glpi-project/glpi/releases/download/$GLPI_VERSION/glpi-$GLPI_VERSION.tgz
tar xvf glpi-$GLPI_VERSION.tgz
rm glpi-$GLPI_VERSION.tgz

# Copier le fichier de configuration
cp /path/to/your/config/file /var/www/html/glpi/config/
chown www-data:www-data /var/www/html/glpi/config/*

# Configurer Apache pour GLPI
cat > /etc/apache2/sites-available/glpi.conf << EOF
<VirtualHost *:80>
    ServerName pharmgreen.org
    ServerAlias www.pharmgreen.org
    DocumentRoot /var/www/html/glpi
    <Directory /var/www/html/glpi>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

a2ensite glpi.conf
a2dissite 000-default.conf
systemctl reload apache2

# Afficher un résumé des informations d'installation
echo -e "\nGLPI a été installé avec succès."
echo "Version de GLPI installée : $GLPI_VERSION"
echo "Nom de la base de données GLPI : glpidb"
echo "Nom d'utilisateur de la base de données GLPI : glpiuser"
echo "Mot de passe de la base de données GLPI : Azerty1*"

# Afficher l'adresse IP ou le nom de domaine de l'installation GLPI
GLPI_HOSTNAME=$(grep -Po '(?<=ServerName )[^ ]*' /etc/apache2/sites-available/glpi.conf)
GLPI_IP=$(host $GLPI_HOSTNAME | grep -Po '(?<=has address )[^ ]*')
if [ -z "$GLPI_IP" ]; then
    GLPI_IP=$(hostname -I | awk '{print $1}')
fi
echo -e "\nVous pouvez accéder à GLPI en utilisant l'adresse suivante :\n"
echo "http://$GLPI_IP"
if [ -n "$GLPI_HOSTNAME" ]; then
    echo "http://$GLPI_HOSTNAME"
fi
