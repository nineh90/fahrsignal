#!/usr/bin/env bash
# Nimmt einen fertig gebauten Flutter-Web-Stand entgegen und macht ihn live.
#
# Wird NICHT von Hand aufgerufen, sondern liegt auf dem Server als
# /docker/fahrsignal/deploy.sh und ist in /root/.ssh/authorized_keys als
# erzwungenes Kommando hinterlegt. Der GitHub-Runner schiebt den Build als
# tar.gz über stdin herein:
#
#     tar czf - -C build/web . | ssh root@VPS true
#
# Der dafuer hinterlegte Schluessel kommt damit an genau dieses Skript und an
# keine Shell - dasselbe Muster wie bei kein-einzelfall, aber ein eigener
# Schluessel, damit die Projekte sich nicht gegenseitig oeffnen.
#
# Gebaut wird bewusst im Runner und nicht hier: Flutter auf zwei Kernen waere
# pro Push mehrere Minuten, und das Builder-Image wiegt Gigabytes.
set -euo pipefail

# site/ enthaelt ausschliesslich Auslieferbares und ist das einzige, was in
# den Webcontainer eingehaengt wird. deploy/ mit der .env liegt daneben und
# ist von dort aus unsichtbar.
BASIS=/docker/fahrsignal/site
STAND=$(date +%Y%m%d-%H%M%S)
NEU="$BASIS/releases/$STAND"
LOG=/var/log/fahrsignal-deploy.log

protokoll() { echo "$(date '+%F %T')  $*" >> "$LOG"; }

mkdir -p "$NEU"
# Ab hier jeden Abbruch aufraeumen - ein halb entpackter Ordner soll nicht
# als Release liegenbleiben.
trap 'rm -rf "$NEU"' ERR

tar xzf - -C "$NEU"

# Lieber die alte Version weiter ausliefern als eine kaputte neue: ein leerer
# oder abgeschnittener Tarball darf den Symlink nicht schwenken.
for pflicht in index.html main.dart.js flutter_bootstrap.js; do
    if [ ! -s "$NEU/$pflicht" ]; then
        protokoll "ABBRUCH $STAND - $pflicht fehlt oder ist leer, alter Stand bleibt live"
        exit 1
    fi
done

chmod -R a+rX "$NEU"

# Atomarer Schwenk: ln legt den neuen Symlink daneben, mv -T schiebt ihn in
# einem Zug ueber den alten. Es gibt keinen Moment, in dem "www" fehlt oder
# auf einen halb entpackten Baum zeigt.
#
# Das Ziel ist RELATIV ("releases/...") und nicht absolut. Im Container ist
# /docker/fahrsignal als /srv eingehaengt - ein absoluter Pfad wuerde dort
# ins Leere zeigen und nginx 404 liefern.
ln -sfn "releases/$STAND" "$BASIS/www.neu"
mv -T "$BASIS/www.neu" "$BASIS/www"

trap - ERR

# Die letzten fuenf Staende bleiben liegen: reicht, um von Hand
# zurueckzuschwenken, und haelt den Platzbedarf bei rund 150 MB.
#   Zurueckschwenken:  ln -sfn releases/<stand> www.neu && mv -T www.neu www
ls -1dt "$BASIS"/releases/*/ 2>/dev/null | tail -n +6 | xargs -r rm -rf

protokoll "$STAND live ($(du -sh "$NEU" | cut -f1))"
echo "FahrSignal: $STAND ist live"
