# argocd-settings

Argo CD configuration of the platform cluster, applied by Application `argocd-settings` (self-heal on).
Change a setting here, open a pull request, merge; never edit the ConfigMaps in the cluster.

* `config/argocd-cm.yaml`       - general settings (URL, accounts, reconciliation timeouts)
* `config/argocd-rbac-cm.yaml`  - who may do what (policy.csv)
