#!/bin/bash

function installation_paquets()
{
info "Installing packages..."
sleep 1
apt update
apt install -y \
apache2 \
mariadb-server \
perl \
curl \
jq \
php \
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

function configuration_mariadb()
{
info "Configuration de MariaDB..."
sleep 1
systemctl start mariadb
sleep 1

# Mdp root
mysql -e "UPDATE mysql.user SET Password = PASSWORD('Azerty1*) WHERE User = 'root'"
# Suppression comptes anonymes
mysql -e "DELETE FROM mysql.user WHERE User = ''"
# Connexion en root impossible
mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
# Suppresion base de donnée test
mysql -e "DROP DATABASE test"
# Rechargement des privilèges
mysql -e "FLUSH PRIVILEGES"
# Création nouvelle bdd
mysql -e "CREATE DATABASE glpi"
# Création d'un nouvel utilisateur
mysql -e "CREATE USER 'glpi_adm'@'localhost' IDENTIFIED BY 'Azerty1*'"
# Accord des privilèges au nouvel utilisateur
mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_adm'@'localhost'"
# Reload privilèges
mysql -e "FLUSH PRIVILEGES"
}

function installation_glpi()
{
info "Downloading and installing the latest version of GLPI..."
# Get download link for the latest release
DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK
tar xzf /tmp/glpi-latest.tgz -C /var/www/html/

# Add permissions
chown -R www-data:www-data /var/www/html/glpi
chmod -R 775 /var/www/html/glpi

# Setup vhost
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

# Désactivation de la signature web apache
echo "ServerSignature Off" >> /etc/apache2/apache2.conf
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf

# Setup Cron task
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

#Activation du module rewrite d'apache
a2enmod rewrite && systemctl restart apache2
}

function config_glpi()
{
info "Configuration de GLPI..."
cd /var/www/html/glpi
php bin/console db:install --db-name=pharmgreen.glpi --db-user=glpi_adm --db-password=Azerty1* --no-interaction
rm -rf /var/www/html/glpi/install
}

function détails()
{
info "=======> GLPI installation details  <======="
warn "Merci de bien noter les informations qui suivent :"
info "==> GLPI:"
info "Utilisateurs par défaut :"
info "UTILISATEUR         MOT DE PASS            ACCESS"
info "glpi              -  glpi           -  admin,"
info "tech              -  tech           -  tech,"
info "normal            -  normal         -  normal,"
info "post-only         -  postonly       -  post-only."
echo ""
info "Vous pouvez accéder à votre serveur GLPI par l'adresse IP ou le nom:"
info "http://$IPADRESS or http://$HOST" 
echo ""
info "==> BDD:"
info "Mot de passe root:           Azerty1*"
info "Mot de passe glpi_adm:       Azerty1*"
info "Nom du domaine GLPI:         pharmgreen.glpi"
info "<==========================================>"
echo ""
}



installation_paquets
configuration_mariadb
installation_glpi
config_glpi
détails