#!/bin/bash

function install_packages() {
        info "Installing packages..."
        sleep 1
        apt update
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

function mariadb_configure() {
        systemctl start mariadb

        # Set the root password
        mysql -e "UPDATE mysql.user SET Password = PASSWORD('Azerty1*') WHERE User = 'root'"
        # Remove anonymous user accounts
        mysql -e "DELETE FROM mysql.user WHERE User = ''"
        # Disable remote root login
        mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
        # Remove the test database
        mysql -e "DROP DATABASE test"
        # Reload privileges
        mysql -e "FLUSH PRIVILEGES"
        # Create a new database
        mysql -e "CREATE DATABASE glpi"
        # Create a new user
        mysql -e "CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY 'Azerty1*'"
        # Grant privileges to the new user for the new database
        mysql -e "GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost'"
        # Reload privileges
        mysql -e "FLUSH PRIVILEGES"
}

function install_glpi() {
        info "Downloading and installing the latest version of GLPI..."
        # Get download link for the latest release
        DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
        wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK
        tar xzf /tmp/glpi-latest.tgz -C /var/www/html/

        # Add permissions
        chown -R www-data:www-data /var/www/html/glpi
        chmod -R 775 /var/www/html/glpi

        # Setup vhost
        cat >/etc/apache2/sites-available/000-default.conf <<EOF
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

        #Disable Apache Web Server Signature
        echo "ServerSignature Off" >>/etc/apache2/apache2.conf
        echo "ServerTokens Prod" >>/etc/apache2/apache2.conf

        # Setup Cron task
        echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >>/etc/cron.d/glpi

        #Activation du module rewrite d'apache
        a2enmod rewrite && systemctl restart apache2
}

function setup_db() {
        info "Setting up GLPI..."
        cd /var/www/html/glpi
        php bin/console db:install --db-name=pharmgreen.glpi --db-user=glpi_user --db-password=Azerty1* --no-interaction
        rm -rf /var/www/html/glpi/install
}

function display_credentials() {
        info "=======> GLPI installation details  <======="
        warn "It is important to record this informations. If you lose them, they will be unrecoverable."
        info "==> GLPI:"
        info "Default user accounts are:"
        info "USER       -  PASSWORD       -  ACCESS"
        info "glpi       -  glpi           -  admin account,"
        info "tech       -  tech           -  technical account,"
        info "normal     -  normal         -  normal account,"
        info "post-only  -  postonly       -  post-only account."
        echo ""
        info "You can connect access GLPI web page from IP or hostname:"
        info "http://$IPADRESS or http://$HOST"
        echo ""
        info "==> Database:"
        info "root password:           Azerty1*"
        info "glpi_user password:      Azerty1*"
        info "GLPI database name:          pharmgreen.glpi"
        info "<==========================================>"
        echo ""
}

install_packages
mariadb_configure
install_glpi
setup_db
display_credentials
