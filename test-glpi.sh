#!/bin/bash

# Lire les informations de configuration à partir du fichier texte
db_name=$(grep "^db_name" config.txt | cut -d "=" -f 2 | xargs)                     # pharmgreen.glpi
db_user=$(grep "^db_user" config.txt | cut -d "=" -f 2 | xargs)                     # wilder
db_pass=$(grep "^db_pass" config.txt | cut -d "=" -f 2 | xargs)                     # Azerty1*
network_interface=$(grep "^network_interface" config.txt | cut -d "=" -f 2 | xargs) #enp0s8

# Installation des paquets

apt update && apt upgrade -y
apt install php-xml php-common php-json php-mysql php-mbstring php-curl php-gd php-intl php-zip php-bz2 php-imap php-apcu -y
apt install apache2 php mariadb-server -y

# Mariadb et mettre yes à tout

mysql_secure_installation

# Création BDD mysql

#mysql -u root -p
mysql -e "CREATEDATABASE $db_name"
mysql -e "GRANT ALL PRIVILEGES ON $db_name TO $db_user IDENTIFIED BY "db_pass""
mysql -e "FLUSH PRIVILEGES"
#mysql -e "EXIT"

# Télécharger GLPI

cd /tmp

wget https://github.com/glpi-project/glpi/releases/download/10.0.15/glpi-10.0.15.tgz

tar -xzvf glpi-10.0.15.tgz -C /var/www/

# Attribuer permissions

chown www-data /var/www/glpi/ -R

# Création des dossiers

mkdir /etc/glpi
chown www-data /etc/glpi/
mv /var/www/glpi/config /etc/glpi

mkdir /var/lib/glpi
chown www-data /var/lib/glpi/
mv /var/www/glpi/files /var/lib/glpi

mkdir /var/log/glpi
chown www-data /var/log/glp

# Création fichiers de configuration

touch /var/www/glpi/inc/downstream.php

cat >/var/www/glpi/inc/downstream.php <<EOF
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
EOF

touch /etc/glpi/local_define.php

cat >/etc/glpi/local_define.php <<EOF
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi/files');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOF

# Préparation config Apache2

touch /etc/apache2/sites-available/support.pharmgreen.org

cat >/etc/apache2/sites-available/support.pharmgreen.org <<EOF
<VirtualHost *:80>
    ServerName pharmgreen.org

    DocumentRoot /var/www/glpi/public

    <Directory /var/www/glpi/public>
        Require all granted

        RewriteEngine On

        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>
    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.2-fpm.sock|fcgi://localhost/"
    </FilesMatch>
</VirtualHost>
EOF

a2ensite support.phamrgreen.org

a2dissite 000-default.conf

a2enmod rewrite

systemctl restart apache2

# Utilisation de php8.2-fpm

apt-get install php8.2-fpm -y

sudo a2enmod proxy_fcgi setenvif
sudo a2enconf php8.2-fpm
sudo systemctl reload apache2

sed -i 's/^\(session\.cookie_httponly\s*=\s*\).*/\1on/' /etc/php/8.2/fpm/php.ini

systemctl restart php8.2-fpm.service

sudo systemctl restart apache2
