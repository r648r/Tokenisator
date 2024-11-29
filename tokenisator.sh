#!/bin/bash

# Script pour créer un token SPL sur Solana, émettre des tokens, transférer des tokens,
# afficher les comptes et générer les métadonnées avec sugar-cli.

# Utilisation :
# ./create_token.sh -n <NOM_TOKEN> -s <SYMBOLE> -t <TOTAL_SUPPLY> -d <DECIMALS> -r <ADRESSE_DESTINATAIRE> -i <URL_IMAGE>

# Fonction pour afficher l'utilisation
usage() {
    echo "Usage: $0 -n <NOM_TOKEN> -s <SYMBOLE> -t <TOTAL_SUPPLY> -d <DECIMALS> -r <ADRESSE_DESTINATAIRE> -i <URL_IMAGE>"
    echo "  -n    Nom du token"
    echo "  -s    Symbole du token"
    echo "  -t    Quantité totale de tokens à émettre (en unités les plus petites, en tenant compte des décimales)"
    echo "  -d    Décimales (par défaut : 9)"
    echo "  -r    Adresse Solana destinataire pour le transfert initial (1 000 tokens)"
    echo "  -i    URL de l'image pour les métadonnées"
    exit 1
}

# Initialisation des variables
TOKEN_NAME=""
SYMBOL=""
TOTAL_SUPPLY=""
DECIMALS=9
RECIPIENT_ADDRESS=""
IMAGE_URL=""

# Analyse des arguments
while getopts ":n:s:t:d:r:i:" opt; do
  case ${opt} in
    n )
      TOKEN_NAME=$OPTARG
      ;;
    s )
      SYMBOL=$OPTARG
      ;;
    t )
      TOTAL_SUPPLY=$OPTARG
      ;;
    d )
      DECIMALS=$OPTARG
      ;;
    r )
      RECIPIENT_ADDRESS=$OPTARG
      ;;
    i )
      IMAGE_URL=$OPTARG
      ;;
    \? )
      echo "Option invalide: -$OPTARG" 1>&2
      usage
      ;;
    : )
      echo "Option -$OPTARG requiert un argument." 1>&2
      usage
      ;;
  esac
done
shift $((OPTIND -1))

# Vérification des arguments requis
if [ -z "$TOKEN_NAME" ] || [ -z "$SYMBOL" ] || [ -z "$TOTAL_SUPPLY" ] || [ -z "$RECIPIENT_ADDRESS" ] || [ -z "$IMAGE_URL" ]; then
    echo "Erreur : Arguments requis manquants."
    usage
fi

# Fonction pour vérifier les commandes nécessaires
check_command() {
    command -v $1 >/dev/null 2>&1 || { echo >&2 "Erreur : $1 n'est pas installé. Aborting."; exit 1; }
}

# Vérifier les outils nécessaires
check_command solana
check_command spl-token
check_command sugar

# Étape 1 : Créer le token
echo "Création du token SPL..."
CREATE_TOKEN_OUTPUT=$(spl-token create-token --decimals $DECIMALS)
if [ $? -ne 0 ]; then
    echo "Erreur : Échec de la création du token."
    exit 1
fi

# Extraire l'adresse du token
TOKEN_ADDRESS=$(echo "$CREATE_TOKEN_OUTPUT" | grep "Address:" | awk '{print $2}')
echo "Token créé avec l'adresse : $TOKEN_ADDRESS"

# Étape 2 : Créer un compte associé pour le token
echo "Création d'un compte associé pour le token..."
CREATE_ACCOUNT_OUTPUT=$(spl-token create-account $TOKEN_ADDRESS)
if [ $? -ne 0 ]; then
    echo "Erreur : Échec de la création du compte associé."
    exit 1
fi

# Extraire l'adresse du compte associé
ACCOUNT_ADDRESS=$(echo "$CREATE_ACCOUNT_OUTPUT" | grep "Creating account" | awk '{print $3}')
echo "Compte associé créé : $ACCOUNT_ADDRESS"

# Étape 3 : Émettre la quantité totale de tokens
echo "Émission de $TOTAL_SUPPLY tokens vers le compte associé..."
spl-token mint $TOKEN_ADDRESS $TOTAL_SUPPLY $ACCOUNT_ADDRESS
if [ $? -ne 0 ]; then
    echo "Erreur : Échec de l'émission des tokens."
    exit 1
fi
echo "$TOTAL_SUPPLY tokens émis vers $ACCOUNT_ADDRESS"

# Étape 4 : Transférer 1 000 tokens vers l'adresse destinataire
TRANSFER_AMOUNT=1000
echo "Transfert de $TRANSFER_AMOUNT tokens vers l'adresse $RECIPIENT_ADDRESS..."
spl-token transfer $TOKEN_ADDRESS $TRANSFER_AMOUNT $RECIPIENT_ADDRESS --fund-recipient
if [ $? -ne 0 ]; then
    echo "Erreur : Échec du transfert des tokens."
    exit 1
fi
echo "$TRANSFER_AMOUNT tokens transférés vers $RECIPIENT_ADDRESS"

# Étape 5 : Afficher les comptes de tokens
echo "Affichage des comptes de tokens..."
spl-token accounts

# Étape 6 : Générer le fichier de métadonnées avec sugar-cli
echo "Création du fichier de métadonnées..."

METADATA_FILE="metadata.json"
cat > $METADATA_FILE <<EOL
{
  "name": "$TOKEN_NAME",
  "symbol": "$SYMBOL",
  "description": "Description de $TOKEN_NAME.",
  "image": "$IMAGE_URL",
  "seller_fee_basis_points": 0,
  "attributes": [],
  "collection": {},
  "properties": {}
}
EOL

echo "Fichier de métadonnées créé : $METADATA_FILE"

# Étape 7 : Générer les métadonnées avec sugar-cli
echo "Génération des métadonnées avec sugar-cli..."
sugar create-metadata --token-address $TOKEN_ADDRESS --metadata-file $METADATA_FILE
if [ $? -ne 0 ]; then
    echo "Erreur : Échec de la génération des métadonnées avec sugar-cli."
    exit 1
fi
echo "Métadonnées générées avec succès."

echo "Script terminé avec succès !"
exit 0
