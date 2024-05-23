#!/bin/bash
#
# GLPI install script
#
# Author: jr0w3
# Version: 1.1.1
#

function warn(){
    echo -e '\e[31m'$1'\e[0m';
}
function info(){
    echo -e '\e[36m'$1'\e[0m';
}

function check_root()
{
# Vérification des privilèges root
if [[ "$(id -u)" -ne 0 ]]
then
        warn "Ce script doit être lancé en root" >&2
  exit 1
else
        info "Privilèges root: OK"
fi
}

function network_info()
{
INTERFACE=$(ip route | awk 'NR==1 {print $5}')
IPADRESS=$(ip addr show $INTERFACE | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
HOST=$(hostname)
}

function confirmation_installation()
{
warn "Ce script va télécharger et installer tous les paquets nécessaires à l'installation de GLPI."
info "Etes-vous  sûrs ? [oui/non]"
read confirm
if [ $confirm == "oui" ]; then
        info "Installation..."
elif [ $confirm == "non" ]; then
        info "Abandon..."
        exit 1
else
        warn "Choix invalide. Abandon..."
        exit 1
fi
}

function install_paquets()
{
info "Installation des paquets..."
sleep 1
apt update
apt install --yes --no-install-recommends \
apache2 \
mariadb-server \
perl \
curl \
jq \
php \
apt install --yes --no-install-recommends \
php-ldap \
php-imap \
php-apcu \
php-xmlrpc \
php-cas \
php-mysqli \
php-mbstring \
php-curl \
php-gd \
php-simplexml \
php-xml \
php-intl \
php-zip \
php-bz2
systemctl enable mariadb
systemctl enable apache2
}

function mariadb_configuration()
{
info "Configuration de MariaDB..."
sleep 1
#SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
#SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
systemctl start mariadb
sleep 1

# Mdp root
mysql -e "UPDATE mysql.user SET Password = "Azerty1*" WHERE User = 'root'"
# Suppression utilisateurs anonymes
mysql -e "DELETE FROM mysql.user WHERE User = ''"
# Désactivation du root à distance
mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
# Suppresion de la db test
mysql -e "DROP DATABASE test"
# Reload des privilèges
mysql -e "FLUSH PRIVILEGES"
# Création de la nouvelle db
mysql -e "CREATE DATABASE glpi.pharmgreen"
# Création d'un nouvel utilisateur
mysql -e "CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD'"
# Accord des privilèges au nouvel utilisateur
mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost'"
# Reload des privilèges
mysql -e "FLUSH PRIVILEGES"

# Time zones
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p'Azerty1*' mysql

dpkg-reconfigure tzdata
systemctl restart mariadb
sleep 1
mysql -e "GRANT SELECT ON mysql.time_zone_name TO 'glpi_user'@'localhost'"
}

function installation_glpi()
{
info "Downloading and installing the latest version of GLPI..."
# Téléchargement
DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK
tar xzf /tmp/glpi-latest.tgz -C /var/www/html/

# Permissions
chown -R www-data:www-data /var/www/html/glpi
chmod -R 775 /var/www/html/glpi

# Vhost
cat > /etc/apache2/sites-available/000-default.conf << EOF
<VirtualHost *:80>
       DocumentRoot /var/www/html/glpi/public  
       <Directory /var/www/html/glpi/public>
                Require all granted
                RewriteEngine On
                RewriteCond %{REQUEST_FILENAME} !-f
                RewriteRule ^(.*)$ index.php [QSA,L]
        </Directory>
        
        LogLevel warn
        ErrorLog \${APACHE_LOG_DIR}/error-glpi.log
        CustomLog \${APACHE_LOG_DIR}/access-glpi.log combined
        
</VirtualHost>
EOF

echo "ServerSignature Off" >> /etc/apache2/apache2.conf
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf

# Cron
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

#Activation du module rewrite d'apache
a2enmod rewrite && systemctl restart apache2
}

function setup_db()
{
info "Setting up GLPI..."
cd /var/www/html/glpi
php bin/console db:install --db-name=glpi.pharmgreen --db-user=glpi_user --db-password=Azerty1* --no-interaction
rm -rf /var/www/html/glpi/install
}

function details()
{
info "================> GLPI détails  <================"
warn "Notes bien toutes les informations qui suivent."
info "==> GLPI :"
info "Utilisateurs par défaut :"
info "USER       -  PASSWORD       -  ACCESS"
info "glpi       -  glpi           -  admin,"
info "tech       -  tech           -  technical,"
info "normal     -  normal         -  normal ,"
info "post-only  -  postonly       -  post-only."
echo ""
info "Vous pouvez vous connecter via :"
info "http://$IPADRESS or http://$HOST" 
echo ""
info "==> Database:"
info "root password:           Azerty1*"
info "glpi_user password:      Azerty1*"
info "GLPI database name:      glpi:pharmgreen"
info "<==========================================>"
echo ""
}


check_root
confirm_installation
network_info
install_paquets
mariadb_configuration
installation_glpi
setup_db
details
