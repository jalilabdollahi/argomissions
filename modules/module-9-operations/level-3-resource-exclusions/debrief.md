# The Invisible Kind

## What broke
`resource.exclusions` in `argocd-cm` told Argo CD to ignore every ConfigMap in every API group on every cluster.
The Application rendered the ConfigMap from Git, but Argo CD refused to apply it, to compare it, or to show it, so
the Deployment that mounts it never started. The application was Synced (Argo CD cannot be out of sync with
something it does not look at) and merely Progressing, with one easily missed condition:
`ExcludedResourceWarning: Resource /ConfigMap lexicon-pages is excluded in the settings`.

## Why Argo CD behaves this way
Exclusions are a cluster-wide performance tool. An excluded kind is dropped from the controller's cluster cache
(the watches and the memory they cost), from the diff and from the resource tree, and Git manifests of that kind
are skipped with a warning instead of an error. Rules have only three selectors: `apiGroups`, `kinds` and
`clusters`. There is no way to exclude by name or namespace, so a rule on a kind as common as ConfigMap affects every
single Application. Setting `resource.exclusions` also *replaces* Argo CD's built-in list (Endpoints,
EndpointSlice, Lease, events and a few more), so a hand-written list must repeat what you still want hidden. The
controller notices the change in `argocd-cm` live and rebuilds its cache; an Application then shows the
previously hidden resources on its next refresh and they need a normal sync.

## The fix
Remove the ConfigMap rule (or restrict it to the clusters where it makes sense), keep the rules for genuinely noisy
kinds, refresh, and sync so that Argo CD creates the ConfigMap itself. Applying the ConfigMap by hand would
make the pod start, but Argo CD would still be blind to it.

## In real life
Exclusions are tempting when the controller's memory grows: Events, EndpointSlices, Leases, cert-manager
CertificateRequests, Cilium identities. Excluding a kind that applications also contain turns into the most
confusing kind of outage: green sync, missing objects. Check `argocd app get` conditions whenever "Synced" and
reality disagree, and prefer `resource.inclusions` or narrow `apiGroups` over a wildcard.

## Commands worth remembering
```bash
argocd app get APP                       # conditions are printed first
kubectl -n argocd get cm argocd-cm -o jsonpath='{.data.resource\.exclusions}'
argocd app get APP --refresh
argocd app sync APP
```

## Common mistakes
* Applying the missing ConfigMap with `kubectl`: the pod runs, but Argo CD still does not manage it.
* Deleting `resource.exclusions` and assuming that nothing changes: that is fine here (the built-in defaults come
  back), but the platform team lost its customization.
* Expecting a restart to be needed, or restarting the controller anyway: argocd-cm is read live.

## Argo CD 2.x vs 3.x
On Argo CD v3.6.1 the exclusion list is applied live (verified: no controller restart was needed), and a custom
`resource.exclusions` still replaces the built-in default list instead of extending it.
