# Annotation Too Long

## What broke
The ConfigMap `host-inventory` carries about 375 KB of data. Argo CD's default apply works like `kubectl apply`
(client-side): to compute three-way patches later it stores the full manifest in the annotation
`kubectl.kubernetes.io/last-applied-configuration`. The API server caps the total size of an object's annotations at
262144 bytes, so the create failed with `metadata.annotations: Too long: may not be more than 262144 bytes`. The
Deployment and Service had no such problem, so the pod sat in `ContainerCreating` waiting for a volume.

## Why Argo CD behaves this way
Client-side apply needs a record of "what I last sent" so it can tell your deletions from other people's additions;
that record lives in an annotation on the object. Server-side apply moves the bookkeeping to the API server:
every field has an owner recorded in `metadata.managedFields`, conflicts are detected per field, and no
last-applied annotation is written. Argo CD offers it as the sync option `ServerSideApply=true`, either for the whole
Application (`spec.syncPolicy.syncOptions`) or per resource with the annotation
`argocd.argoproj.io/sync-options: ServerSideApply=true`. Because the option is part of the Application spec (or of the
manifest in Git), every later sync, including automated ones, keeps applying that way; a one-off `kubectl apply
--server-side` does not.

## The fix
`argocd app set host-registry --sync-option ServerSideApply=true`, then sync. The ConfigMap is created with all its data
and no `last-applied-configuration` annotation; the pod mounts it and the Application turns Healthy.

## In real life
This bites with big CRDs (Prometheus Operator, Istio, Gateway API: their CRDs are far above 256 KiB, which is why their
install docs say `--server-side`), big dashboards or rule files in ConfigMaps, and generated data like this export.
Mind the other limit: a ConfigMap cannot exceed about 1 MiB anyway, so beyond that the data belongs in a volume or an
object store. Server-side apply also changes conflict behaviour (a field owned by another manager is a conflict) and
pairs well with `ignoreDifferences` using `managedFieldsManagers`.

## Commands worth remembering
```bash
wc -c file.yaml                                        # how big is the manifest
argocd app set APP --sync-option ServerSideApply=true
argocd app sync APP --server-side                      # one-off
kubectl get cm NAME -o jsonpath='{.metadata.annotations}'
kubectl get cm NAME --show-managed-fields -o yaml | head -30
```

## Common mistakes
- Trimming the data until it fits: the failure disappears and the feature the data served goes with it.
- Applying the ConfigMap by hand with `kubectl apply --server-side`: it works once, but the Application still has no
  idea how it must apply it, and the next Argo CD sync fails again.
- Using `Replace=true` as a workaround: replace avoids the annotation but throws away fields other controllers set.

## Argo CD 2.x vs 3.x
Verified on 3.6.1: without any option a sync still uses client-side apply and fails with the message above, so
`ServerSideApply=true` is still opt-in (per Application or per resource). What Argo CD 3.x changed around it is
the default of annotation-based resource tracking, which does not interfere here.
