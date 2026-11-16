# Delete The Set, Lose The Fleet

## What broke
Nothing was broken yet: the mission was to avoid breaking it. The ApplicationSet had to be replaced by one with a
new name, and an ApplicationSet cannot be renamed, so the only way is delete and create. Done naively, that deletes
the three generated Applications and, through their finalizer, every Deployment and Service they manage: the
kiosks would have stopped serving until the new set had regenerated and re-synced everything.

## Why Argo CD behaves this way
Generated Applications carry an `ownerReference` to their ApplicationSet. When the owner is deleted, Kubernetes
garbage-collects the children. The ApplicationSet controller also puts the finalizer
`resources-finalizer.argocd.argoproj.io` on every Application it generates, so deleting an Application is
"cascading" by default: Argo CD first deletes everything the Application deployed, then lets the Application go.
Deleting the set is therefore the same as deleting the whole fleet and what it runs.

Two documented mechanisms break that chain:

* `spec.syncPolicy.preserveResourcesOnDeletion: true` makes the controller stop adding (and remove) the finalizer, so
  the Applications are deleted but their workloads stay. The new ApplicationSet creates Applications with the same
  names and the same tracking ids; Argo CD finds the objects already there, compares them with Git and has nothing to
  change.
* `kubectl delete ... --cascade=orphan` deletes only the ApplicationSet and removes the owner reference from its
  Applications. They keep running and the new set with the same generated names adopts them.

## The fix
Either of the two, then apply `kiosk-fleet`. Prove it the way the validator does: the UID of every Deployment and
Service is unchanged, so nothing was deleted and recreated.

## In real life
Renaming, moving to another namespace or splitting an ApplicationSet is routine in a growing GitOps repo, and "delete
and re-create" is how people do it. Production fleets have lost workloads to a one-line `kubectl delete`. Many
teams set `preserveResourcesOnDeletion: true` on every production ApplicationSet from day one, and use
`applicationsSync: create-only` / `create-update` (no delete) so that removing an element cannot prune an app either.
Whatever you choose, check that the Applications lost their finalizer before you delete.

## Commands worth remembering
```bash
kubectl -n argocd get application X -o jsonpath='{.metadata.finalizers}'
kubectl -n argocd get applications -o custom-columns=N:.metadata.name,OWNER:.metadata.ownerReferences[0].name
kubectl -n argocd delete applicationset X --cascade=orphan
kubectl explain applicationset.spec.syncPolicy
```

## Common mistakes
- Setting `preserveResourcesOnDeletion` and deleting right away: the finalizer is removed by the controller on its
  next reconcile; delete before that and the cascade still happens.
- Applying `kiosk-fleet` while `kiosk-apps` still exists: two sets generate the same Application names and fight
  for ownership.
- Stripping finalizers from every Application "to be safe" and deleting the namespaces afterwards.
