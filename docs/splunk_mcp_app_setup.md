# Splunk MCP App installieren und vorbereiten

Diese Anleitung beschreibt die Vorbedingungen für Phase 3. Vor dem Senden von Testevents muss die Splunk-MCP-App installiert, die Splunk-REST-API mit Token-Authentifizierung erreichbar und der MCP-Endpunkt verifiziert sein.

## Voraussetzungen

- Splunk läuft lokal; Splunk Web ist unter `http://localhost:8000`, die Management-API unter `https://localhost:8089` und HEC (TLS) unter `https://localhost:8088` erreichbar.
- Das App-Archiv liegt unter `runtime/apps/splunk-mcp-server_200.tgz`. Es enthält die App `Splunk_MCP_Server`, Version 2.0.0.
- Die Umgebungsvariable `SPLUNK_ACCESS_TOKEN` enthält einen für diese Splunk-Instanz gültigen Splunk-Bearer-Token. Der Token muss zum Benutzer und dessen Berechtigungen passen.
- Für den lokalen Demo-Stack kann das selbstsignierte REST-Zertifikat mit `-k` akzeptiert werden. Für produktive Systeme muss stattdessen das Zertifikat geprüft werden.

Die Beispiele sind vom Projektverzeichnis aus in Windows PowerShell auszuführen und verwenden `curl.exe` (nicht den PowerShell-Alias `curl`). Sie laden den Token aus der Projektdatei `.env`, geben seinen Wert nicht aus und verwenden ihn für REST-Aufrufe im HTTP-Header:

```powershell
$baseUrl = 'https://localhost:8089'
$tokenLine = Get-Content .env | Where-Object { $_ -match '^SPLUNK_ACCESS_TOKEN=' } | Select-Object -First 1
if (-not $tokenLine) { throw 'SPLUNK_ACCESS_TOKEN fehlt in .env.' }
$env:SPLUNK_ACCESS_TOKEN = ($tokenLine -replace '^SPLUNK_ACCESS_TOKEN=', '').Trim()
if (-not $env:SPLUNK_ACCESS_TOKEN) { throw 'SPLUNK_ACCESS_TOKEN ist leer.' }
$authHeader = "Authorization: Bearer $env:SPLUNK_ACCESS_TOKEN"
```

## 1. Token-Authentifizierung vorab verifizieren

Prüfe zuerst den Status der Splunk-Token-Authentifizierung:

```powershell
curl.exe -k -sS -H $authHeader "$baseUrl/services/admin/token-auth/tokens_auth?output_mode=json"
if ($LASTEXITCODE -ne 0) { throw 'Abfrage der Token-Authentifizierung ist fehlgeschlagen.' }
```

Die Antwort muss `disabled` auf `false` setzen. Verifiziere anschließend, dass genau der konfigurierte Token für die REST-API akzeptiert wird:

```powershell
$httpStatus = curl.exe -k -sS -o NUL -w '%{http_code}' -H $authHeader `
  "$baseUrl/services/server/info?output_mode=json"
if ($LASTEXITCODE -ne 0 -or $httpStatus -ne '200') {
    throw "Splunk-REST-API akzeptiert den Bearer-Token nicht (HTTP $httpStatus). Nicht mit App-Upload fortfahren."
}
```

Ein erfolgreicher Healthcheck des Containers allein weist die Token-Authentifizierung nicht nach; der Healthcheck kann intern andere Anmeldedaten verwenden.

In dieser lokalen Compose-Konfiguration ist HEC mit TLS aktiviert. Deshalb muss `SPLUNK_HEC_URL` mit `https://localhost:8088/services/collector/event` beginnen und Client-Aufrufe müssen das lokale selbstsignierte Zertifikat für die Demo akzeptieren (`-k` bei `curl.exe`). Ein unverschlüsselter HTTP-Aufruf an Port 8088 erhält keine gültige HTTP-Antwort.

### Falls Token-Authentifizierung deaktiviert ist oder noch kein Token existiert

Die Aktivierung und Ausstellung des ersten Splunk-Tokens sind Bootstrap-Aktionen. Dafür ist eine administrative Splunk-Anmeldung erforderlich; nach erfolgreicher Einrichtung müssen die folgenden API-Aufrufe mit `Authorization: Bearer ...` erfolgen.

Bei deaktivierter Token-Authentifizierung einmalig mit dem vorhandenen lokalen Administratorkonto aktivieren:

```powershell
curl.exe -k -sS -u "admin:$env:SPLUNK_PASSWORD" -X POST `
  --data-urlencode 'disabled=false' `
  "$baseUrl/services/admin/token-auth/tokens_auth"
```

