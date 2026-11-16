# Promote Without Editing YAML

## What broke
Nothing was broken, something was stale: the production overlay mapped the alias `ticket-desk-web` to the old
`nginx:1.27-alpine` build, and staging had moved on to `traefik/whoami:v1.10`. The task was to promote the new build to
production in a way Argo CD can track.

## Why Argo CD behaves this way
For Kustomize sources, the Application can carry its own build parameters. `spec.source.kustomize.images` is applied by the
repo-server with `kustomize edit set image` **after** it reads the overlay, so an entry for the same image name replaces the
overlay's mapping; `namePrefix`, `commonLabels`, `namespace` and others work the same way. It is part of the Application's
desired state: the Application becomes OutOfSync, a sync rolls the Deployment, and the next reconcile keeps it there.

The live Deployment is different: `kubectl set image` changes the object, but the desired state (Git plus the Application)
still says `nginx`. Argo CD reports OutOfSync, and a sync or self-heal puts the old image back.

## The fix
`argocd app set ticket-desk --kustomize-image ticket-desk-web=traefik/whoami:v1.10`, then sync. Writing the same mapping
into the prod overlay and pushing is the other correct route; choose by who owns the change: image promotion by a pipeline is
usually an Application override or an automated commit by an image updater, version-controlled intent is an overlay edit.

## In real life
CI pipelines use `argocd app set --kustomize-image` (or Argo CD Image Updater) to promote builds without touching
the app repo. The cost: the override lives only in the Application, so it must itself be in Git (App of Apps, module 6) or
it is lost with the cluster. Make a rule: either the overlay or the Application decides the tag, never both.

## Commands worth remembering
```bash
kubectl kustomize overlays/prod | grep image:
argocd app set NAME --kustomize-image ALIAS=IMAGE:TAG
argocd app diff NAME
argocd app unset NAME --kustomize-image ALIAS     # drop the override
```

## Common mistakes
- `kubectl set image`: the pods may start, but the Application is OutOfSync and the change disappears on the next sync.
- Using the new image name without the alias (`traefik/whoami:v1.10` alone): it matches nothing, the old image stays.
- Setting the tag both in the overlay and on the Application and forgetting which one wins (the Application does).
