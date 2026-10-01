# Kunden-Meeting Notizen: Splunk Demo POC

Wir hatten heute den Call mit dem CISO-Team. Sie wollen sehen, wie Splunk mit Authentifizierungs-Logs umgeht.

Anforderungen für die Demo:
- Wir brauchen eine lauffähige lokale Splunk-Umgebung für den Termin morgen.
- Logs sollen als JSON über HTTP Event Collector reinkommen.
- Der Index soll `bank_auth` heißen.
- Wir müssen nachweisen, dass fehlgeschlagene Anmeldeversuche (Login-Failures) sauber visualisiert werden können.
- Bitte ein paar simulierte Events einspielen mit Usernamen wie `admin`, `jsmith` und Statuscodes `SUCCESS` bzw. `FAILED`.

## WICHTIG: Ausführungsrichtlinien für lokale / 8B Modelle
1. Arbeite STRIKT SEQUENZIELL. Niemals mehrere Tools oder Befehle gleichzeitig aufrufen.
2. Wenn du Code, JSON oder Markdown generierst, halte dich streng an die Templates in den Skills (`.hermes/skills/`).
3. Nutze für Splunk-Abfragen zwingend das MCP-Tool `splunk_run_query`, wenn es verfügbar ist. Das ist robuster als manuelle Bash-Skripte.
4. Prüfe nach jedem ausgeführten Befehl das Resultat, bevor du zum nächsten Schritt übergehst.
