# Selector Is Immutable

## What broke
A harmless-looking commit added `commonLabels` to a Kustomization. Kustomize's `commonLabels` writes the labels
on every object **and into every selector** it knows about: the Deployment's `spec.selector.matchLabels` and the
Service's `spec.selector`. Argo CD tried to patch the live Deployment, and Kubernetes answered
`spec.selector: Invalid value: ...: field is immutable`. The sync failed, the old pods kept running.

## Why Argo CD behaves this way
Argo CD renders the Kustomization, diffs the result with the live objects and applies the difference. It does not
decide what is legal: `Deployment.spec.selector` has been immutable since `apps/v1`, because changing it would
orphan the ReplicaSets that match the old one. So the failure comes from the API server, and Argo CD reports it
verbatim in the operation message. Re-syncing the same commit cannot ever succeed. Newer Kustomize replaces
`commonLabels` (deprecated) by `labels:` with explicit switches: `includeSelectors` (default false) and
`includeTemplates` (default false, pod templates).

## The fix
Use `labels: [{pairs: {...}, includeSelectors: false, includeTemplates: true}]`. The labels land on object
metadata and pod templates, selectors stay as they were, and the Deployment rolls out new pods normally.
Putting the labels straight into the pod template or a patch also works. Deleting and re-creating the Deployment
"fixes" the sync but causes downtime and bakes the wide selector in for good.

## In real life
Org-wide label policies (cost centre, team, environment) are the usual trigger, and the failure often appears
only when the first Application using the Kustomization is synced after the change, because new clusters apply
fine. The same trap exists in Helm (`selector.matchLabels` built from a changing value) and with Service
`clusterIP`. When a label is for humans, billing or dashboards, it does not belong in a selector.

## Commands worth remembering
```bash
kubectl kustomize deploy/                 # render locally before pushing
argocd app manifests NAME                 # what Argo CD would apply
argocd app diff NAME
kubectl get deploy NAME -o jsonpath='{.spec.selector}'
```

## Common mistakes
- Syncing again (or enabling Replace/Force): the selector is still rejected, or the Deployment is recreated with downtime.
- Reverting the commit: the sync works, but the requested labels are gone.
- Setting `includeSelectors: false` without `includeTemplates: true`: the objects get the labels, the pods do not.

## Argo CD 2.x vs 3.x
The bundled Kustomize is 5.x: `commonLabels` still works but is deprecated in favour of `labels:`. Behaviour of the
immutable-field failure is the same in both Argo CD generations.
