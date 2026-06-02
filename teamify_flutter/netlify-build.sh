#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.41.7"
FLUTTER_TARBALL="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_TARBALL}"

if [ ! -d "$HOME/flutter" ]; then
  echo ">>> Downloading Flutter $FLUTTER_VERSION..."
  wget -q -O /tmp/flutter.tar.xz "$FLUTTER_URL"
  echo ">>> Extracting Flutter SDK..."
  tar -xf /tmp/flutter.tar.xz -C "$HOME"
fi

export PATH="$HOME/flutter/bin:$PATH"

flutter config --enable-web
flutter precache --web
flutter --version

flutter pub get
flutter build web \
  --dart-define=API_BASE_URL=https://teamify-backend-5hq0.onrender.com \
  --dart-define=OAUTH_REDIRECT_URI=https://curious-scone-0d6e70.netlify.app/
