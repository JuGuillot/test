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
network_interface=$(grep "^network_interface" config.txt | cut -d "=" -f 2 | xargs)

# Vérifier que les variables ne sont pas vides
if [ -z "$db_name" ] || [ -z "$db_user" ] || [ -z "$db_pass" ] || [ -z "$network_interface" ]; then
  echo "Une ou plusieurs variables de configuration sont manquantes dans config.txt !"
  exit 1
fi

# Récupérer l'adresse IP de l'interface spécifiée
ip_address=$(ip addr show $network_interface | grep "inet " | awk '{print $2}' | cut -d/ -f1)

# Vérifier que l'adresse IP a été récupérée
if [ -z "$ip_address" ]; then
  echo "Impossible de récupérer l'adresse IP de l'interface $network_interface !"
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
  ServerAlias $ip_address
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
config_file="/var/www/html/glpi/config/config_db.php"

echo "<?php
define('DB_NAME', '$db_name');
define('DB_USER', '$db_user');
define('DB_PASS', '$db_pass');
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_TYPE', 'mysqli');
?>" > $config_file

# Vérifier que le fichier a été correctement créé
if [ ! -f $config_file ]; then
  echo "Le fichier de configuration de la base de données n'a pas été créé correctement !"
  exit 1
fi

# Définir les permissions appropriées
chown -R www-data:www-data /var/www/html/glpi
chmod 644 $config_file

echo "L'installation de GLPI est terminée ! Adresse IP : http://$ip_address"
