#!/usr/bin/env bash
set -euo pipefail

android_signing_values=(
  "${ANDROID_KEYSTORE_BASE64:-}"
  "${ANDROID_KEYSTORE_PASSWORD:-}"
  "${ANDROID_KEY_ALIAS:-}"
  "${ANDROID_KEY_PASSWORD:-}"
)
configured_signing_values=0
for value in "${android_signing_values[@]}"; do
  if [[ -n "$value" ]]; then
    configured_signing_values=$((configured_signing_values + 1))
  fi
done

if [[ "$configured_signing_values" -eq 0 ]]; then
  echo "Android signing secrets are not configured; this APK will use Flutter's default debug signing key."
elif [[ "$configured_signing_values" -eq 4 ]]; then
  keystore_path="android/app/app-casas-release.jks"
  printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 --decode > "$keystore_path"
  chmod 600 "$keystore_path"
  keytool -list \
    -keystore "$keystore_path" \
    -storepass "$ANDROID_KEYSTORE_PASSWORD" \
    -alias "$ANDROID_KEY_ALIAS" >/dev/null
else
  echo "::error::Set all four Android signing secrets, or leave all four unset."
  exit 1
fi

dart_defines=(
  "--dart-define=FIREBASE_API_KEY=${FIREBASE_API_KEY:-}"
  "--dart-define=FIREBASE_APP_ID=${FIREBASE_APP_ID:-}"
  "--dart-define=FIREBASE_MESSAGING_SENDER_ID=${FIREBASE_MESSAGING_SENDER_ID:-}"
  "--dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-}"
  "--dart-define=GOOGLE_SERVER_CLIENT_ID=${GOOGLE_SERVER_CLIENT_ID:-}"
  "--dart-define=FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN:-}"
  "--dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET:-}"
)

flutter build apk --release "${dart_defines[@]}"
