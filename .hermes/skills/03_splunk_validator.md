# Skill: Splunk Validation Loop

## Zweck
Überprüft autonom, ob Test-Events korrekt im Zielindex ankommen und abfragbar sind. 
**WICHTIG für lokale Agenten:** Führe immer nur einen Schritt gleichzeitig aus. 

## Vorbedingungen & MCP-Anbindung
1. Vergewissere dich, dass die Splunk MCP App installiert und das Token für Hermes aktualisiert wurde (siehe `mcp/mcp_config.json`).
2. Generiere simulierte Events (JSON) gemäß Spezifikation (z.B. in `runtime/sample_events.json`) und sende sie per Bash (curl) an den HEC Endpunkt.
   ```bash
   jq -c '.[]' runtime/sample_events.json > runtime/sample_events.ndjson
   curl -k -H "Authorization: Splunk <DEIN_HEC_TOKEN_AUS_ENV>" https://localhost:8088/services/collector/event -d @runtime/sample_events.ndjson
   ```

## Validierung über MCP Tool
Verwende zwingend die integrierten **MCP Tools**, um die Daten in Splunk zu validieren, da dies fehlerresistenter für den Agenten ist als manuelles Bash/curl mit JSON-Parsing.

1. **Tool-Aufruf:** Nutze das bereitgestellte Tool `splunk_run_query` (direkt über den Hermes MCP Client oder zur Not via curl).
2. **Parameter:** 
   - `query`: `"search index=bank_auth | stats count by status"`
   - `earliest_time`: `"-10y"` (um historische simulierte Events sicher zu erfassen)
3. **Auswertung:** Prüfe das JSON-Ergebnis des Tools. Wenn die Anzahl > 0 ist und die korrekten Status (z.B. SUCCESS / FAILED) gelistet sind, ist die Validierung erfolgreich.
4. **Fehlgeschlagen:** Wenn das Tool 0 Events zurückliefert, warte 5 Sekunden und rufe das Tool erneut auf (Splunk Latenz).

## Feedback
Gib am Ende eine klare Zusammenfassung an den User aus:
`[VALIDIERT] X Events in Index <index> gefunden. Extrahierte Werte: <werte>`
