# Every Service In Every Env

## What broke
The matrix generator produced four parameter sets (two services × two environments), but the template named
every Application after the service only. Two Applications called `invoicer` and two called `mailer` cannot
exist in one namespace, so the ApplicationSet failed with "contains applications with duplicate name" and
created none of them.

## Why Argo CD behaves this way
A matrix generator takes the Cartesian product of its child generators: each parameter set of the first is merged
with each parameter set of the second (here `path.*` from Git plus `env` from the list). The template then
renders once per pair. Anything in the template that must be unique (the Application name, and usually the
destination namespace) therefore has to be built from parameters of **both** generators. The controller validates
the rendered list before creating anything, which is why one collision stops the whole set rather than just the
duplicates. The namespace was already `{{.path.basename}}-{{.env}}` and the Helm parameter `env`
differentiated the content, so only the name was missing the environment.

## The fix
Name the Application `{{.path.basename}}-{{.env}}`. Four distinct Applications appear, each in its own namespace.

## In real life
Matrix generators are the standard way to roll "every service to every environment/cluster" without writing
N×M Applications. The recurring bug is a template field that only uses one axis: names, namespaces, Helm release
names or `destination` values that collide silently or loudly. When adding an axis (a region, a cluster), grep
the template for every field that must now include it.

## Commands worth remembering
```bash
argocd appset get NAME
kubectl -n argocd get applicationset NAME -o jsonpath='{.status.conditions}' | jq
kubectl -n argocd logs deploy/argocd-applicationset-controller | grep NAME
```

## Common mistakes
- Naming the Application after the environment only: the two services collide instead.
- Dropping an environment from the list to remove the collision: prod disappears.
- Creating the four Applications by hand: they would work, but the set would still be broken and own nothing.
