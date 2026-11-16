# Keep The Data

## What broke
Nothing yet, and that was the point: with auto-prune on, deleting `pvc.yaml` from Git would have deleted the
PersistentVolumeClaim, and with it (depending on the reclaim policy) the volume holding the customers' photos.
The task was to let a manifest leave the repository without Argo CD deleting what it describes.

## Why Argo CD behaves this way
Prune deletes every tracked live object that is no longer rendered from Git. Two annotations change that for one
object:

* `argocd.argoproj.io/sync-options: Prune=false` makes a sync skip deleting it (the sync result says
  `PruneSkipped` / `ignored (no prune)`). Argo CD reads it from the **live** object, so it has to be applied by an
  earlier sync; putting it in the same commit that removes the file is too late. The same annotation exists for
  the whole Application as a sync option, and `Delete=false` protects an object from deletion when the
  *Application* is deleted.
* Skipping the prune leaves a tracked object without a Git counterpart, which Argo CD reports as `OutOfSync`
  (`requiresPruning: true`). `argocd.argoproj.io/compare-options: IgnoreExtraneous` excludes such an object from
  the Application's sync status, so the app is `Synced` while the claim stays untouched.

On Argo CD 3.6.1 we verified the sequence: with `Prune=false` alone the Application stays `OutOfSync` for good;
adding `IgnoreExtraneous` makes it `Synced`. The claim is still tracked (its `tracking-id` annotation remains)
until the storage application adopts it.

## The fix
Put both annotations on the claim in Git, let a sync apply them, then delete the manifest. (Putting them on the
live object with `kubectl annotate` before deleting the file works too, but then Git does not document why.)

## In real life
Storage, databases, certificates, load balancers and namespaces are things you never want a typo in Git to
delete. Moving ownership between Applications (or between repos) is the classic moment where prune bites: the
old app prunes, the new app has not synced yet. A Kubernetes protection also helped here: a claim in use by a pod
stays `Terminating` until the pod is gone, which gives you a window, not a fix.

## Commands worth remembering
```bash
kubectl -n NS get pvc NAME -o jsonpath='{.metadata.uid}'
kubectl annotate pvc NAME argocd.argoproj.io/sync-options=Prune=false
argocd app get NAME                      # "ignored (no prune)" on the resource
argocd app set NAME --sync-option Prune=false     # for a whole Application
```

## Common mistakes
- Deleting the manifest first, or in the same commit: the annotation is not on the live object yet and the claim is pruned.
- Stopping at `Prune=false` and accepting a permanently `OutOfSync` Application (or turning prune off for everything).
- Believing `Terminating` means the data is safe: it only means the pod still holds the claim.

## Argo CD 2.x vs 3.x
The curriculum expected `Prune=false` alone to be enough. It is not: on 3.6.1 the Application stays `OutOfSync`
with the orphaned object marked as requiring pruning, so `IgnoreExtraneous` is the second half of the answer.
Resource tracking is annotation-based in 3.x (label-based in 2.x), so the tracking-id lives in an annotation, which
is also why moving an object between Applications is done by changing that annotation.
