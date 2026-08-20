#!/bin/bash

FICHIER_XCCONFIG_DEBUG="$(pwd)/platforms/ios/cordova/build-debug.xcconfig"
FICHIER_XCCONFIG_RELEASE="$(pwd)/platforms/ios/cordova/build-release.xcconfig"

echo "Le répertoire courant est : $(pwd)"

if [ -f "$FICHIER_XCCONFIG_DEBUG" ]; then
  cat "$FICHIER_XCCONFIG_DEBUG"
else
  echo "Info: fichier absent $FICHIER_XCCONFIG_DEBUG"
fi

if [ -f "$FICHIER_XCCONFIG_RELEASE" ]; then
  cat "$FICHIER_XCCONFIG_RELEASE"
else
  echo "Info: fichier absent $FICHIER_XCCONFIG_RELEASE"
fi

# Vérifier si ios
TARGET="${DEVICE_TARGET:-${APPFLOW_BUILD_TARGET:-ios}}"
TARGET_LC="$(printf '%s' "$TARGET" | tr '[:upper:]' '[:lower:]')"

if [ "$TARGET_LC" != "ios" ]; then
  echo "Rien à faire pour ios"
  exit 0
fi

echo "Ici remplacement chaine"

ENCRYPTION_HANDLER_PATH="$(pwd)/platforms/ios/StudiUM mobile/Plugins/@moodlehq/phonegap-plugin-push/EncryptionHandler.m"

if [ ! -f "$ENCRYPTION_HANDLER_PATH" ]; then
  echo "Info: fichier absent $ENCRYPTION_HANDLER_PATH"
  exit 0
fi

if sed --version >/dev/null 2>&1; then
  sed -i 's/#import "Moodle-Swift.h"/#import "StudiUM_mobile-Swift.h"/g' "$ENCRYPTION_HANDLER_PATH"
else
  sed -i '' 's/#import "Moodle-Swift.h"/#import "StudiUM_mobile-Swift.h"/g' "$ENCRYPTION_HANDLER_PATH"
fi

cat "$ENCRYPTION_HANDLER_PATH"
