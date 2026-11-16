# stockroom-db

Inventory database service for the stockroom. Consumers call `http://stockroom-db.stockroom`.

* `manifests/` the original plain manifests (what runs today)
* `chart/` the Helm chart that replaces them (`values.yaml` = laptop defaults, `values/production.yaml` = production)

The data lives on a PersistentVolumeClaim; losing it means restoring from last night's backup.
