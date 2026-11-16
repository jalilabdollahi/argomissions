# Fighting The Autoscaler

## What broke
Git pinned `replicas: 2` and an autoscaler wanted 4. With self-heal Argo CD reverted every change, the autoscaler
raised it again, pods were started and killed in a loop, and the Application was permanently `OutOfSync`. Two
controllers claimed ownership of the same field, and neither was wrong.

## Why Argo CD behaves this way
Argo CD's contract is "Git is the whole truth for the fields it declares". An HPA's contract is "I own
`spec.replicas`". Both are legitimate; the Application needs to say which fields belong to somebody else.

* `spec.ignoreDifferences` removes fields (by `jsonPointers`, `jqPathExpressions` or `managedFieldsManagers`) from
  the comparison, so the Application is `Synced` even though the live value differs.
* By default that only affects the *diff*. When a sync happens for another reason, Argo CD still applies the whole
  Git manifest, so the replica count would be reset once. `RespectIgnoreDifferences=true` makes syncs honour the
  ignore list too.
* The other solution is to stop declaring the field: without `replicas` in Git, Argo CD has no opinion. (With
  client-side apply, the sync that removes the line deletes the field once, so the Deployment briefly returns to the
  default of 1 replica before the autoscaler takes over again.)

Self-heal backs off between attempts (the operation's `autoHealAttemptsCount` grows), which is why the fight is
visible as repeated automated operations rather than a tight loop.

## The fix
Add the `ignoreDifferences` entry for `/spec/replicas` on Deployment `quote-api` and enable
`RespectIgnoreDifferences=true`, or remove `replicas` from the manifest. Keep self-heal on: it still protects every
other field.

## In real life
Every Argo CD + HPA, KEDA or VPA installation hits this. The same applies to anything another controller owns:
service meshes injecting sidecars, cert-manager CA bundles, operators writing status-like fields into spec.

## Commands worth remembering
```bash
argocd app diff NAME
kubectl get deploy NAME --show-managed-fields -o yaml     # who writes which field
kubectl get hpa; kubectl describe hpa NAME
```

## Common mistakes
- Turning self-heal off: the fight stops, drift in every other field is no longer corrected.
- Adding `ignoreDifferences` without `RespectIgnoreDifferences=true` and being surprised by one reset per sync.
- Deleting or "pausing" the autoscaler, which only moves the outage to the next traffic peak.
