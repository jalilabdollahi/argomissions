# Sync Failed: Unknown Kind

## What broke
One of the three manifests in `deploy/` was a `PodDisruptionBudget` written for `policy/v1beta1`. That version
was removed in Kubernetes 1.25, and the cluster only serves `policy/v1`. The sync failed with
`failed to discover server resources for group version policy/v1beta1`, and because the failure happened during
validation, not a single object (not even the Deployment and Service) was created.

## Why Argo CD behaves this way
Before a sync applies anything, Argo CD turns the rendered manifests into sync tasks and validates each one
against the API discovery of the destination cluster: does that group/version/kind exist, is the namespace
valid, is the resource allowed by the project? If any task is invalid the whole operation stops with
`one or more synchronization tasks are not valid`. This is deliberate: a half-applied release is worse than none.

The comparison can still run, which is why the Application showed `OutOfSync` (everything missing) rather than
`Unknown`: Argo CD only needs the *Git* side to be parseable for that. The error appears the moment it has to
talk to the API server about the kind.

## The fix
Update the manifest to the API version the cluster serves (`policy/v1`) in Git, push, and sync. For a PDB the
`spec` did not change between versions, so one line is enough. Deleting the file would also "fix" the sync, but
it silently removes the protection the service had during node drains.

## In real life
This is the classic failure after a cluster upgrade: manifests that were valid for years stop applying because
the API was removed (`extensions/v1beta1` Ingress, `batch/v1beta1` CronJob, `policy/v1beta1` PDB and
PodSecurityPolicy, ...). Teams find out in the middle of a release, or worse, in a staging cluster that runs a
newer Kubernetes than production. Tools such as `kubectl convert`, `pluto` or `kubent` find deprecated versions
before the upgrade.

## Commands worth remembering
```bash
argocd app get billing                 # last operation message and per-resource errors
argocd app manifests billing           # what Argo CD would apply
kubectl api-versions | grep policy     # which versions the cluster serves
kubectl api-resources | grep -i disruption
kubectl explain pdb                    # the preferred version and its fields
```

## Common mistakes
- Deleting the offending file from Git: the sync goes green but the PodDisruptionBudget (a requirement) is gone.
- Fixing the manifest and forgetting to sync: the Application has a manual policy, so nothing happens by itself.
- Blaming Argo CD and re-running the sync: the error comes from the API server's discovery and will not change
  until the manifest does.

## Argo CD 2.x vs 3.x
The behaviour is the same in 2.x and 3.x: the removed API is a property of the cluster, not of Argo CD.
Resource tracking in 3.x is annotation based, so the PDB (like every managed object) carries
`argocd.argoproj.io/tracking-id` once it is created.
