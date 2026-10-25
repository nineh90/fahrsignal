# WebSocket-Relay für FahrSignal – reicht Anweisungen zwischen den beiden
# Geräten im Auto weiter (lib/transport/relay_server.dart).
#
# Gebaut wird auf dem Server, aber nur selten: der Relay ändert sich kaum,
# und das Ergebnis ist eine einzelne Binärdatei von ~6 MB. hochladen.sh legt
# relay_server.dart aus lib/transport/ neben dieses Dockerfile.
#
# Dart-Version gepinnt wie Flutter im Deploy – ein neues "stable" soll nicht
# unbemerkt mitkommen.
FROM dart:3.12 AS bau
WORKDIR /app
COPY pubspec.yaml .
RUN dart pub get
COPY main.dart relay_server.dart bin/
RUN dart compile exe bin/main.dart -o /app/relay

# Kein Betriebssystem im Laufzeit-Image: nur die Binärdatei und die paar
# Bibliotheken, die Dart dafür mitbringt (/runtime).
FROM scratch
COPY --from=bau /runtime/ /
COPY --from=bau /app/relay /relay
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/relay"]
