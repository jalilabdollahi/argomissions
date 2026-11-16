# Two Owners, One ConfigMap

## What broke
Two Applications each declared a ConfigMap `feature-flags` in the same namespace, with different content. Argo CD marks every
object it deploys with the annotation `argocd.argoproj.io/tracking-id: <app>:<group>/<kind>:<namespace>/<name>`. The ConfigMap
carried `cart-service:...`, so `promo-banner`, which also wanted it, saw a resource belonging to someone else and raised
`SharedResourceWarning: ConfigMap/feature-flags is part of applications argocd/promo-banner and cart-service`. The cluster could
never equal both Git copies: one Application stayed OutOfSync and the live flags held only one service's key.

## Why Argo CD behaves this way
Ownership in Argo CD is a single name in an annotation. Argo CD compares each Application's Git state with the live objects that
carry (or would carry) its tracking id, so an object declared by two Applications cannot be "in sync" for both. It warns rather than
refuses by default, because moving a resource from one Application to another legitimately passes through this state.
The sync option `FailOnSharedResource=true` upgrades the warning into a failed sync for the Application that does not own the object;
that exposes the problem but does not remove it.

## The fix
Make Git say it once. Pick the Application that should own `feature-flags`, put the complete content there (both keys), and delete
the manifest from the other folder. Argo CD re-tracks nothing by hand: after the refresh the owner is Synced, the other Application no
longer lists the ConfigMap, and the warning disappears. Neither choice of owner is wrong, but merging the content is part of the job.

## In real life
This happens with shared config (feature flags, CA bundles, namespaces, NetworkPolicies, ServiceAccounts), with monorepos where two
Applications' paths overlap, and with a Helm chart installed twice into one namespace. Prefer a small third Application (or the
platform team's repo) that owns shared objects, and let the others only consume them. Mind that pruning an object out of the Application
that is *not* its owner does not delete it: prune only removes objects tracked as that Application.

## Commands worth remembering
```bash
argocd app get APP                                  # conditions such as SharedResourceWarning
kubectl get cm NAME -o jsonpath='{.metadata.annotations}'    # tracking-id names the owner
argocd app manifests APP | grep -n 'kind: ConfigMap'
grep -rn "name: feature-flags" repo/                # who declares it in Git
argocd app get APP --refresh
```

## Common mistakes
- Adding `FailOnSharedResource=true` and calling it done: the second owner now fails loudly, Git still declares the object twice.
- Deleting the manifest from one folder without merging its keys: one service silently loses its flag.
- Making the two copies identical: the warning stays, because the problem is two owners, not two contents.

## Argo CD 2.x vs 3.x
Since 3.0 the default tracking method is the annotation (`argocd.argoproj.io/tracking-id`), not the `app.kubernetes.io/instance` label of 2.x,
and the id includes the Application name, which is what makes the owner readable here. With label tracking, two Applications could overwrite each
other's label, which looked like an endless flip. On 3.6.1 the second Application just stays OutOfSync with the warning; we saw no flip-flopping.
