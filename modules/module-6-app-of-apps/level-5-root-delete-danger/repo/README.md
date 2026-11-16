# inventory-gitops

Managed by the root Application `inventory-root` (automated sync, prune enabled).

* `apps/`       - one Application manifest per inventory service
* `workloads/`  - Kubernetes manifests of each service

Deleting an Application manifest from `apps/` retires the service together with its workloads.
