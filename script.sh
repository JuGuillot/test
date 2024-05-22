#!/bin/bash

function installation_paquets() {
    info "Installation des paquets nécessaires..."
    sleep 1
    apt update
    apt install -y \
        apache2 \
        mariadb-server \
        perl \
        curl \
        jq \
        php \
        php8.2-fpm \
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

function config_mariadb() {
    info "Configuration de MariaDB..."
    systemctl start mariadb
    sleep 1

    # Mot de passe root
    mysql -e "UPDATE mysql.user SET Password = PASSWORD('Azerty1*') WHERE User = 'root'"
    # Supprimer utilisateurs anonymes
    mysql -e "DELETE FROM mysql.user WHERE User = ''"
    # Désactiver l'accès à distance en root
    mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
    # Supprimer la base de donnée test
    mysql -e "DROP DATABASE test"
    # Recharger les privileges
    mysql -e "FLUSH PRIVILEGES"
    # Création de la noubelle base de donnée
    mysql -e "CREATE DATABASE pharmgreen.glpi"
    # Création du nouvel utilisateur
    mysql -e "CREATE USER 'pharmgreen.glpi'@'localhost' IDENTIFIED BY 'Azerty1*'"
    # Accorder les privligèles au nouvel utilisateur
    mysql -e "GRANT ALL PRIVILEGES ON pharmgreen.glpi TO 'glpi_adm'@'localhost'"
    # Recharger les privilèges
    mysql -e "FLUSH PRIVILEGES"

    sleep 1
}

function install_glpi() {
    info "Téléchargement et installation de GLPI..."
    # Dernière version de GLPI
    DOWNLOADLINK=$(wget https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
    wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK
    tar xzf /tmp/glpi-latest.tgz -C /var/www/html/

    # Création dossiers
    sudo mkdir /etc/glpi
    sudo chown www-data /etc/glpi/
    sudo mv /var/www/glpi/config /etc/glpi

    sudo mkdir /var/lib/glpi
    sudo chown www-data /var/lib/glpi/
    sudo mv /var/www/glpi/files /var/lib/glpi

    sudo mkdir /var/log/glpi
    sudo chown www-data /var/log/glpi

    # Ajout permissions
    chown -R www-data:www-data /var/www/html/glpi
    chmod -R 775 /var/www/html/glpi
    chown -R www-data /var/www/glpi/

    # Création fichiers de config

    cat >/var/www/glpi/inc/downstream.php <<EOF
<?php
define('GLPI_CONFIG_DIR', '/etc/glpi/');
if (file_exists(GLPI_CONFIG_DIR . '/local_define.php')) {
    require_once GLPI_CONFIG_DIR . '/local_define.php';
}
EOF

    cat >/etc/glpi/local_define.php <<EOF
<?php
define('GLPI_VAR_DIR', '/var/lib/glpi/files');
define('GLPI_LOG_DIR', '/var/log/glpi');
EOF

    # Config vhost
    cat >/etc/apache2/sites-available/pharmgreen.glpi <<EOF
<VirtualHost *:80>
    ServerName pharmgreen.glpi

    DocumentRoot /var/www/glpi/public

    # If you want to place GLPI in a subfolder of your site (e.g. your virtual host is serving multiple applications),
    # you can use an Alias directive. If you do this, the DocumentRoot directive MUST NOT target the GLPI directory itself.
    # Alias "/glpi" "/var/www/glpi/public"

    <Directory /var/www/glpi/public>
        Require all granted

        RewriteEngine On

        # Redirect all requests to GLPI router, unless file exists.
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:unix:/run/php/php8.2-fpm.sock|fcgi://localhost/"
    </FilesMatch>

</VirtualHost>
EOF

    #Activation du module rewrite d'apache
    a2ensite pharmgreen.glpi
    a2dissite 000-default.conf
    a2enmod rewrite && systemctl restart apache2
    systemctl restart apache2

    # Config de php8.2-fpm

    a2enmod proxy_fcgi setenvif
    a2enconf php8.2-fpm
    systemctl reload apache2

    # Modifier ou ajouter la ligne session.cookie_httponly dans php.ini
    if grep -q "^session.cookie_httponly" "$PHP_INI_FILE"; then
        # La ligne existe, la modifier
        sed -i 's/^session.cookie_httponly.*/session.cookie_httponly = on/' "$PHP_INI_FILE"
    else
        # La ligne n'existe pas, l'ajouter à la fin du fichier
        echo "session.cookie_httponly = on" >>"$PHP_INI_FILE"
    fi

    systemctl restart php8.2-fpm.service
    systemctl restart apache2
}

function Résumé() {
    info "=======> Résumé de l'installation glpi  <======="
    info "==> GLPI:"
    info "Utilisateurs par défaut :"
    info "UTILISATEUR -  MDP            -  ACCESS"
    info "glpi        -  glpi           -  admin,"
    info "tech        -  tech           -  tech,"
    info "normal      -  normal         -  normal,"
    info "post-only   -  postonly       -  post-only."
    echo ""
    info "Vous pouvez accéder au server GLPI par ces 2 moyens :"
    info "http://$IPADRESS or http://$HOST"
    echo ""
    info "==> Base de donnée :"
    info "root password:           Azerty1*"
    info "glpi_user password:      Azerty1*"
    info "GLPI database name:          pharmgreen.glpi"
    info "<==========================================>"
    echo ""
}

installation_paquets
config_mariadb
install_glpi
Résumé
