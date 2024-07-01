#!/bin/bash

# Variables
DB_USER="Administrator"  # Remplacez par votre utilisateur de base de données
DB_PASS="Azerty1*"  # Remplacez par votre mot de passe de base de données
DB_NAME="asterisk"
LDAP_SERVER="ldap://your_ldap_server"
LDAP_BASE_DN="dc=pharmgreen,dc=org"
LDAP_BIND_DN="cn=Administrator,dc=pharmgreen,dc=org"
LDAP_BIND_PW="Azerty1*"

# Fonction pour extraire les utilisateurs et leurs numéros de téléphone de l'AD
extract_users_and_numbers() {
  ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" -b "$LDAP_BASE_DN" "(objectClass=user)" sAMAccountName telephoneNumber | awk '/^sAMAccountName:/ {username=$2} /^telephoneNumber:/ {print username":"$2}'
}

# Vérifiez la connexion LDAP
if ! ldapsearch -x -H "$LDAP_SERVER" -D "$LDAP_BIND_DN" -w "$LDAP_BIND_PW" -b "$LDAP_BASE_DN" "(objectClass=user)" >/dev/null 2>&1; then
  echo "Erreur: Impossible de contacter le serveur LDAP"
  exit 1
fi

# Récupérer les utilisateurs et leurs numéros
users=$(extract_users_and_numbers)

# Vérifier si des utilisateurs ont été trouvés
if [ -z "$users" ]; then
  echo "Aucun utilisateur trouvé"
  exit 1
fi

# Pour chaque utilisateur et numéro, créer une extension SIP
IFS=$'\n'
for user in $users; do
  username=$(echo $user | cut -d':' -f1)
  extension=$(echo $user | cut -d':' -f2)

  # Vérifiez si les variables username et extension ne sont pas vides
  if [ -z "$username" ] || [ -z "$extension" ]; then
    echo "Erreur: Utilisateur ou extension non valide. Utilisateur: $username, Extension: $extension"
    continue
  fi

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
