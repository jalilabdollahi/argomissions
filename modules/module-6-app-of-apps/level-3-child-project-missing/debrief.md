# Debrief — Orphaned Children

## What broke
The two child Applications reference the AppProject `tracing-team`. On the old cluster somebody had created that
project by hand; the rebuilt cluster only has `default`, and the root's Git folder contained the Applications but not
the project. Each child got `InvalidSpecError: Application referencing project tracing-team which does not exist` and
never synced. The root, which only had to create two Application objects, was green the whole time.

## Why Argo CD behaves this way
An Application is validated against its project before anything else: no project, no source, no destination, no sync.
The error is a condition on the child, not a failure of the parent, so the parent's health says nothing about it.
Projects are ordinary Kubernetes objects (kind `AppProject` in `argocd`), so an app-of-apps root can create them like
any other manifest. In one sync the root applies everything in wave order; kinds without a defined order, like
`AppProject` and `Application`, fall in the same wave unless you separate them with `argocd.argoproj.io/sync-wave`.
A project in a lower wave exists before the Applications that need it are created.

## The fix
Put an AppProject manifest into the folder the root deploys, with the limits the team agreed on (the one repository,
two namespaces, and Namespace in the cluster resource whitelist because the children use `CreateNamespace`), and give it
an earlier wave than its children. Now the whole platform comes up from nothing in one sync.

## In real life
Disaster recovery and "new cluster" bootstraps find all the objects that were once created by hand: the project, the
repository credentials, the namespace. If a root depends on something, that something belongs in Git next to it, in an
earlier wave. Switching the children to `default` makes the error disappear and removes the team's boundaries.

## Commands worth remembering
- `argocd app get CHILD` / `kubectl -n argocd get application CHILD -o jsonpath='{.status.conditions}'` — the condition.
- `kubectl -n argocd get appprojects` — which projects exist.
- `argocd proj get NAME` — what a project allows.

## Common mistakes
- `kubectl apply` of the project: the children heal, the next cluster rebuild fails the same way.
- Moving the children to the `default` project to make the error vanish.
- Putting the project in the folder but leaving it in the same wave as the children, so a fresh bootstrap is a race.
