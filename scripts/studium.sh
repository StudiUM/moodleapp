#!/bin/bash

# Valeurs par défaut
STUDIUM_ENV="prod"
DEVICE_TARGET=""

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

detect_device_target() {
  local candidates=(
    "${DEVICE_TARGET:-}"
    "${APPFLOW_BUILD_TARGET:-}"
    "${PLATFORM:-}"
    "${BUILD_PLATFORM:-}"
    "${CI_PLATFORM:-}"
  )

  for candidate in "${candidates[@]}"; do
    candidate_lc="$(to_lower "$candidate")"

    case "$candidate_lc" in
      ios|iphoneos)
        echo "ios"
        return
        ;;
      android)
        echo "android"
        return
        ;;
    esac
  done

  echo "android"
}

# Si des arguments sont fournis, on les utilise
if [ ! -z "$1" ]; then
  STUDIUM_ENV=$1
fi

if [ ! -z "$2" ]; then
  DEVICE_TARGET=$2
fi

if [ -z "$DEVICE_TARGET" ]; then
  DEVICE_TARGET="$(detect_device_target)"
fi

DEVICE_TARGET="$(to_lower "$DEVICE_TARGET")"

if [[ "$DEVICE_TARGET" != "android" && "$DEVICE_TARGET" != "ios" ]]; then
  echo "Erreur: DEVICE_TARGET doit être 'android' ou 'ios'."
  exit 1
fi

# Déterminer le fichier source en fonction de l'environnement et de la plateforme.
SOURCE_FILE="studium-${STUDIUM_ENV}-${DEVICE_TARGET}.config.json"

if [ ! -f "$SOURCE_FILE" ]; then
  # Fallback vers le fichier de configuration générique de la plateforme
  if [[ "$DEVICE_TARGET" == "android" ]]; then
    SOURCE_FILE="android-config.json"
  else
    SOURCE_FILE="ios-config.json"
  fi
fi

# Vérifier si le fichier existe
if [ ! -f "$SOURCE_FILE" ]; then
  echo "Erreur: le fichier $SOURCE_FILE n'existe pas."
  exit 1
fi

# Vérifier les variables Appflow obligatoires.
if [ -z "${STUDIUM_NAME:-}" ] || [ -z "${STUDIUM_URL:-}" ]; then
  echo "Erreur: STUDIUM_NAME et STUDIUM_URL doivent être définies."
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Erreur: node est requis pour générer moodle.config.json."
  exit 1
fi

# Construire dynamiquement la liste des sites depuis des variables séparées par '|'.
IFS='|' read -r -a SITE_NAMES <<< "$STUDIUM_NAME"
IFS='|' read -r -a SITE_URLS <<< "$STUDIUM_URL"

if [ "${#SITE_NAMES[@]}" -ne "${#SITE_URLS[@]}" ]; then
  echo "Erreur: STUDIUM_NAME et STUDIUM_URL doivent contenir le même nombre d'éléments."
  exit 1
fi

for i in "${!SITE_NAMES[@]}"; do
  SITE_NAME="$(echo "${SITE_NAMES[$i]}" | xargs)"
  SITE_URL="$(echo "${SITE_URLS[$i]}" | xargs)"

  if [ -z "$SITE_NAME" ] || [ -z "$SITE_URL" ]; then
    echo "Erreur: nom ou URL vide détecté à la position $i dans STUDIUM_NAME/STUDIUM_URL."
    exit 1
  fi
done

SOURCE_FILE="$SOURCE_FILE" STUDIUM_NAME="$STUDIUM_NAME" STUDIUM_URL="$STUDIUM_URL" node - <<'NODE'
const fs = require('fs');

const sourcePath = process.env.SOURCE_FILE;
const targetPath = 'moodle.config.json';

const names = (process.env.STUDIUM_NAME || '').split('|').map(s => s.trim());
const urls = (process.env.STUDIUM_URL || '').split('|').map(s => s.trim());

if (names.length !== urls.length) {
  console.error('Erreur: STUDIUM_NAME et STUDIUM_URL doivent contenir le même nombre d\'éléments.');
  process.exit(1);
}

const sites = names.map((name, index) => ({ name, url: urls[index] }));
const config = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));
config.sites = sites;

fs.writeFileSync(targetPath, `${JSON.stringify(config, null, 4)}\n`);
NODE

# Confirmation
echo "Le fichier $SOURCE_FILE a été utilisé et moodle.config.json a été généré avec succès"

# Déterminer le fichier source
SOURCE_FILE_XML="config.$DEVICE_TARGET.xml"

# Vérifier si le fichier xml existe
if [ ! -f "$SOURCE_FILE_XML" ]; then
  echo "Erreur: le fichier $SOURCE_FILE_XML n'existe pas."
  exit 1
fi

# Copier le fichier
cp "$SOURCE_FILE_XML" config.xml

# Confirmation
echo "Le fichier $SOURCE_FILE_XML a été copié avec succès vers config.xml"

# Générer le fichier google-services.json
printf '%s\n' "${GOOGLE_SERVICES:-}" > google-services.json

# Générer le fichier GoogleService-Info.plist
if [ "$DEVICE_TARGET" == "ios" ]; then
  if [ -z "${GOOGLE_INFO_PLIST:-}" ]; then
    echo "Erreur: GOOGLE_INFO_PLIST doit être définie pour un build iOS."
    exit 1
  fi

  printf '%s\n' "$GOOGLE_INFO_PLIST" > GoogleService-Info.plist
fi

echo "Le fichier google-services.json a été généré avec succès"
