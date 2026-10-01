# Splunk Agentic AI Demo

Dieses Repository demonstriert die Leistungsfähigkeit einer Agentic AI (Hermes) bei der automatischen Bereitstellung, Konfiguration und Validierung einer Splunk-Umgebung für einen Proof of Concept (POC).

Anstatt manuell Docker Compose-Dateien zu schreiben, Splunk über die UI/CLI zu konfigurieren und Testdaten zu generieren, nutzt dieses Projekt Hermes, um eine unstrukturierte Geschäftsanforderung (wie z. B. Kunden-Meeting-Notizen) zu interpretieren und die technische Lösung vollautomatisch aufzubauen.

## Zielsetzung
Das Projekt zeigt, wie ein KI-Agent:
1. **Unstrukturierte Anforderungen versteht:** Eine `input_briefing.md` (Notizen aus einem Call mit einem CISO-Team) wird als Ausgangspunkt genommen.
2. **Architektur plant:** Eine entsprechende System-Architektur (Docker Compose) wird entworfen.
3. **Provisioning durchführt:** Eine lokale Splunk-Umgebung wird hochgefahren.
4. **Konfiguriert & Daten einspeist:** HTTP Event Collector (HEC) und Indizes (`bank_auth`) werden konfiguriert und JSON-Testdaten (Authentifizierungs-Logs) werden simuliert und indexiert.
5. **Validiert:** Die KI prüft selbstständig, ob die Logs ankommen und für die Visualisierung von Fehlversuchen bereitstehen.

## Projektstruktur

- `.hermes/` - Enthält die spezifischen Skills (`01_spec_generator`, `02_compose_builder`, `03_splunk_validator`), die den Agenten durch den Workflow führen.
- `docs/` - Enthält das Ausgangs-Briefing (`input_briefing.md`) und die vom Agenten generierte Architekturspezifikation.
- `runtime/` - Beinhaltet das `docker-compose.yml` und die generierten Testdaten (`sample_events.json`).
- `mcp/` - Konfiguration für das Model Context Protocol (Splunk MCP).
- `docs/splunk_mcp_app_setup.md` - REST-API- und Token-Auth-Vorbereitung für die Splunk-MCP-App.

## Ablauf der Demo
Um die Demo unter Windows zu starten, zunächst Docker Desktop und die Engine bereitstellen:

```powershell
.\runtime\start-docker-desktop.ps1
```

Das Skript startet Docker Desktop bei Bedarf und wartet bis zu fünf Minuten auf eine erreichbare Docker Engine. Es führt **keine** Docker-Compose-Befehle aus. Starte anschließend den Demo-Stack separat:

```powershell
docker compose --env-file .env -f runtime\docker-compose.yml up -d
```

Anschließend kann Hermes das Verzeichnis übernehmen und die Umgebung basierend auf den Meeting-Notizen (`docs/input_briefing.md`) konfigurieren, Testdaten einspielen und die Logs in Splunk validieren.

## Phase 4: Demo bereinigen

Wenn die Demo nicht mehr benötigt wird, entfernt Phase 4 ihre Docker-Compose-Ressourcen und rebased den aktuellen Git-Branch auf seinen konfigurierten Upstream:

```powershell
.\runtime\purge-demo.ps1
```

Das Skript verlangt eine Bestätigung, prüft vor dem Rebase auf einen sauberen Git-Stand und bricht bei gemeinsam genutzten oder unerwarteten Compose-Ressourcen ab. Es entfernt keine globalen Docker-Ressourcen, behält das Splunk-Image und die Host-Dateien bei. Splunk-Daten im entfernten Container gehen verloren. Details und Schutzprüfungen stehen in `.hermes/skills/04_purge.md`.
