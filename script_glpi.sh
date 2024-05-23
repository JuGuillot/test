#!/bin/bash

# Vérifier que le fichier de configuration existe
if [ ! -f config.txt ]; then
  echo "Le fichier de configuration config.txt n'existe pas !"
  exit 1
fi

# Lire les informations de configuration à partir du fichier
db_name=$(grep "^db_name" config.txt | cut -d "=" -f 2 | xargs)
db_user=$(grep "^db_user" config.txt | cut -d "=" -f 2 | xargs)
db_pass=$(grep "^db_pass" config.txt | cut -d "=" -f 2 | xargs)
glpi_url=$(grep "^glpi_url" config.txt | cut -d "=" -f 2 | xargs)

# Vérifier que les variables ne sont pas vides
if [ -z "$db_name" ] || [ -z "$db_user" ] || [ -z "$db_pass" ] || [ -z "$glpi_url" ]; then
  echo "Une ou plusieurs variables de configuration sont manquantes dans config.txt !"
  exit 1
fi

# Installer les dépendances nécessaires
apt-get update
apt-get install -y apache2 mysql-server php php-mysql php-curl php-gd php-xmlrpc wget tar

# Configurer la base de données
mysql -e "CREATE DATABASE IF NOT EXISTS $db_name;"
mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"
mysql -e "FLUSH PRIVILEGES;"

# Télécharger et extraire GLPI
wget https://github.com/glpi-project/glpi/releases/download/10.0.6/glpi-10.0.6.tgz
tar -xvf glpi-10.0.6.tgz
mv glpi /var/www/html/

# Configurer Apache
echo "
<VirtualHost *:80>
  ServerName $glpi_url
  DocumentRoot /var/www/html/glpi
  <Directory /var/www/html/glpi>
    AllowOverride All
    Order allow,deny
    Allow from all
  </Directory>
</VirtualHost>
" > /etc/apache2/sites-available/glpi.conf

a2ensite glpi
a2enmod rewrite
service apache2 restart

# Configurer GLPI
echo "<?php
define('DB_NAME', '$db_name');
define('DB_USER', '$db_user');
define('DB_PASS', '$db_pass');
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_TYPE', 'mysqli');
?>" > /var/www/html/glpi/config/config_db.php

chown -R www-data:www-data /var/www/html/glpi

echo "L'installation de GLPI est terminée !"
