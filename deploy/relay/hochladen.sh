#!/usr/bin/env bash
# Baut den Relay-Container auf dem VPS neu und startet ihn.
#
# Anders als die Web-App geht der Relay NICHT über den Push-Deploy: der
# Deploy-Schlüssel darf nur deploy.sh ausführen und kennt keine Container.
# Nötig nur, wenn sich relay_server.dart, dieser Ordner oder
# deploy/docker-compose.yml geändert hat.
#
#   deploy/relay/hochladen.sh            # Ziel: ssh-Alias nils-vps
#   deploy/relay/hochladen.sh user@host
#
# Der Benutzer braucht Docker-Rechte und sudo (für /docker/fahrsignal, das
# root gehört). sudo fragt einmal nach dem Passwort.
set -euo pipefail
cd "$(dirname "$0")/../.."

ZIEL="${1:-nils-vps}"
TMP=$(ssh "$ZIEL" mktemp -d)

scp -q deploy/relay/Dockerfile deploy/relay/pubspec.yaml deploy/relay/main.dart \
  lib/transport/relay_server.dart deploy/docker-compose.yml "$ZIEL:$TMP/"

ssh -t "$ZIEL" "set -e
  sudo mkdir -p /docker/fahrsignal/relay
  sudo cp $TMP/Dockerfile $TMP/pubspec.yaml $TMP/main.dart $TMP/relay_server.dart /docker/fahrsignal/relay/
  sudo cp $TMP/docker-compose.yml /docker/fahrsignal/deploy/docker-compose.yml
  rm -rf $TMP
  cd /docker/fahrsignal/deploy
  sudo docker compose up -d --build relay
  sudo docker compose ps"
