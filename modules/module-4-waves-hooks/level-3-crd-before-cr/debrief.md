# Unknown Kind On First Sync

## What broke
`sensor-hub` contains a custom resource, a `Probe`. The kind `Probe` is defined by a CustomResourceDefinition
that lives in the other Application, `sensor-crds`, and that one was never synced. Argo CD dry-runs every
resource of a sync before it applies the first one; the API server answered that it does not know the group
version `sensors.argomissions.io/v1`, so the whole sync was rejected: *failed to discover server resources for
group version sensors.argomissions.io/v1: the server could not find the requested resource*.

## Why Argo CD behaves this way
A sync validates the whole set of manifests up front (a server-side dry run) so that it does not apply half of
a release and then fail. A kind that does not exist yet cannot be validated. Within one Application Argo CD
knows about the relationship: if the CRD is part of the same sync it skips the dry run for its custom resources
and always applies the CRD before them, whatever their waves are (verified on this Argo CD). Across Applications
there is no such knowledge, because Applications are independent: each has its own sync, so order between them
is your job. The error is not a typo or a permission problem, it is "this kind does not exist yet".

## The fix
Sync the Application that owns the CRD first (and let it become Healthy), then sync the instances. The CRD
must be installed through Argo CD, otherwise nothing owns it. To make this automatic for fresh clusters,
order it in Git: sync waves on the child Applications of an app of apps (the parent waits for each wave's
Applications to be Healthy), or `SkipDryRunOnMissingResource=true` on the instance Application combined with an
automated sync and `retry`, so it is applied as soon as the kind exists.

## In real life
This is the standard bootstrap problem of every cluster that runs operators: cert-manager `Certificate`s,
Prometheus `ServiceMonitor`s, Istio, Crossplane, Argo Rollouts. The CRDs come from a chart or operator, the
instances from a team's repo. Bootstrapping a new cluster fails the first time unless the order is encoded
(waves in the root app, or retries), and then everyone remembers it once, as the incident they had.

## Commands worth remembering
```bash
kubectl get crd | grep NAME
kubectl api-resources --api-group=sensors.argomissions.io
argocd app sync NAME && argocd app wait NAME --health
argocd app get NAME              # the operation message names the missing group version
```

## Argo CD 2.x vs 3.x
In older documentation "CRD and CR in the same Application fail on the first sync". On Argo CD 3.x that is not
the case: when the CRD is in the same sync, the custom resources are applied after it and the dry run is skipped
for them. The failure remains for CRDs that arrive another way (another Application, a Helm chart, an operator).

## Common mistakes
- `kubectl apply`-ing the CRD to get past the error: it works, but the CRD is unowned and never updated by Git.
- Syncing the failing Application again and again: the kind does not exist until something installs the CRD.
- Hiding the problem with `SkipDryRunOnMissingResource` alone: it only skips the validation; applying still fails
  until the CRD exists, so the instance needs a retry or a wave in front of it.
