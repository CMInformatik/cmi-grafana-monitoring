# Grafana Agent Uplink Module

Das folgende Modul dient als Basiskonfiguration für alle Collector-Agents der CMI.
Das Modul stellt Receiver für Logs, Metriken und Traces bereit. Empfangene Daten werden mit default Tags versehen und an den spezifizierten Grafana Cloud Stack gesendet.

## Argumente

Das Modul akzeptiert folgende Argumente:

| Name                      | default      | Pflicht | Beschreibung                                                                       |
| ------------------------- | :----------- | ------- | ---------------------------------------------------------------------------------- |
| token                     | -            | Ja      | Grafana token für die Authentifizierung bei Grafana Cloud                          |
| site                      | -            | Ja      | Name der Site in dem der Collector betreiben wird (Bspw. CMI Cloud Prod oder UMB). |
| submodule_branch          | master       | Nein    | Branch der für git submode verwendet werden soll.                                  |
| stack_name                | cminformatik | Nein    | Name des Grafana Cloud Stack an den die Daten gesendet werden sollen.              |
| proxy_url                 | null         | Nein    | Proxy-URL über den Daten an Grafana Cloud gesendet werden sollen.                  |
| additional_lables_to_drop | []           | Nein    | Liste an Labels, die zusätzlich zu den default Labels gedroppt werden sollen.      |

## Exports

Das Modul exportiert die folgenden Variablen:

| Name                | Beschreibung                                                                                                                      |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| metrics_receiver    | Endpunkt zum senden von Metriken an Grafana Cloud.                                                                                |
| logs_receiver       | Endpunkt zum senden von Logs an Grafana Cloud.                                                                                    |
| traces_receiver     | Endpunk zum senden von Traces an Grafana Cloud.                                                                                   |
| agent_logs_receiver | Log-Endpunkt für Grafana Agent Logs. Verarbeitet die Logs zusätzlich und sendet diese anschliessend an den internen logs_receiver |

## Beispiel

```bash
module.git "base_module" {
  repository = "https://github.com/CMInformatik/cmi-grafana-monitoring.git"
  path       = "modules/grafana_agent_uplink/module.river"
  revision   = "master"
  arguments {
    token            = "<our_token>"
    site             = "<your_site_name>"
  }
}

prometheus.scrape "integrations" {
  targets = <your_scrape_targets>
  forward_to = [
    module.git.base_module.exports.metrics_receiver,
  ]
}

```
