# tracing-gitops

GitOps repository of the tracing team, managed by the root Application `tracing-root`.

* `apps/`       - Application manifests, one per service. Every service runs in the team project `tracing-team`.
* `workloads/`  - Kubernetes manifests of each service

The team project may deploy only from this repository and only into the namespaces `tracing-collector` and
`tracing-query` of the in-cluster destination.
