# Architecture Specification: Bankhaus Authentication Demo POC

## 1. Übersicht & Ziel
Bereitstellung einer lokalen Splunk-Single-Instance-Demo für das CISO-Team. Authentifizierungsereignisse werden als JSON über den HTTP Event Collector (HEC) an Splunk gesendet. Die Demo weist nach, dass fehlgeschlagene Anmeldeversuche zuverlässig gesucht und visualisiert werden können.

## 2. Topologie & Netzwerk
- **Splunk Rolle:** Single-Instance (Search Head + Indexer in einem)
- **Web UI:** `http://localhost:8000`
- **Management / REST API:** `https://localhost:8089`
- **HTTP Event Collector (HEC):** `https://localhost:8088`

## 3. Data Ingestion & Storage
- **Index Name:** `bank_auth`
- **Source Type:** `_json`
- **HEC Token Name:** `demo_hec_token`
- **HEC Token Secret:** Über `.env` (`SPLUNK_HEC_TOKEN`) bereitzustellen; kein Klartext-Secret in dieser Spezifikation.
- **Event-Felder:** `user`, `action`, `status`, `src_ip`
- **Statuswerte:** `SUCCESS` und `FAILED`
- **Beispielnutzer:** `admin` und `jsmith`

## 4. Validierungskriterien
- **Test-Events:** 5 simulierte JSON-Authentifizierungsereignisse. Sie umfassen beide Statuswerte und beide Beispielnutzer.
- **Erwartete Felder:** `user`, `action`, `status`, `src_ip`; `status` muss `SUCCESS` oder `FAILED` enthalten.
- **Prüf-SPL – Ereignisse nach Status und Nutzer:** `index=bank_auth | stats count by status, user`
- **Prüf-SPL – fehlgeschlagene Anmeldungen für die Visualisierung:** `index=bank_auth status=FAILED | stats count by user`
- **Visualisierungsnachweis:** Die letzte Abfrage wird als Balkendiagramm mit der Anzahl fehlgeschlagener Anmeldungen pro Nutzer dargestellt. Die Ergebnisse müssen fehlgeschlagene Ereignisse enthalten und nach Nutzer aufgeschlüsselt sein.

## 5. Annahmen & offene Fragen
- Die Anzahl von 5 Test-Events stammt aus der bestehenden POC-Spezifikation; das Briefing legt keine Anzahl fest.
- Die genaue Verteilung der Statuswerte und Nutzer ist nicht vorgegeben. Die Testdaten sollen mindestens ein `FAILED`- und ein `SUCCESS`-Ereignis sowie Ereignisse für `admin` und `jsmith` enthalten.
- Das Briefing legt kein Zeitfenster und keine Zeitreihen-Visualisierung fest. Für einen reproduzierbaren Nachweis wird daher zunächst eine Zählung fehlgeschlagener Logins pro Nutzer verwendet.
- Es bestehen keine offenen Fragen, die die Erstellung dieser Spezifikation verhindern.
