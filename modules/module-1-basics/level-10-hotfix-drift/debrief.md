# The Hotfix That Must Survive

## What broke
Nothing was down: someone changed the live Deployment by hand (`kubectl scale ... --replicas=3`) and Git was
never updated. Live state (3 replicas) and desired state (1 replica in Git) drifted apart, and Argo CD reported
the Application as `OutOfSync`.

## Why Argo CD behaves this way
Argo CD continuously compares the manifests rendered from Git with the live objects. Any difference in a field
that Git declares is drift, and the Application becomes `OutOfSync`. Git always wins: a sync (manual, or
automatic with `selfHeal`) overwrites the live value. There is no "keep the cluster's version" button: the only
way to keep a live change is to make it the desired state, which means committing it.

That is why a plain sync here is dangerous. It is the *right* tool when the drift is unwanted and the *wrong*
one when the live change is the improvement. `argocd app diff` tells you which case you are in.

## The fix
Put the value that is correct in Git: `replicas: 3`, commit, push, sync. The sync finds the live object already
equal to the new desired state and only moves the Application's revision forward. Capacity is untouched, and
the next engineer who reads Git sees the truth.

## In real life
Incident hotfixes with `kubectl` are normal; the failure is leaving them there. Without a follow-up commit the
next deploy silently reverts the fix, usually at the worst time. If replicas are meant to be managed by an
autoscaler, the right answer is different: drop `replicas` from the manifest and use an HPA (or
`ignoreDifferences`), see the sync-policy missions.

## Commands worth remembering
```bash
argocd app diff checkout                 # live vs Git, field by field
argocd app get checkout                  # which resources are OutOfSync
kubectl -n checkout get deploy checkout -o jsonpath='{.spec.replicas}'
argocd app sync checkout
```

## Common mistakes
- Pressing Sync "to clean up": Git still says 1, so production is scaled down again.
- Leaving the Application OutOfSync "until later": the drift hides the next real change and the next sync
  reverts the hotfix.
- Fixing Git but never syncing: the Application stays on an old revision and is not at the head of `main`.

## Argo CD 2.x vs 3.x
Drift detection is the same. In 3.x resource tracking uses annotations by default, which changes nothing for
this scenario; `kubectl scale` only touches `spec.replicas`, which Git owns.
