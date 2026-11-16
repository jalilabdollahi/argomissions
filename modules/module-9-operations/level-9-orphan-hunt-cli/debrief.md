# Forensics With The CLI

## What broke
A tidy-up commit ("Align environment values with the staging config") changed `BASE_CURRENCY` from `EUR` to
`USD` in the production manifest. Argo CD did its job: Git changed, the cluster followed, the Application
stayed Synced and Healthy. Two later releases (v1.2 with two replicas, and a cache TTL change) were stacked on
top before anyone noticed the quotes were wrong.

## Why Argo CD behaves this way
Argo CD only knows whether the cluster matches Git, not whether Git is right. What it does give you is a
ledger: `status.history` records every successful sync with the exact revision, deploy time and source, and
the repo-server can render the manifests for *any* commit on demand, so you can compare versions without
cloning anything:

* `argocd app history APP` lists the deployed revisions (the last 10 by default, `revisionHistoryLimit`).
* `argocd app manifests APP --revision SHA` renders what that revision would deploy.
* `argocd app diff APP --revision SHA` compares that revision with the live state.

Finding the first revision where a value turns bad is a bisect over this list; `git show` then tells you who
changed it and why.

## The fix
Fix forward: a new commit that restores the value (or `git revert` of the culprit, which touches different
lines than the later releases and so applies cleanly). Automated sync deploys it. Rolling the whole branch back
or force-pushing would also throw away the good releases made after the bad commit, and would erase the very
history that explains the incident.

## In real life
Most "Argo CD deployed something wrong" incidents are really "someone merged something wrong". A history that
is append-only is what makes the post-mortem possible, and also what lets other clusters, caches and
`argocd app history` entries keep pointing at commits that still exist. Combine this with small, single-purpose
commits and a review rule for production values.

## Commands worth remembering
```bash
argocd app history APP
argocd app manifests APP --revision SHA
argocd app diff APP --revision SHA
git log --oneline -- deploy/deployment.yaml
git show SHA
git revert SHA
```

## Common mistakes
- `kubectl set env` on the live Deployment: automated sync without self-heal leaves the app OutOfSync, and
  Git still holds the bad value.
- Rolling back to the last good revision (or `git reset --hard` plus a force push): the currency is right again
  but the v1.2 release and the TTL change are gone.
- Reverting more than the culprit, because the commit message was too vague to trust.
