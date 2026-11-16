# tidewater-gitops

Everything that runs on the Tidewater payments platform. Argo CD is the only thing that deploys.

```
bootstrap/root.yaml     the one Application that is applied by hand, once per cluster (it manages platform/)
platform/projects/      AppProjects (sync-wave -1: they must exist before the Applications)
platform/apps/          one child Application per component
workloads/              the manifests each child deploys
```

## New cluster runbook
1. Install Argo CD.
2. `kubectl apply -f bootstrap/root.yaml`
3. Everything else comes from this repository.

This repository is private. Argo CD reads it with the read-only Gitea machine user (see the platform handoff).
