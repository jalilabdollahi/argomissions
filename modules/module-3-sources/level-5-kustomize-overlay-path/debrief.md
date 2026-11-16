# The Base Is Not An Environment

## What broke
The Application's `path` was `kustomize/base`. A Kustomize **base** is a reusable set of manifests; the things that make
an environment (replica counts, settings, patches) live in **overlays** that list the base as a resource. Argo CD built
the directory it was given, got a valid, healthy, one-replica deployment and had no reason to complain.

## Why Argo CD behaves this way
For a source path that contains a `kustomization.yaml`, the repo-server runs `kustomize build <path>` and applies the
result. It has no concept of "environment": an environment is simply a path (or a branch, or a values file) that you pick.
Whatever that directory renders is the desired state, so pointing at the base is a perfectly legal configuration. You can
reproduce every render with `kubectl kustomize <dir>`, which uses the same engine.

## The fix
Set the Application path to `kustomize/overlays/prod` and sync. The diff shows the replica count and text patch, and
the new pods roll out. Changing the base instead would also make production look right, but staging builds on the same
base and would silently inherit production settings.

## In real life
One Application per environment, each with its own overlay path, is the classic Kustomize layout. The mistake shows up
when a team copies an Application from another repo and adjusts the repo URL but not the path, or when a refactor moves
overlays. Production then runs with development defaults without a single error. A quick `argocd app get` (look at *Path*)
and `kubectl kustomize` on the same directory settle it.

## Commands worth remembering
```bash
kubectl kustomize kustomize/overlays/prod | less
argocd app get inventory-sync            # shows Path
argocd app set inventory-sync --path kustomize/overlays/prod
argocd app diff inventory-sync
```

## Common mistakes
- Scaling the Deployment with `kubectl`: the Application stays OutOfSync and the text is still wrong.
- Moving production settings into the base to "fix" production: every other environment changes with it.
- Assuming a Synced Application is the right environment; Argo CD only checks that the cluster matches the chosen path.
