# Black Friday Freeze

## What broke
Four independent faults, stacked so that fixing one showed the next:
1. **The freeze had no exception.** Project `blackfriday` carried a deny sync window that is active every minute,
   so the approved v9.0 release could neither be auto-synced nor started by hand (`cannot sync: blocked by sync window`).
2. **`bf-promo` was never allowed to deploy.** Its namespace `bf-promo` was not among the project's destinations
   (`InvalidSpecError`). After that was fixed, the first sync failed on a second project rule: the `CreateNamespace=true`
   option makes Argo CD create a cluster-scoped `Namespace`, which the project did not allow.
3. **Git and the autoscaler both owned `spec.replicas`.** Hidden while the freeze held, because a deny window also
   blocks self-heal. Once a sync can run, Argo CD would set 2 and `load-scaler` would set 6 again, forever.
4. **`bf-promo` is a manual-sync Application**: its first release sat there until somebody pressed Sync.

## Why Argo CD behaves this way
Sync windows are enforced by the application controller on every sync, automated or manual; `manualSync: true`
lets a human-started sync through while keeping automation blocked. A project is a trust boundary: destinations
say where an app may deploy, `clusterResourceWhitelist` says which cluster-scoped kinds it may create (a Namespace
included). The comparison between Git and the cluster is purely field-based, so two controllers writing one field
will fight unless you declare the field's owner with `ignoreDifferences`; and `RespectIgnoreDifferences=true`
extends that to the sync itself, otherwise a sync triggered by another change would still write Git's value.

## The fix
`argocd proj windows enable-manual-sync`, `argocd proj add-destination`, `argocd proj allow-cluster-resource`
(or pre-create the namespace), an `ignoreDifferences` rule for `/spec/replicas` with `RespectIgnoreDifferences=true`,
then sync `bf-cart` and `bf-promo`. The freeze, self-heal, the autoscaler and the project boundary all stay.

## In real life
Launch-day incidents are rarely one bug: a freeze added in a calm week, a new service whose project nobody
updated, and an autoscaler that only misbehaves once load arrives. The usual wrong answers are the ones that
remove the safety net: delete the window, set the project to `*`, switch off self-heal, turn the autoscaler off.
All of them "work" at 06:10 and cost a post-mortem. A good freeze defines in advance who may sync during it and
how, and the post-incident action items are usually: `manualSync` on the window, replica ownership in the app
spec, and a pre-launch dry run of every new Application through `argocd app sync --dry-run`.

## Commands worth remembering
```bash
argocd proj windows list|enable-manual-sync|add|delete PROJECT [ID]
argocd proj get PROJECT
argocd proj add-destination PROJECT SERVER NAMESPACE
argocd proj allow-cluster-resource PROJECT GROUP KIND
argocd app get APP                 # SyncWindow, Conditions, last operation
kubectl get deploy X -o jsonpath='{.metadata.generation}'   # is somebody rewriting the spec?
```

## Common mistakes
- Deleting the freeze window: the release ships, and so does every other pending change.
- `argocd proj add-destination ... '*'` or `*/*` cluster resources: the project stops being a boundary.
- Switching self-heal off to stop the replica fight: the cart now ignores every other kind of drift.
- `ignoreDifferences` without `RespectIgnoreDifferences=true`: Synced in the UI, but the next sync resets the replicas.
- Removing the autoscaler: it belongs to another team, and the next traffic spike hits 2 pods.

## Argo CD 2.x vs 3.x
Behaviour here is the same on 2.x and 3.6.1: `CreateNamespace=true` needs the project to allow the cluster-scoped
`Namespace` kind (`resource :Namespace is not permitted in project`), and a deny window also stops automated
self-heal. What changed in 3.x is the default resource tracking method (annotation instead of label), which
makes the owner of each object readable in `argocd.argoproj.io/tracking-id`.
