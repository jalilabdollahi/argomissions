# Half The Manifests

## What broke
The `inventory` Application pointed at `deploy/`, but all manifests lived in `deploy/web/` and `deploy/db/`.
Argo CD found no YAML directly in `deploy/`, rendered **zero objects**, compared that empty set with an empty
namespace and happily reported `Synced` and `Healthy`. Nothing was wrong from Argo CD's point of view.

## Why Argo CD behaves this way
When a source path has no `Chart.yaml`, no `kustomization.yaml` and no config-management plugin, Argo CD treats
it as a plain **directory** source and reads `*.yaml`, `*.yml` and `*.json` files. By default that read is not
recursive: only files directly inside the path count. `spec.source.directory.recurse: true` makes the
repo-server walk the whole tree. "Nothing to deploy" is a perfectly valid desired state, so there is no error and
no warning: a green Application can manage nothing at all.

## The fix
Set `directory.recurse: true` on the Application (`argocd app set inventory --directory-recurse`, the UI
checkbox, or the YAML) and sync. Both tiers appear, with Argo CD's tracking annotation. Flattening the folders
would also render, but it throws away the team's layout, which is why this mission keeps it.

## In real life
This bites teams that reorganise a repo into per-component folders, or migrate from one big manifest file to a
tree, and forget that the Application was written for the old shape. Because the result is Synced/Healthy,
alerts stay quiet and the outage is discovered by users. A habit worth having: after changing a path, look at
the resource count on the Application, not just its colour. If you prefer one Application per tier, point two
Applications (or an ApplicationSet) at `deploy/web` and `deploy/db` instead of recursing.

## Commands worth remembering
```bash
argocd app get NAME                  # resources list: how many objects does it manage?
argocd app manifests NAME            # what the repo-server rendered
argocd app set NAME --directory-recurse
argocd app set NAME --directory-exclude 'glob'   # see the next level in this module
```

## Common mistakes
- Trusting the green tick: `Synced` only says the (possibly empty) rendered set matches the cluster.
- Pointing the Application at one subfolder (`deploy/web`): the web tier appears and the database is silently
  missing.
- `kubectl apply -R` on the folder: the pods run but Argo CD still renders nothing and owns nothing.
