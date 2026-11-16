# The Missing Region

## What broke
Nothing was broken. An ApplicationSet creates exactly the Applications its generators describe, and the `list`
generator of `geo-edge` only had two elements. Europe had no Application because nobody had asked for one.

## Why Argo CD behaves this way
The ApplicationSet controller runs a loop: every generator produces *parameter sets* (here one per list
element, `region: us-east`, ...), each parameter set is substituted into the `template`, and the result is one
Application. The controller then makes the real Application list match: it creates missing Applications,
updates changed ones and (with the default policy) deletes the ones that are no longer generated. Generated
Applications carry an `ownerReference` to the ApplicationSet; that link is what lets the set manage them.
The set was `Healthy` because "all applications have been generated successfully" is true for two elements.

## The fix
Add the element `region: eu-west` to the list. The controller reacts at once, creates `geo-edge-eu-west`, and
the template's `automated` sync policy plus `CreateNamespace=true` brings it up in `geo-eu-west`.

## In real life
An ApplicationSet is how one team stamps out the same service for dozens of regions, tenants or clusters. The
list is usually reviewed in a pull request, so "add a region" is a one-line change. The most common shortcut
is to copy an existing Application YAML: it works, but it is an orphan: the set does not own it, the next
template change does not reach it, and deleting the region from the list will not remove it.

## Commands worth remembering
```bash
kubectl -n argocd get applicationset NAME -o yaml      # generators, template, status.conditions
argocd appset list                                      # ApplicationSets
argocd appset get NAME                                  # generated Applications and conditions
kubectl -n argocd get applications -o custom-columns=NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name
```

## Common mistakes
- Creating the missing Application by hand instead of adding an element: it has no owner, and the set ignores it.
- Editing a generated Application: the set overwrites it on the next reconcile, because the template is the truth.
- Adding an element with a slightly different value (`eu-west-1`): the template builds names and namespaces from it.
