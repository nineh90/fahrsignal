#!/usr/bin/env bash
# Vercel-Buildschritt: Flutter installieren und Web-App bauen.
# Vercel hat kein Flutter im Build-Image → wir holen es selbst.
# Die Supabase-Keys kommen als Vercel-Environment-Variablen (Build-Zeit),
# NICHT aus dem Repo.
set -euo pipefail

# Flutter SDK holen (stabiler Kanal). Vercel cached den Ordner zwischen Builds,
# daher nur klonen, wenn noch nicht vorhanden.
if [ ! -x "flutter/bin/flutter" ]; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git
fi
export PATH="$PWD/flutter/bin:$PATH"

flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_KEY="${SUPABASE_KEY:-}"
