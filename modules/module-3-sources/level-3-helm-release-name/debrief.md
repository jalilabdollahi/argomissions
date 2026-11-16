# The Renamed Release

## What broke
The Application used to deploy plain manifests with fixed names (`tracker-api`). When it was pointed at the Helm
chart, names started coming from `{{ .Release.Name }}-api`. Argo CD passes the **Application name** as the
release name, so the chart produced `fleet-tracker-api`. Because the Application has automated sync with prune,
Argo CD created the new objects and deleted the old `tracker-api` Deployment and Service. Everything was green,
and every caller of `tracker-api.fleet` lost its backend.

## Why Argo CD behaves this way
Argo CD runs `helm template <release-name> <path> --namespace <destination namespace>`; the release name defaults
to `metadata.name` of the Application. Helm templates routinely derive object names, labels and selectors from
it. Argo CD does not install a Helm release (there is no `helm ls` entry), it only renders and applies, but
`.Release.Name` still means exactly what it means to Helm. `spec.source.helm.releaseName` overrides it without
renaming the Application. Which objects "belong" to an Application is decided by tracking annotations and the set
of rendered names: once the names changed, the old ones were simply no longer desired, and prune removed them.

## The fix
`argocd app set fleet-tracker --release-name tracker` (YAML: `spec.source.helm.releaseName: tracker`) so the
chart renders `tracker-api` again; the new objects are adopted and the leftovers pruned. Hard-coding the name
in the chart is equally valid when the chart has no other users.

## In real life
Migrating a service from plain YAML or Kustomize to Helm is the usual trigger, but so is renaming an Application
(for example `payments` to `payments-prod`) when a chart builds names from the release. Always diff the rendered
names before switching source (`helm template <release> ...` vs the live objects) and be careful with prune on a
Service other teams depend on. Selectors are immutable on a Deployment, so a changed label scheme causes a failed
sync instead of silence.

## Commands worth remembering
```bash
argocd app set NAME --release-name RELEASE
helm template RELEASE path/to/chart | grep -n "name:"
argocd app manifests NAME        # the names Argo CD will apply
argocd app diff NAME             # shows what a new render would change
```

## Common mistakes
- Passing a release name that already contains the suffix (`tracker-api` gives `tracker-api-api`).
- Re-applying the old manifests by hand: the name returns, but the service is not owned by the Application and runs the old release.
- Renaming the Application to fix the name: the Application name is an identity used by tracking, history and RBAC.
