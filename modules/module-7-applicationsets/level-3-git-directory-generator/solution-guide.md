# Walkthrough — Too Many Apps

1. **Find the odd one out.**
   ```bash
   argocd app list                       # studio-render, studio-thumbnails, studio-captions, studio-shared
   argocd app get studio-shared          # Synced: it deploys the ConfigMap studio-defaults from apps/shared
   ls studio-platform/apps               # captions  render  shared  thumbnails
   ```
2. **Why it exists.** `kubectl -n argocd get applicationset studio -o yaml`: the generator has one directory
   pattern, `apps/*`, and `apps/shared` matches it like any service folder.
3. **Exclude it.** In `studio-appset.yaml`:
   ```yaml
   generators:
   - git:
       repoURL: http://gitea.gitea.svc.cluster.local:3000/platform/studio-platform.git
       revision: main
       directories:
       - path: apps/*
       - path: apps/shared
         exclude: true
   ```
4. **Apply.**
   ```bash
   kubectl apply -f studio-appset.yaml
   argocd app list                       # studio-shared disappears
   ```
   The controller deletes Applications the set no longer generates.
5. **Verify** the three services still answer `studio <service> v1`, then run `check` in the game.

Deleting `studio-shared` by hand only works until the next reconcile: the set creates it again. Moving
`apps/shared` out of `apps/` in Git is also a valid fix.