Falls noch kein Token existiert, im Splunk-Webinterface unter **Settings > Tokens** einen Token für den vorgesehenen Benutzer erstellen. Den Token lokal in `.env` als `SPLUNK_ACCESS_TOKEN` hinterlegen, PowerShell wie oben neu mit diesem Wert initialisieren und den REST-Preflight wiederholen. Keine Tokenwerte in die Compose-Datei oder in MCP-Konfigurationen eintragen.

Wenn ein vorhandener Token mit HTTP `401` abgelehnt wird, nicht auf Passwort-Authentifizierung für die folgenden Installationsaufrufe ausweichen: Token, Ablaufzeit, Token-Authentifizierungsstatus und Benutzerberechtigungen prüfen und den Preflight wiederholen.

## 2. Vorhandene Installation prüfen

Bevor das Archiv hochgeladen wird, die App über die REST-API abfragen:

```powershell
$appStatus = curl.exe -k -sS -w "`nHTTP %{http_code}" -H $authHeader `
  "$baseUrl/services/apps/local/Splunk_MCP_Server?output_mode=json"
if ($LASTEXITCODE -ne 0) { throw 'App-Status konnte nicht abgefragt werden.' }
$appStatus
```

Bei HTTP `200` ist die App vorhanden. Die Antwort muss die App `Splunk_MCP_Server` und die erwartete Version `2.0.0` ausweisen. In diesem Fall nicht erneut installieren. Bei HTTP `404` mit dem Upload fortfahren. Andere HTTP-Statuscodes sind Fehler und müssen vor dem Upload geklärt werden.

## 3. App-Archiv über die REST-API installieren

Nur wenn der vorherige App-Check HTTP `404` zurückgegeben hat, das vorhandene Archiv über `POST /services/apps/local` als Multipart-Upload installieren. Der Upload und alle nachfolgenden REST-Aufrufe verwenden denselben Bearer-Token:

```powershell
$archive = 'runtime/apps/splunk-mcp-server_200.tgz'
if (-not (Test-Path $archive -PathType Leaf)) { throw "App-Archiv nicht gefunden: $archive" }

curl.exe -k -sS -H $authHeader `
  -F "name=@$archive" `
  -F 'filename=true' `
  "$baseUrl/services/apps/local?output_mode=json"
if ($LASTEXITCODE -ne 0) { throw 'Upload der Splunk-MCP-App fehlgeschlagen.' }
```

Die Antwort des Uploads muss einen Erfolg anzeigen. Danach erneut
`GET /services/apps/local/Splunk_MCP_Server?output_mode=json` aufrufen und prüfen, dass Version `2.0.0` registriert ist. Bei einer Installationsantwort, die einen Neustart verlangt, den Splunk-Service neu starten und erst fortfahren, wenn der REST-Healthcheck wieder erfolgreich ist.

## 4. MCP-Endpunkt und erforderlichen Token-Typ prüfen

Die App stellt ihren MCP-Endpunkt unter folgendem REST-Pfad bereit:

```text
https://localhost:8089/servicesNS/nobody/Splunk_MCP_Server/mcp
```

Der Splunk-REST-Bearer-Token für Installation und API-Aufrufe ist nicht automatisch ein gültiger MCP-Token für diesen Endpunkt. Die App verlangt standardmäßig einen RSA-verschlüsselten MCP-Token. Für MCP-`initialize`/`tools/list` muss daher ein für diese App ausgestellter MCP-Token verwendet werden. Keine verschlüsselte Tokenprüfung abschalten, nur um einen normalen REST-Bearer-Token zu verwenden.

Erst wenn App-Installation, Token-Preflight und MCP-Handshake erfolgreich sind, mit der Event-Ingestion und den SPL-Validierungen aus `.hermes/skills/03_splunk_validator.md` beginnen.

## Fehlerbehandlung

- **HTTP 401 beim REST-Preflight:** Token ungültig/abgelaufen, Token-Authentifizierung deaktiviert oder Berechtigungen fehlen. Vor dem Upload beheben.
- **HTTP 404 beim App-Check:** App fehlt; Archiv über die beschriebene REST-API installieren.
- **HTTP 409 oder anderer Uploadfehler:** Nicht wiederholt blind hochladen. App-Status und Splunk-Antwort prüfen; bei bereits vorhandener App Version und Update-Vorgehen explizit verifizieren.
- **HTTP 503 am MCP-Endpunkt:** Splunk- und App-Health sowie MCP-App-Konfiguration und Rate-Limit-Konfiguration prüfen.
- **„encrypted token required“ beim MCP-Handshake:** Der gesendete Wert ist kein RSA-verschlüsselter MCP-Token. Den korrekten MCP-Token-Ausstellungsablauf beheben, nicht die Verschlüsselungsanforderung umgehen.
