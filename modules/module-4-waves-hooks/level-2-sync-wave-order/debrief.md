# Config Before Code

## What broke
The Deployment reads its carrier from the ConfigMap `shipping-ui-config`. Someone copied the `sync-wave: "1"`
annotation of the Service onto the ConfigMap ("expose things after the workload is healthy"). Argo CD ran
wave 0 (the Deployment), waited for it to become Healthy, and it never did: the pod sat in
`CreateContainerConfigError` because the ConfigMap it needed was waiting in wave 1. A deadlock: the sync stays
`Running` until somebody terminates it (or, with a short `progressDeadlineSeconds`, fails once the deadline passes).

## Why Argo CD behaves this way
Sync waves are a barrier. Resources are applied wave by wave in ascending order (default 0, negative values
allowed). After each wave Argo CD waits until every resource in it is **Healthy** before it starts the next one,
and it adds a short pause between waves. Inside a wave it applies kinds in a built-in order (Namespace,
ServiceAccount, Secret, ConfigMap, ... Service ... Deployment ... Job), which is why a ConfigMap and a
Deployment without any annotation already work together. The moment you give one of them a wave, you
override that order, and "the later wave waits for the earlier one" becomes your responsibility.

## The fix
Give the ConfigMap a wave lower than (or equal to) the Deployment's, in Git. `-1` states the intent: "config
first". A new sync then creates the ConfigMap, waits for it, rolls out the Deployment, and finally exposes the
Service. The stuck operation has to be terminated first (`argocd app terminate-op`), because Argo CD runs one operation
at a time; the new sync starts from scratch.

## In real life
Waves are most useful for things that really depend on each other and whose dependency Argo CD cannot see:
namespaces and quotas before workloads, config and secrets before the app, the app before its Ingress or
monitoring objects. The usual accidents are copy/pasted annotations, a wave on the dependency that is later than
the consumer, and a wave 0 resource with a bad probe that blocks everything behind it.

## Commands worth remembering
```bash
argocd app get NAME                       # operation message: "waiting for healthy state of ..."
argocd app sync NAME --refresh
argocd app terminate-op NAME              # stop a sync that is waiting on a wave
kubectl -n NS describe pod                # CreateContainerConfigError, missing ConfigMap/Secret
```

## Common mistakes
- Creating the ConfigMap with `kubectl apply` so the pod starts: the pod recovers, but Git still says "wave 1" and
  the next fresh install deadlocks again.
- Re-running the sync: Argo CD refuses a second operation while the first is waiting, and the ConfigMap is still
  held back.
- Putting a high wave on everything "to be safe": waves only order resources relative to each other.
