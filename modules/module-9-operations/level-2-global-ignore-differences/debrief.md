# Every App Is OutOfSync

## What broke
A controller outside Git (the security team's `complyd`) rewrites a label on every Deployment of the cluster.
Git says `scan: pending`, the live object says `scan-<epoch>`, so every Application that contains a Deployment is
OutOfSync, forever, no matter how often it is synced. Module 2 showed the per-Application answer
(`spec.ignoreDifferences`); here the problem is not one Application but the whole installation.

## Why Argo CD behaves this way
Argo CD compares the desired manifest from Git with the live object field by field and only ignores what it is
told to ignore. Rules can live in two places: in an Application (`spec.ignoreDifferences`, applies to that
Application only) and in the `argocd-cm` ConfigMap, where
`resource.customizations.ignoreDifferences.<group>_<Kind>` (or `.all`) applies to every Application on every
cluster. Both take `jsonPointers`, `jqPathExpressions` or `managedFieldsManagers` (ignore everything a named field
manager wrote). The controller reads `argocd-cm` live, no restart; an Application picks the new rule up on its
next refresh (here within the reconciliation timeout, or at once with `argocd app get X --refresh`).

## The fix
One key in `argocd-cm`: `resource.customizations.ignoreDifferences.apps_Deployment` with
`jsonPointers: [/metadata/labels/complyd.argomissions.io~1scan]` (a `/` in a label name is `~1`). All current and
future Applications now ignore that label, the scanner keeps running, and nothing else is hidden.

## In real life
Mutating admission webhooks, service meshes injecting sidecars, cost allocation tools, autoscalers, cert
injectors and policy engines all write fields that Git does not contain. Fixing it per Application means every
team rediscovers the problem. A platform team puts the rule in `argocd-cm` (managed in Git, like everything
else), scoped as narrowly as the problem allows: one field, one kind. Ignoring `/spec` or `/metadata` globally
silently disables drift detection for everyone.

## Commands worth remembering
```bash
argocd app diff APP
kubectl get deploy X -o json | jq '.metadata.managedFields'
kubectl -n argocd get cm argocd-cm -o yaml
argocd app get APP --refresh
```

## Common mistakes
* Copying `ignoreDifferences` into every Application: works for today's apps, the next one breaks again.
* Ignoring too much (`/spec`, `/metadata`): the app is green, but a real hotfix or a deleted label is invisible.
* Forgetting `~1` for the slash in a label name, so the pointer matches nothing and the app stays OutOfSync.

## Argo CD 2.x vs 3.x
The global `resource.customizations.ignoreDifferences.<group>_<Kind>` keys and `managedFieldsManagers` work the
same in 2.x and 3.x. With 3.x annotation-based tracking, Argo CD's own tracking annotation is not a diff
source, and only fields that Git sets explicitly can drift: that is why this level uses a label Git declares
(a label or annotation that only appears on the live object is not compared at all).
