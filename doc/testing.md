# Lokale Test-Anleitung (iOS Simulator, ephemeral test server)

Ziel
----
Sichere, lokale End-to-End Tests der Flutter App auf iOS-Simulator, die NIE gegen Produktions- oder Standard-.env laufen.

Grundprinzip
------------
- Test-Server läuft isoliert in Docker-Compose (`docker-compose.test.yml`) mit einer temporären Postgres-Instanz.
- Test-Server aktiviert nur, wenn `TEST_RUN=true` und `ENABLE_TEST_ENDPOINTS=true` gesetzt sind; Server verweigert Start bei widersprüchlichen Einstellungen.
- Tests rufen `POST /__test/reset` zur Isolation vor/nach Testläufen auf.
- iOS-Simulator und Flutter-Integrationstests werden lokal ausgeführt und kommunizieren mit dem Test-Server über `TEST_SERVER_URL`.

Vorbereitung
-----------
1. Kopiere die Beispiel-Datei:

```bash
cp .env.test.example .env.test
# Passe .env.test falls nötig an
```

2. Stelle sicher, dass Docker installiert und lauffähig ist.

Starten des Test-Stacks
-----------------------
Startet den Server-Stack und wartet auf einen gesunden Server:

```bash
./scripts/start-test-server.sh
```

Das Skript baut das Server-Image (aus `server/Dockerfile`), startet Postgres und den Server, und wartet bis `http://localhost:$TEST_SERVER_PORT/__test/health` erreichbar ist.

Simulator starten (manuell)
---------------------------
Booten des iOS-Simulators (z.B. iPhone 14):

```bash
open -a Simulator
# optional: xcrun simctl boot "iPhone 14"
```

Flutter Integration Tests ausführen
----------------------------------
Beispiel (führt Tests lokal gegen Test-Server aus):

```bash
# setzt TEST_SERVER_URL und TEST_RUN für die App
flutter test integration_test --dart-define=TEST_SERVER_URL="${TEST_SERVER_URL}" --dart-define=TEST_RUN=true
```

Hinweis: alternativ `flutter build ios --simulator` + `flutter run` mit den `--dart-define` Flags möglich.

Teardown / Cleanup
-------------------
Nach Testabschluss:

```bash
./scripts/stop-test-server.sh
```

Dieses entfernt Container, Volumes und netzwerkbezogene Artefakte.

Sicherheitshinweise
-------------------
- **Wichtig:** `.env.test` muss `TEST_RUN=true` enthalten. Wenn `ENABLE_TEST_ENDPOINTS=true` ohne `TEST_RUN=true` gesetzt ist, bricht der Server den Start ab.
- Der Server prüft außerdem, ob `DATABASE_URL` ungleich `TEST_DATABASE_URL` ist und bricht ab, um Produktionsschäden zu vermeiden.
- Test-DB verwendet ein anonymes/named Volume, das beim `down --volumes` gelöscht wird.

Fehlerbehebung
--------------
- Wenn das Start-Skript timing out meldet, schaue in die Server-Logs:

```bash
docker compose -f docker-compose.test.yml logs --no-color server
```

- Wenn Tests trotzdem auf eine falsche DB zeigen, prüfe Umgebungsvariablen:

```bash
env | grep TEST
env | grep DATABASE_URL
```

Erweiterungen
-------------
- Optional: Ein kurzes `TEST_RUN_TOKEN` in `.env.test` erzwingen und Tests müssen diesen Token mit `POST /__test/reset` mitsenden.
- Optional: Ein zusätzliches Script, das den iOS-Simulator-UDID automatisch sucht und für `flutter run` verwendet.

Wenn du möchtest, kann ich jetzt:
- die `integration_test` Test-Scaffold-Datei anlegen,
- oder die `server/Dockerfile` prüfen und anpassen, falls nötig.

