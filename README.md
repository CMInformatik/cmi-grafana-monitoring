# Grafana Monitoring

Das folgende Projekt enthält alle Resourcen, die im Zusammenhang mit dem Grafana Monitoring stehen.

## Azure Collector Container

Im Ordner `grafana_collector_container` befinden sich das Projekt für den Grafana Collector, der in jeder Azure Umgebung (CMI Cloud Prod, CMI Cloud Stage usw.) einmal läuft. Dieser Collector wird als Container gestartet und findet alle VMs in der angegebenen Azure Subscription. Die Authentifizierung bei Azure erfolgt dabei über eine Managed Identity der Container Instance.

### Allgemeine Konfiguration

Der Container lässt sich vollständig per Env-Variablen konfigurieren. Die folgenden Variablen sind bezüglich allgemeiner Konfiguration verfügbar:

| Name                          | default      | Pflicht | Beschreibung                                                                                               |
| ----------------------------- | :----------- | ------- | ---------------------------------------------------------------------------------------------------------- |
| GRAFANA_TOKEN                 | -            | Ja      | Grafana token für die Authentifizierung bei Grafana Cloud                                                  |
| SITE_NAME                     | -            | Ja      | Name der Site in dem der Collector betreiben wird (Bspw. CMI Cloud Prod oder UMB).                         |
| AGENT_NAME                    | -            | Ja      | Name des Collector-Agent.                                                                                  |
| STACK_NAME                    | cminformatik | Nein    | Name des Grafana Cloud Stack. Wenn nicht angegeben, wird der default Stack aus dem Uplink-Modul verwendet. |
| BRANCH_NAME                   | master       | Nein    | Branch von welchem die verwendeten River-Module abgerufen werden sollen.                                   |
| LOG_LEVEL                     | info         | Nein    | Log-Level des Collector-Agent.                                                                             |
| ENABLE_OPENTELEMETRY_RECEIVER | false        | Nein    | Soll der OpenTelemetry Receiver aktiviert werden? true = Ja, false = Nein.                                 |
| ENABLE_AZURE_AUTODISCOVERY    | false        | Nein    | Soll die Azure Auto-Discovery Integration aktiviert werden? true = Ja, false = Nein.                       |
| ENABLE_PUSH_GATEWAY           | false        | Nein    | Soll der Push Gateway konfiguriert und gestartet werden? true = Ja, false = Nein.                          |
| ENABLE_FORWARDERS             | false        | Nein    | Wenn diese Einstellung auf true gesetzt wird, wird der Prometheus und Loki forwarder aktiviert.            |
| ENABLE_POSTGRES_MONITORING    | false        | Nein    | Wenn diese Einstellung auf true gesetzt wird, wird die Überwachung von Postgres Server aktiviert.          |

### OTEL-Collector

Wird `ENABLE_OPENTELEMETRY_RECEIVER = true` gesetzt, wird ein OpenTelemetry Receiver konfiguriert und gestartet. Diese hört auf den Ports 4317 (OTLP-GRPC) und 4318 (OTLP-HTTP). Die Schnittstelle kann genutzt werden, um Metriken, Logs und Traces an den Collector zu senden. Die Daten werden dann verarbeitet (filtering und tagging) und an den konfigurierten Grafana Cloud Stack gesendet.

### Azure Auto-Discorvery

Wird `ENABLE_AZURE_AUTODISCOVERY = true` gesetz, sucht der Collector automatisch nach VMs in der angegebenen Azure Subscription und scrapet den Agent und Windows/Linux Metrik-Endpunkt. Für die Integration sind die folgenden Einstellungen notwendig:

| Name                  | default | Pflicht | Beschreibung                                        |
| --------------------- | :------ | ------- | --------------------------------------------------- |
| AZURE_CLIENT_ID       | -       | Ja      | Client ID der Azure managed identity.               |
| AZURE_SUBSCRIPTION_ID | -       | Ja      | Subscription-ID, die der Collector überwachen soll. |
| AZURE_ENV_NAME        | -       | Ja      | Name des Azure Env. (Bspw. Prod oder Stage).        |

### Push Gateway

Mit der Variabel `ENABLE_PUSH_GATEWAY = true` kann ein Push Gateway gestartet werden. Der Gateway hört auf dem Port 9091 und kann genutzt werden, um Metriken per Post Request an den Collector zu senden. Für weitere Informationen kann die [folgende Dokumentation](https://github.com/prometheus/pushgateway/) konsultiert werden.

### Forwarders

Mit der Einstellung `ENABLE_FORWARDERS = true` werden die Prometheus und Loki Forwarder konfiguriert und gestartet. Diese hören auf den Ports 9998 (Prometheus) und 9999 (Loki). Die Schnittstellen können genutzt werden, um Metriken und Logs an den Collector zu senden. Die Daten werden dann verarbeitet (filtering und tagging) und an den konfigurierten Grafana Cloud Stack gesendet.

### Postgres Monitoring

Mit der Einstellung `ENABLE_POSTGRES_MONITORING = true` wird die Überwachung von Postgres Servern aktiviert. Die Konfiguration der Postgres Server erfolgt über die Env-Variable `POSTGRES_DATA_SOURCES`. Datenbanken auf den Servern werden automatisch discovered. Als Datenbank sollte somit immer `postgres` im String angegeben werden. Das folgende Beispiel zeigt die Konfiguration von zwei Postgres Servern:

```bash
POSTGRES_DATA_SOURCES="<identifier1>=postgresql://<username>:<password>@<server_name>:5432/postgres,<identifier2>=postgresql://<username>:<password>@<server_name>:5432/postgres"
```

> **_NOTE:_** Der server_name muss für jedes Element eindeutig sein und das Passwort darf keine im Connection-String enthaltene Sonderzeichen enthalten (Bspw. /, : oder , ).

### Testen des Collectors

Für die Secrets muss im Ordner `grafana_collector_container` ein Secrets file mit dem Namen `local_configuration.env` und folgenden Inhalt angelegt werden:

```bash
GRAFANA_TOKEN=<grafana_token>
BRANCH_NAME=<branch_name>
```

Um den Collector lokal zu testen, kann diser anschliessend mit dem folgenden Befehl gebaut und gestartet werden:

```bash
docker build --tag "grafana_collector_local_image:latest" .\grafana_collector_container\
docker compose -f .\grafana_collector_container\docker-compose.yaml up
```

## Grafana Agent River Module

Der Grafana Agent flow nutzt als Konfigurations-Sprache eine Eigenentwicklung von Grafana namens River. River erlaubt das Auslagern von Konfigurationen in sogenannte Module. Im Ordner `modules` befinden sich einige solche Module, die in verschiedenen Umgebungen verwendet werden (UMB, Netrics, Azure usw.). Genauere Informationen zu den Modulen können den jeweiligen Readme-Dateien entnommen werden. Weitere Informationen bezüglich Grafana Agent Flow und River könenn dem [folgenden Link](https://grafana.com/docs/agent/latest/flow/) entnommen werden.

## Tooling

Zum aktuellen Zeitpunkt existiert für River kein wirkliches Tooling. In der [folgenden Repository](https://github.com/rfratto/vscode-river) befindet sich eine basic VSCode Extension für Syntax-Highlighting.

## CI/CD

### Grafana River Formatter

Dieser Action such die Repo nach allen Dateien mit einer .river Endung ab und formatiert diese mit dem offiziellen River Formatter. Die Formatierten Datein werden anschliessend wieder in den aktiven Branch gepusht.
