# Grafana Monitoring Postman Collections

Dieser Ordner enthält nützliche Postman Collections für die diversen Grafana APIs. Ziel ist es, Vorlagen für wiederkehrende Aufgaben bereitzustellen.

## Loki Collection

Diese Collection wurde mit dem Ziel entworfen, die Anforderung umzusetzen, bestimmte Logs, z.B. bei Kündigung eines Kunden, zu löschen. [Anforderungs-Ticket](https://cmiag.myjetbrains.com/youtrack/issue/AZ-432)

Für einfaches Testing enthält die Collection außerdem Calls zum einfachen Anlegen von neuen Logs und Abrufen dieser per API.

### Löschen von Logs

Die Collection folgt dabei folgender [Grafana-Dokumentation](https://grafana.com/docs/grafana-cloud/send-data/logs/delete-log-lines/):

1. URL und User prüfen: In der Collection sind die Daten für das Testsystem vorkonfiguriert. Für Prod müssen diese bei ST7 angefragt werden. Bzw. wie in der Grafana-Dokumentation beschrieben, in der Datasource abgelesen werden.
2. API-Keys: Die benötigten API-Keys sind jeweils nur kurze Zeit gültig und können bei Bedarf durch ST7 wie in der Grafana-Doku neu erstellt werden.
3. Call vorbereiten: Die Calls sind so vorkonfiguriert, dass immer die Logs der letzten 30 gelöscht werden. Nach aktuellem Stand (27.12.2023) entspricht das der maximalen Aufbewahrungszeit und damit allen Logs. In der Query muss nur noch der Filter (tenant_id) ausgefüllt werden.
4. POST loki/api/v1/delete ausführen. Das effektive Löschen kann einige Zeit in Anspruch nehmen.
5. GET loki/api/v1/delete ausführen und den Status prüfen.
6. Daten über Grafana Explore prüfen.

### Besonderheiten

Loki benötigt für einen Großteil der Anfragen Zeitstempel. Das Format kann hierbei aber von Endpunkt zu Endpunkt unterschiedlich sein. Sollten die Standards angepasst werden, muss darauf geachtet werden, das richtige Format zu verwenden.
