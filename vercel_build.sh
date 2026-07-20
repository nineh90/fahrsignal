#!/usr/bin/env bash
# Vercel-Buildschritt: Flutter installieren und Web-App bauen.
# Vercel hat kein Flutter im Build-Image → wir holen es selbst.
# Die Supabase-Keys kommen als Vercel-Environment-Variablen (Build-Zeit),
# NICHT aus dem Repo.
set -euo pipefail

# WICHTIG: exakt die lokal verifizierte Version pinnen (nicht "stable").
# Ein frisches "stable" kann eine neuere Flutter-Engine ziehen, deren
# Web-Build bei uns einen weißen Bildschirm erzeugt hat.
FLUTTER_VERSION="3.44.3"

clone_flutter() {
  rm -rf flutter
  git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git
}

# Flutter holen (Vercel cached den Ordner zwischen Builds).
if [ ! -x "flutter/bin/flutter" ]; then
  clone_flutter
fi
export PATH="$PWD/flutter/bin:$PATH"

# Falls der Cache eine andere Version enthält: auf die gepinnte zwingen.
INSTALLED="$(flutter --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
if [ "$INSTALLED" != "$FLUTTER_VERSION" ]; then
  echo "Gecachte Flutter-Version '$INSTALLED' != '$FLUTTER_VERSION' → neu klonen."
  clone_flutter
  export PATH="$PWD/flutter/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_KEY="${SUPABASE_KEY:-}"
