#!/usr/bin/env bash
# Startet FahrSignal lokal mit der Supabase-Konfiguration aus .env.
# Ohne diese Werte fällt main.dart auf den lokalen WS-Relay zurück.
#
#   ./run_local.sh            # Standard: Linux-Desktop
#   ./run_local.sh chrome     # im Browser
set -euo pipefail
cd "$(dirname "$0")"

DEVICE="${1:-linux}"

if [ ! -f .env ]; then
  echo ".env fehlt — lege sie mit SUPABASE_URL und SUPABASE_KEY an." >&2
  exit 1
fi

# .env einlesen (Kommentare/Leerzeilen ignorieren).
set -a
# shellcheck disable=SC1091
source .env
set +a

# Werte trimmen: ein versehentliches Leerzeichen sprengt Supabases Uri.parse.
URL="$(echo "${SUPABASE_URL:-}" | xargs)"
KEY="$(echo "${SUPABASE_KEY:-}" | xargs)"

if [ -z "$URL" ] || [ -z "$KEY" ]; then
  echo "SUPABASE_URL oder SUPABASE_KEY ist leer in .env." >&2
  exit 1
fi

exec flutter run -d "$DEVICE" \
  --dart-define=SUPABASE_URL="$URL" \
  --dart-define=SUPABASE_KEY="$KEY"
