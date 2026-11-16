# Master Of Nothing

## What broke
The Application `invoices` was created with `targetRevision: master`. Later the team renamed the branch to
`main`, which is the only branch left. Argo CD asked Git to resolve `master` to a commit and got "revision not
found", so it could not render anything: the Application was `Unknown` and nothing was deployed.

## Why Argo CD behaves this way
`spec.source.targetRevision` is what Argo CD tracks: a branch name, a tag, a commit SHA, a semver range (for
Helm charts) or `HEAD`. On every comparison the repo-server resolves it to a commit SHA with `git ls-remote`
and renders that commit; `status.sync.revision` is the resolved SHA. A name that does not exist cannot be
resolved, so the failure happens before any manifest is rendered. The Application resource lives in the
cluster and is independent of the repo, so renaming a branch never updates it.

`HEAD` means "whatever the repo's default branch is". It survives a rename, but also silently follows a
default-branch change, so many teams prefer an explicit name.

## The fix
Set `targetRevision` to `main` (or `HEAD`) and sync. Re-creating a `master` branch only hides the problem: two
branches now diverge, and the next person who pushes to the wrong one deploys nothing, or the wrong thing.

## In real life
Branch renames (master to main, develop to trunk, release branches per version) are a regular cause of
"Unknown" Applications, usually discovered by the first person who looks at the Argo CD UI. After a rename,
search all Application and ApplicationSet manifests for the old name, `argocd app list -o json | jq` makes that
quick. A typo in a tag or branch name fails the same way.

## Commands worth remembering
```bash
argocd app get NAME
argocd app set NAME --revision BRANCH
git ls-remote --heads origin       # branches the server really has
git ls-remote --tags origin
argocd app list -o json | jq -r '.[] | [.metadata.name, .spec.source.targetRevision] | @tsv'
```

## Common mistakes
- Pushing a `master` branch so the old name resolves again: it works today, and leaves two branches to confuse
  everyone after you.
- Fixing the revision but forgetting to sync: the Application is OutOfSync until someone syncs it.
- Assuming Argo CD "tracks the default branch": it tracks exactly the name in `targetRevision`.
