#!/usr/bin/env bash
# Startet FahrSignal lokal mit dem WebSocket-Relay aus bin/relay_server.dart.
# Der Relay läuft im Hintergrund auf Port 8080 und endet mit der App.
# Ein zweites Gerät im WLAN erreicht ihn über die Adresse dieses Rechners.
#
#   ./run_local.sh            # Standard: Linux-Desktop
#   ./run_local.sh chrome     # im Browser
set -euo pipefail
cd "$(dirname "$0")"

DEVICE="${1:-linux}"

dart run bin/relay_server.dart &
RELAY=$!
trap 'kill "$RELAY" 2>/dev/null || true' EXIT

flutter run -d "$DEVICE"
