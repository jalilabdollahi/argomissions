# Waves That Do Not Wait

## What broke
The runbook said "database first, API second", and the repo said it too: `beacon-db` carries
`argocd.argoproj.io/sync-wave: "1"`, `beacon-api` carries `"2"`. But the two things being ordered were
**Application** resources, and Argo CD does not know how to tell whether an Application is healthy. Wave 1 was
"done" the instant the `beacon-db` Application object existed, so wave 2 was created two seconds later while the
database was still replaying its log.

## Why Argo CD behaves this way
A sync runs wave by wave. After applying a wave, Argo CD waits until every resource in it is **Healthy** (and
a short delay) before it starts the next one. "Healthy" comes from the health assessment: built-in checks for
core kinds (Deployment, StatefulSet, Service, Ingress, Job, PVC ...), custom Lua checks in
`resource.customizations.health.<group>_<kind>`, or, for a kind without any check, simply *Healthy*.

Since Argo CD 1.8 the built-in Application check is gone: the root's health used to be computed from its
children, which made huge trees slow and fragile. In the root, a child Application is therefore always Healthy.
Argo CD 3.6.1 behaves the same (verified for this level): `argocd admin settings resource-overrides health` prints
`Health script is not configured for 'argoproj.io/Application'` on a stock install.

## The fix
Add a health customization for `argoproj.io/Application` to `argocd-cm` that returns the child's own
`status.health`. Then waves work across Applications: the root sync stays on wave 1 until `beacon-db` is
Healthy, then creates `beacon-api`. Argo CD reads the key without a restart. Because ordering only exists
*during* a sync, the platform had to be replayed from the root (delete the children, sync the root) before the
proof held: a fix that is only configured is not a fix that was observed.

## In real life
Every team that builds a platform with an app-of-apps (CRDs and controllers first, then workloads) hits this the
first time they bootstrap a cluster from scratch: it "works" on the old cluster because the dependencies were
already there. Operators that ship with CRDs (cert-manager, Istio, Crossplane providers) are the classic victims:
the next wave applies a custom resource before its CRD is registered. The same Lua trick exists for any custom
resource without health information.

## Commands worth remembering
```bash
argocd app get beacon-root                          # resource tree, waves, health per resource
argocd admin settings resource-overrides health obj.yaml --load-cluster-settings
kubectl -n argocd get cm argocd-cm -o yaml | grep customizations
argocd app sync <root> --async && argocd app wait <root> --health
```

## Common mistakes
* Re-numbering the waves (bigger gaps, negative numbers). Waves order resources; they cannot wait for something
  that never reports health.
* Deleting and re-creating one child by hand once the database is up: the order looks right for a moment, but the
  next cold start (a new cluster, a DR rebuild) is as unordered as before.
* Writing the Lua so that it always returns `Healthy`, which restores exactly the default behaviour.

## Argo CD 2.x vs 3.x
Nothing changed here: no default Application health check in either. In 3.x the key format
`resource.customizations.health.<group>_<kind>` is the supported one, and the old combined
`resource.customizations` key is deprecated. The `argocd-cm` changes are picked up live in both.
