# lighthouse-gitops

Everything that runs on the Lighthouse platform cluster, as code.

* `platform/projects/` - AppProjects (`infra`, `services`); they have to exist before any Application uses them
* `platform/apps/`     - one child Application per component, ordered with sync-waves (cache, then gateway and catalog)
* `platform/apps/_archive/` - retired components, kept for the audit trail only, never deployed
* `workloads/`         - Kubernetes manifests of the components

## Bootstrap

The cluster is empty except for Argo CD. A single root Application named `lighthouse-bootstrap` (namespace `argocd`)
brings up the projects and the child Applications; nothing else is applied by hand. Its manifest is not in this
repository yet.
