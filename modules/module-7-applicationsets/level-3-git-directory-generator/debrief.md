# Too Many Apps

## What broke
The git directory generator pattern `apps/*` matches every folder under `apps/`. `apps/shared` holds CI
defaults, not a service, but the generator cannot tell, so the ApplicationSet created
`studio-shared`, which deployed a ConfigMap nobody wanted in the cluster.

## Why Argo CD behaves this way
The directory generator only looks at paths in Git: each matching directory becomes one parameter set
(`path.path`, `path.basename`, ...), and each parameter set becomes one Application. There is no notion of
"looks like a service". To narrow the result you list more entries under `directories`: an entry with
`exclude: true` removes matching directories from the ones the earlier include entries selected. Because the
Application is owned by the ApplicationSet, deleting it by hand is pointless: the controller reconciles the
list and creates it again. When the generator stops producing it, the controller deletes it (the default
`applicationsSync` policy allows deletion).

## The fix
Add `- path: apps/shared` with `exclude: true` to the generator. Alternatively keep Git tidy and move the
non-service folder out of `apps/`.

## In real life
Monorepos grow `_common`, `base`, `docs` and `templates` folders next to the services, and a glob generator
happily turns them into broken Applications (or worse, into Applications that deploy something nobody
expected). Excludes, a stricter path pattern or a dedicated `services/` directory keep the set honest. Review
the generated Application list whenever a folder is added.

## Commands worth remembering
```bash
argocd appset get NAME
kubectl -n argocd get applicationset NAME -o yaml
kubectl -n argocd annotate applicationset NAME argocd.argoproj.io/application-set-refresh=true
```

## Common mistakes
- Deleting the unwanted Application: it comes back on the next reconcile.
- Writing the exclude path without the `apps/` prefix: it matches nothing, because paths are relative to the repo root.
- Excluding a folder in the template (conditionals) instead of in the generator, leaving a half-rendered Application.
