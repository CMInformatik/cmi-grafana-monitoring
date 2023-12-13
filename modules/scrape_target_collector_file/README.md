# Grafana Agent File Scrape-Target Collector

Das folgende Modul list Scrape-Targets aus einer spezifizierten Datei aus und stellt diese als **target** Liste zur Verfügung.

## Argumente

Das Modul akzeptiert folgende Argumente:

| Name                      | default | Pflicht | Beschreibung                                 |
| ------------------------- | ------- | ------- | -------------------------------------------- |
| windows_targets_file_path | -       | Ja      | Pfad zur JSON-Datei mit den Windows-Targets. |
| mssql_targets_file_path   | -       | Ja      | Pfad zur JSON-Datei mit den MSSQL-Targets.   |
| linux_targets_file_path   | -       | Ja      | Pfad zur JSON-Datei mit den Linux-Targets    |

## Exports

Das Modul exportiert die folgenden Variablen:

| Name    | Beschreibung                                                                                                                                                                                                                                                               |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| targets | Eine Liste aller Scrape-Targets, die in den verschiedenen Dateien spezifiziert wurden. Für alle Windows und Linux Targets wird automatisch ein zusätzliches Target für den Grafana Agent angelegt. Dieser output kann einem Prometheus.scrape als targets übergeben werden. |

## Beispiel

```bash
module.git "file_scrape_targets" {
  repository = "https://github.com/CMInformatik/cmi-grafana-monitoring.git"
  path       = "modules/scrape-target-collector-file.river"
  revision = "master"
  arguments {
    windows_targets_file_path = "C:\\CMI-Grafana\\windows_targets.json"
    mssql_targets_file_path = "C:\\CMI-Grafana\\mssql_targets.json"
	linux_targets_file_path = "C:\\CMI-Grafana\\linux_targets.json"
  }
}

prometheus.scrape "integrations" {
  targets = module.git.file_scrape_targets.exports.targets
  forward_to = [
    module.git.base_module.exports.metrics_receiver,
  ]
}
```
