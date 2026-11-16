# tariff-gitops

Managed by the root Application `tariff-root` (automated sync, prune enabled).

* `apps/`       - one Application manifest per tariff service
* `workloads/`  - Kubernetes manifests of each service

To retire a service, delete its manifest from `apps/`.
