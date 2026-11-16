# inventory-sync

Warehouse stock synchroniser. Kustomize layout:

* `kustomize/base` - shared manifests, not meant to be deployed on its own
* `kustomize/overlays/staging` - staging (namespace `inventory-staging`, not managed here yet)
* `kustomize/overlays/prod` - production, deployed to namespace `inventory`
