# Skill: Docker Compose Generierung

## Zweck
Erstellt das Docker Compose File für Splunk.
**Regel für den Agenten:** Schreibe die Datei `runtime/docker-compose.yml` und starte den Stack. Führe erst danach weitere Prüfungen aus (sequenzielles Arbeiten).

## Splunk Enterprise Best Practices für 8B Modelle
Ein kleines lokales Modell sollte sich strikt an dieses Template für `runtime/docker-compose.yml` halten, um YAML-Einrückungsfehler zu vermeiden:

```yaml
services:
  splunk:
    image: splunk/splunk:latest
    container_name: splunk-demo
    environment:
      - SPLUNK_GENERAL_TERMS=--accept-sgt-current-at-splunk-com
      - SPLUNK_START_ARGS=--accept-license
      - SPLUNK_PASSWORD=${SPLUNK_PASSWORD}
      - SPLUNK_HEC_TOKEN=${SPLUNK_HEC_TOKEN}
    ports:
      - "8000:8000"
      - "8089:8089"
      - "8088:8088"
    healthcheck:
      test: ["CMD-SHELL", "curl -k -f -u \"admin:$${SPLUNK_PASSWORD}\" https://localhost:8089/services/server/info || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 6
      start_period: 2m
    networks:
      - splunk-net

networks:
  splunk-net:
    driver: bridge
```

## Ablauf
1. Unter Windows bei Bedarf zuerst `runtime/start-docker-desktop.ps1` ausführen. Unter Linux/WSL `bash runtime/start-docker-desktop.sh`.
2. Stack starten: `docker compose --env-file .env -f runtime/docker-compose.yml up -d`
3. Abwarten: Prüfe mit `docker ps`, ob der Status `(healthy)` ist, bevor du mit Skill 03 weiter machst. Nutze `sleep 20`, um nicht zu oft zu pollen.
