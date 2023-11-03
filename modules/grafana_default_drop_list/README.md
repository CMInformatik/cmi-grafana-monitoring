# Grafana Agent default drop list

Das folgende Modul stellt Listen bereit, die Namen von Metriken enthalten, die nicht an Grafana Cloud gesendet werden sollen.

## Argumente

Das Modul akzeptiert keine Argumente.

## Exports

Das Modul exportiert folgende Werte:

| Name                    | Beschreibung                                                                   |
| ----------------------- | ------------------------------------------------------------------------------ |
| metrics_lable_drop_list | Eine Liste an Metrik-Namen, die nicht an Grafana Cloud gesendet werden sollen. |

## Beispiel

```bash
module.git "default_drop_lists" {
  repository = "https://github.com/CMInformatik/cmi-grafana-monitoring.git"
  path       = "modules/grafana_default_drop_list/module.river"
  revision   = "master"
}

prometheus.relabel "default_drop" {
  forward_to = [<your_target>]

  rule {
    source_labels = ["__name__"]
	regex  = join(module.git.default_drop_lists.exports.metrics_lable_drop_list, "|")
	action = "drop"
  }
}
```
