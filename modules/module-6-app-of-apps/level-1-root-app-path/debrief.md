# Debrief — The Empty Root

## What broke
The root Application `shopfront-root` read folder `apps/`. That folder held a README and no manifest, while the
child Application YAML files lived in `argocd/apps/`. Argo CD rendered an empty list of resources and compared it
with a cluster that had none: `Synced`, `Healthy`, zero children. Nothing was wrong from Argo CD's point of view.

## Why Argo CD behaves this way
An app-of-apps root is an ordinary Application whose manifests happen to be of kind `Application`. Sync status means
"the live objects equal what the source renders", and an empty render equals an empty cluster. A path that exists but
contains no `.yaml`, `.yml` or `.json` file is not an error (a path that does not exist is: `app path does not exist`).
A directory source is also not recursive by default, so pointing the root at the parent folder `argocd/` would be empty
too. Children created by the root get the tracking annotation `argocd.argoproj.io/tracking-id: shopfront-root:...`, which
is how you tell a generated child from one applied by hand.

## The fix
Point the root at the folder that directly contains the child manifests (`argocd app set shopfront-root --path
argocd/apps`, or the same change in the root's own manifest), or move the manifests to where the root looks. With
automated sync the children appear within seconds and each starts its own sync.

## In real life
"Green but empty" roots show up after a repository reorganisation: someone moves `apps/` and nobody updates the
bootstrap Application, or the root points at a folder that exists but is empty on the branch it tracks. Alert on the
number of resources of the root, not only on its status.

## Commands worth remembering
- `argocd app manifests ROOT` — what the root really renders (empty means empty).
- `argocd app get ROOT` — the Path and the resource list.
- `kubectl -n argocd get applications` — which children exist, with their tracking annotation.

## Common mistakes
- Trusting `Synced/Healthy` on a root: check that it lists the children you expect.
- `kubectl apply -f` of the child Applications: they run, but the root does not own them, so they are never pruned or
  healed by it.
- Pointing the root at a parent folder and expecting recursion; use the exact folder or `directory.recurse: true`.
