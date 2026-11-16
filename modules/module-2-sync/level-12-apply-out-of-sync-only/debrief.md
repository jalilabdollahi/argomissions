# The Slow Sync

## What broke
Each sync of `region-configs` applied every object in the Application, although only one or two had changed. Eight region
ConfigMaps and a Deployment were re-applied needlessly (slow on big Applications, noisy on the API server), and one of the
re-applied objects, `visit-counter`, belongs at runtime to another controller: its live value `4821` was overwritten with the `0`
that Git carries.

## Why Argo CD behaves this way
A sync, by default, is "apply the whole rendered manifest set". Comparison and apply are separate steps: `ignoreDifferences` makes
the comparison skip a field, so the Application shows Synced while the counter drifts, but when a sync does run it still sends the
Git version of every resource. (`RespectIgnoreDifferences=true` is the dedicated option for keeping ignored fields out of the apply.)
With `ApplyOutOfSyncOnly=true` a sync skips resources whose comparison status is Synced and only applies the ones that are
OutOfSync, so neither untouched objects nor the other controllers' data are written. A side effect worth knowing: objects that
nobody changes keep their `resourceVersion` and `managedFields` timestamps across syncs.

## The fix
Add the sync option `ApplyOutOfSyncOnly=true` to the Application **before** syncing r42, then sync. Only `edge-banner` and
`region-eu-west` are applied; `visit-counter` keeps `4821`. Setting the option after a plain sync would document the lesson but not
bring the counter back.

## In real life
Large Applications (hundreds of resources, CRDs, big ConfigMaps) sync much faster with it, and so do clusters with a loaded API server.
It is also the standard remedy when controllers or admission webhooks write into objects Argo CD deploys. Caveats: it does not heal
drift by itself that the comparison cannot see (ignored fields), and a resource that is Synced but was changed outside the comparison
is not re-applied; use `RespectIgnoreDifferences=true` when you need ignored fields excluded from the apply rather than the sync.

## Commands worth remembering
```bash
argocd app diff APP                                  # what is actually out of sync
argocd app set APP --sync-option ApplyOutOfSyncOnly=true
argocd app sync APP --apply-out-of-sync-only         # one-off
kubectl get cm -o custom-columns=N:.metadata.name,RV:.metadata.resourceVersion
```

## Common mistakes
- Syncing first and setting the option afterwards: the counter is already gone.
- Believing `ignoreDifferences` protects the field during a sync: it only hides it from the diff.
- Restoring the counter with `kubectl patch` and calling it done: the next release resets it again.

## Argo CD 2.x vs 3.x
`ApplyOutOfSyncOnly` behaves the same in 2.x and 3.x. Verified on 3.6.1: with a plain sync `visit-counter` is reported
`configured` and reset to `0`; with the option it is left alone and keeps its resourceVersion. As in earlier levels the CLI and UI copy the
Application's sync options into the sync operation; a raw `operation` patch would not.
