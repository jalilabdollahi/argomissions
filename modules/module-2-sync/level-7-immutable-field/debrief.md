# Field Is Immutable

## What broke
A commit changed `spec.selector.matchLabels` of a Deployment that was already running. Argo CD patched the Service
(its selector is mutable) but the API server refused the Deployment: `spec.selector: Invalid value: ... field is
immutable`. The sync ended `Failed`, the Application stayed `OutOfSync`, and because the Service already selected the
new label while the old pods carried the old one, traffic stopped.

## Why Argo CD behaves this way
Argo CD is not smarter than `kubectl apply`: a sync computes a patch between the live object and the Git manifest and
sends it to the API server. Some fields can never be changed on a live object (Deployment/StatefulSet selectors, a Job's
pod template, a Service's `clusterIP`, a PVC's storage class ...). The server rejects the update and Argo CD reports the
server's message verbatim on the resource.

Tasks of a sync run in waves but one failing resource does not roll back the others, so the Service change had already
been applied. The way forward is to replace the object: delete it and create it again.

* `Replace=true` (sync option, or per-resource annotation) swaps *patch* for `kubectl replace`. That is useful for
  oversized annotations or CRDs, but replacing is still an *update* and selectors stay immutable: it fails with
  `error when replacing ... field is immutable`.
* `--force` (the **Force** checkbox in the UI) tells Argo CD to delete the object and create it afresh whenever it cannot
  be updated. That is what an immutable field needs.
* Deleting the object yourself and letting the next sync re-create it is the same thing done by hand.

## The fix
Keep the new selector in Git (it is the desired state) and run `argocd app sync ticket-desk --force`. Argo CD deletes
Deployment `ticket-desk` and creates it with the new selector; the Application turns Synced and Healthy and the
Service finds the new pods.

## In real life
Relabelling "for consistency" is the classic trigger, as are changing a Job's image or template (Jobs are immutable
too), growing a StatefulSet's `volumeClaimTemplates`, and Helm chart upgrades that rename labels. Deleting a Deployment
means a short outage unless you plan it: create the new Deployment under a new name first, shift traffic, then remove
the old one in a later commit. For Jobs, `argocd.argoproj.io/hook: Sync` with
`hook-delete-policy: BeforeHookCreation` is the idiomatic way to re-run them.

## Commands worth remembering
```bash
argocd app get ticket-desk                  # which resource failed and the server's message
argocd app diff ticket-desk                 # live vs Git
argocd app sync ticket-desk --force         # delete and re-create what cannot be updated
argocd app sync ticket-desk --replace       # kubectl replace instead of patch
argocd app delete-resource ticket-desk --kind Deployment --resource-name ticket-desk
```

## Common mistakes
- Reverting the commit to make the error go away: the labels you wanted are lost and the problem returns with the next
  relabel.
- Reaching for `Replace=true` alone: replacing still cannot change a selector.
- Deleting the Deployment by hand and never syncing: Argo CD shows `Missing`/OutOfSync and nothing runs.

## Argo CD 2.x vs 3.x
Nothing changed in the immutable-field behaviour between 2.x and 3.x. Note that in Argo CD 3.x resources are tracked by
annotation by default, so a re-created Deployment carries the `argocd.argoproj.io/tracking-id` annotation again as soon as
the sync creates it; nothing has to be adopted by hand.
