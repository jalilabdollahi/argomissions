# label-printer

The deployment of the label printing service is described by `deploy/app.conf` (plain `key=value`).
Argo CD renders it into Kubernetes manifests with the in-house `kv-render` config management plugin.
