# Grafana Agent default drop list

Das folgende Modul exportiert Listen von Lables, die in Loki Logs nicht gedroppt werden sollen.

## Argumente

Das Modul akzeptiert keine Argumente.

## Exports

Das Modul exportiert folgende Werte:

| Name                    | Beschreibung                                                                   |
| ----------------------- | ------------------------------------------------------------------------------ |
| loki_lable_keep_list | Eine Liste an Lables, die in Loki Logs enthalten sein soll. |

## Beispiel

Das folgende Beispiel zeigt, wie die von diesem Modul exportierte Liste verwendet werden kann, um alle Labels aus Loki Logs zu entfernen, die nicht in der Liste enthalten sind.

```bash
module.git "default_drop_lists" {
  repository = "https://github.com/CMInformatik/cmi-grafana-monitoring.git"
  path       = "modules/grafana_lable_keep_list/module.river"
  revision   = "master"
}

loki.process "only_keep_these_lables" {
  forward_to = [<your_target>]

  stage.label_keep  {
    values = module.git.default_drop_lists.exports.loki_lable_keep_list
  }
}
```
