# Skill: Demo Purge

## Zweck
Entfernt die von dieser Demo verwalteten Docker-Compose-Ressourcen und rebased den aktuellen Git-Branch auf seinen konfigurierten Upstream.

## Sicherheits- und Ablaufregeln
1. Phase 4 nur auf ausdrückliche Anforderung starten. `runtime/purge-demo.ps1` ist der vorgesehene Einstiegspunkt und verlangt die PowerShell-Bestätigung für die kombinierte destruktive Aktion.
2. Vorab muss das Git-Arbeitsverzeichnis sauber sein und der Branch einen konfigurierten Upstream besitzen. Das Skript holt den Upstream und rebased den aktuellen Branch darauf. Bei Fetch- oder Rebase-Fehlern werden Docker-Ressourcen nicht entfernt.
3. Das Skript prüft Docker-Container, Netzwerke und Volumes mit dem Compose-Projektlabel. Teilen Ressourcen das generische Compose-Projekt `runtime` mit einer anderen Compose-Konfiguration oder sind Netzwerke außerhalb der Demo belegt, bricht es ab.
4. Für den aktuellen Compose-Stack werden Container, Orphans, Netzwerk und deklarierte Volumes mit `docker compose down --volumes --remove-orphans` entfernt. Bei der aktuellen `docker-compose.yml` sind keine Volumes deklariert; die Splunk-Daten im Container gehen mit dessen Entfernung verloren.
5. Kein globales `docker system prune`, `docker volume prune`, `docker network prune` oder `docker image prune` verwenden. Das heruntergeladene `splunk/splunk:latest`-Image sowie Host-Dateien wie App-Archiv, Konfigurationen und Beispieldaten bleiben erhalten.
6. Docker Desktop nicht automatisch starten, nur um zu purgen. Wenn die Engine nicht läuft, Skript abbrechen, Docker Desktop starten lassen und Phase 4 erneut aufrufen.
7. Nach erfolgreicher Entfernung den Compose-Status prüfen und im Ergebnis Rebase-Ziel, entfernte Ressourcen sowie erhaltene Artefakte nennen. Bei teilweise erfolgreichem Ablauf (Rebase erfolgreich, Compose-Purge fehlgeschlagen) beide Zustände explizit melden.

## Ausführung unter Windows

```powershell
.\runtime\purge-demo.ps1
```

Das Skript verwendet den Upstream des aktuellen Branches als Rebase-Ziel (zum Beispiel `origin/main`). Eine abweichende Basis muss vor dem Start als Upstream des Branches konfiguriert werden. Nicht committete Änderungen werden nicht automatisch gestasht oder verworfen.
