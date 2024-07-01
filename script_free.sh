#!/bin/bash

# Variables
DB_USER="root"  # Remplacez par votre utilisateur de base de données
DB_PASS="Azerty1*"  # Remplacez par votre mot de passe de base de données
DB_NAME="pharmgreen"

#!/bin/bash

# Variables
DB_USER="root"  # Remplacez par votre utilisateur de base de données
DB_PASS="yourpassword"  # Remplacez par votre mot de passe de base de données
DB_NAME="asterisk"

# Fonction pour extraire les utilisateurs et leurs numéros de téléphone de l'AD
extract_users_and_numbers() {
  ldapsearch -x -b "dc=pharmgreen,dc=org" -D "cn=administrator,dc=pharmgreen,dc=org" -w Azerty1* "(objectClass=user)" sAMAccountName telephoneNumber | awk '/^sAMAccountName:/ {username=$2} /^telephoneNumber:/ {print username":"$2}'
}

# Récupérer les utilisateurs et leurs numéros
users=$(extract_users_and_numbers)

# Pour chaque utilisateur et numéro, créer une extension SIP
IFS=$'\n'
for user in $users; do
  username=$(echo $user | cut -d':' -f1)
  extension=$(echo $user | cut -d':' -f2)

  # Insérer l'extension SIP dans la base de données Asterisk
  mysql -u$DB_USER -p$DB_PASS $DB_NAME <<EOF
INSERT INTO sip (id, keyword, data, flags) VALUES
('$extension', 'account', '$username', 0),
('$extension', 'callerid', '$username <$extension>', 0),
('$extension', 'context', 'from-internal', 0),
('$extension', 'host', 'dynamic', 0),
('$extension', 'secret', 'yourpassword', 0);  # Remplacez par un mot de passe sécurisé
EOF

  echo "Extension SIP $extension créée pour l'utilisateur $username"
done
