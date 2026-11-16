# The Moved Manifests

## What broke
A commit reorganised the repo and moved the manifests from `k8s/` to `deploy/catalog/`. The Application
`catalog` still said `path: k8s`. At the target revision there is no such folder, so Argo CD could not
produce any manifests and reported `k8s: app path does not exist`.

## Why Argo CD behaves this way
An Application's source is three things: a repo, a revision and a **path** inside that repo. On every
comparison the repo-server checks out the revision and renders the manifests from exactly that folder.
Nothing follows file moves: Argo CD has no idea that the files in `deploy/catalog` used to be in `k8s`.
The Application resource lives in the cluster, not in the repo, so a commit that moves files cannot update it.

The Application had no usable target state, so its sync status is `Unknown` rather than `OutOfSync`, and the
error is a `ComparisonError` condition, not a failed sync operation.

## The fix
Change `spec.source.path` to `deploy/catalog` and sync. Git was correct all along: the layout the team agreed
on stays, and the consumer (the Application) follows.

## In real life
Repo restructures are a top cause of "suddenly Unknown" Applications. The fix is to change the Application in
the same breath as the move; teams that keep Application manifests in Git (app-of-apps) can put both changes in
one pull request, which turns the failure into a reviewed change. Directory renames in Helm charts and
Kustomize bases cause the same error for `valueFiles` and `resources:` entries.

## Commands worth remembering
```bash
argocd app get NAME                     # conditions show the error
argocd app set NAME --path DIR          # change the source folder
git log --stat --oneline                # what moved, and when
git ls-tree -r --name-only HEAD         # the layout at a revision
```

## Common mistakes
- Copying or reverting the files back to `k8s/` so the old path works: you undo a deliberate change and the
  next person to follow the new layout breaks it again.
- Fixing the path but not syncing: a manual-sync Application stays OutOfSync and nothing is deployed.
- Looking at a stale local clone: run `git pull` first, the layout at `main` is what counts.
