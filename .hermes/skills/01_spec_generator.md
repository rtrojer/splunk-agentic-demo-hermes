# Skill: Specification Generator

## Zweck
Wandelt unstrukturierte Kundenprosa in eine normierte Splunk-POC-Spezifikation für die Dokumentation (Obsidian) und Weiterverarbeitung um. 
**Regel für den Agenten:** Führe diesen Schritt einzeln aus. Erstelle erst die Datei und verifiziere sie, bevor du mit dem nächsten Skill (z.B. Docker) weiter machst. Kein paralleles Tool-Calling!

## Pflichtfelder in `docs/architecture_spec.md`
Die Ausgabedatei MUSS exakt dieses Format haben (inklusive Markdown-Überschriften). Erfinde keine zusätzlichen Felder:

```markdown
# Architecture Specification: [Projektname / Kunde aus Briefing]

## 1. Übersicht & Ziel
[Maximal 2 Sätze zur Kurzbeschreibung des POC-Szenarios]

## 2. Topologie & Netzwerk
- **Splunk Rolle:** Single-Instance (Search Head + Indexer in einem)
- **Web UI:** Port 8000
- **Management / REST API:** Port 8089
- **HTTP Event Collector (HEC):** Port 8088

## 3. Data Ingestion & Storage
- **Index Name:** [aus Briefing, z.B. bank_auth]
- **Source Type:** _json
- **HEC Token Name:** demo_hec_token

## 4. Validierungskriterien
- **Test-Events:** [Anzahl & Typ der Events aus Briefing]
- **Erwartete Felder:** [z.B. user, action, status]
- **Prüf-SPL:** index=[Index Name] | stats count by status
```
