# Overrides Ignored

## What broke
The ApplicationSet merged two lists: a base list with one element per environment and an override list with the
exceptions. The override element described the production environment with the field `environment`, while the base
list and `mergeKeys` used `env`. The override never matched a base element, so Argo CD generated prod from the
defaults alone: one replica and the plain banner. There was no error, no warning and every Application was green.

## Why Argo CD behaves this way
The merge generator runs its child generators and then combines their parameter sets. The **first** generator is
the base; for every later generator, each parameter set is merged into the base set whose `mergeKeys` fields are
equal. Sets that match nothing are ignored: they do not create new Applications and they are not reported, because
"nothing to override" is a legitimate result (for example when an environment is removed from the base list). The
same rule applies to values: `env: prod` never matches `env: production`, and the comparison is on strings.

Keys that are present on the base side only, or the other way round, therefore degrade silently. The only visible
symptom is that the generated Application has the base parameters. Check what was really generated with
`argocd app get <app>` (parameters) or `kubectl get application <app> -o yaml`, not only with the health colours.

## The fix
Give the override element the same key field and value as its base element (`env: prod`) and apply the
ApplicationSet again. The controller regenerates `parcel-api-prod` with `replicas=3` and the new banner, and its
automated sync rolls the Deployment. Changing the generated Application by hand does not work: the ApplicationSet
controller owns the spec of its children and rewrites it.

## In real life
Merge generators are popular for "defaults plus exceptions" fleets (clusters by region, tenants by tier). The classic
bugs are a typo in a key name, `eu-west` vs `eu_west`, or a cluster generator whose key is `name` merged with a list
that says `cluster`. Because mismatches are silent, teams add a check to CI that renders the ApplicationSet
(`argocd appset generate`) and compares the number and parameters of the generated Applications.

## Commands worth remembering
```bash
argocd appset get parcel-api                  # generated apps and conditions
argocd appset generate parcel-api-appset.yaml # dry run: what would be generated
argocd app get parcel-api-prod                # helm parameters of the child
kubectl -n argocd get applicationset parcel-api -o yaml
```

## Common mistakes
- Editing the generated Application (`argocd app set`, a patch): the ApplicationSet reverts it on its next reconcile.
- Scaling the Deployment with `kubectl scale`: Git still says one replica and the app is OutOfSync.
- Adding a second `prod` element to the base list instead of fixing the key: the merge generator is then pointless
  and the duplicate collides with the existing Application name.
