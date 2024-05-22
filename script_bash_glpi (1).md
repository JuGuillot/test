#!/bin/bash

# Vérifier que le fichier de configuration existe
if [ ! -f config.txt ]; then
  echo "Le fichier de configuration config.txt n'existe pas !"
  exit 1
fi

# Lire les informations de configuration à partir du fichier
db_name=$(grep "db_name" config.txt | cut -d "=" -f 2)
db_user=$(grep "db_user" config.txt | cut -d "=" -f 2)
db_pass=$(grep "db_pass" config.txt | cut -d "=" -f 2)
glpi_url=$(grep "glpi_url" config.txt | cut -d "=" -f 2)

# Installer les dépendances nécessaires
apt-get update
apt-get install -y apache2 mysql-server php php-mysql php-curl php-gd php-xmlrpc

# Configurer la base de données
mysql -e "CREATE DATABASE $db_name;"
mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_pass';"

# Télécharger et extraire GLPI
wget https://github.com/glpi-project/glpi/releases/download/9.5.6/glpi-9.5.6.tgz
tar -xvf glpi-9.5.6.tgz
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
echo "
define('DB_NAME', '$db_name');
define('DB_USER', '$db_user');
define('DB_PASS', '$db_pass');
define('DB_HOST', 'localhost');
define('DB_PORT', '3306');
define('DB_TYPE', 'mysqli');
" > /var/www/html/glpi/config/config_db.php

chown -R www-data:www-data /var/www/html/glpi

echo "L'installation de GLPI est terminée !"



# traduction
Cette commande shell assigne la valeur de la variable `db_name` en utilisant le contenu d'un fichier appelé `config.txt`. Voici une explication détaillée de chaque partie de la commande :

1. **`grep "db_name" config.txt`** :
    
    - **`grep`** : C'est une commande Unix utilisée pour rechercher des motifs dans un fichier.
    - **`"db_name"`** : C'est le motif recherché. Ici, nous cherchons une ligne contenant `db_name`.
    - **`config.txt`** : C'est le fichier dans lequel nous cherchons le motif.
    
    Cette partie de la commande recherche et renvoie toutes les lignes de `config.txt` qui contiennent le mot `db_name`.
    
2. **`|`** :
    
    - C'est un opérateur de pipe qui prend la sortie de la commande à gauche (ici, `grep "db_name" config.txt`) et l'utilise comme entrée pour la commande à droite.
3. **`cut -d "=" -f 2`** :
    
    - **`cut`** : C'est une commande utilisée pour découper des sections de chaque ligne d'un fichier ou de l'entrée standard.
    - **`-d "="`** : Cette option définit le délimiteur comme étant le signe `=`. Cela signifie que la commande `cut` va utiliser `=` pour séparer les champs.
    - **`-f 2`** : Cette option indique que nous voulons le deuxième champ de chaque ligne, en utilisant `=` comme séparateur.
    
    Cette partie de la commande prend la sortie de `grep`, c'est-à-dire les lignes contenant `db_name`, et extrait tout ce qui se trouve après le signe `=` dans ces lignes.
    
4. **`db_name=$(...)`** :
    
    - Cette syntaxe permet d'assigner le résultat de la commande entre parenthèses à la variable `db_name`.

En résumé, la commande complète cherche la ligne dans `config.txt` qui contient `db_name`, puis extrait et assigne à la variable `db_name` la valeur associée après le signe `=`. Par exemple, si `config.txt` contient une ligne `db_name=my_database`, alors après exécution de la commande, la variable `db_name` contiendra `my_database`.