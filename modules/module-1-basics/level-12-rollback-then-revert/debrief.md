# Undo Without Rewriting History

## What broke
The commit "tune worker flags" added `-workers=8 -log-level=debug` to the container arguments. The worker does
not know those flags, exits immediately and crash-loops. Because the Deployment uses the `Recreate` strategy
there was no old pod left to serve, so the Application was `Synced` (Git and cluster agree) and `Degraded`.

## Why Argo CD behaves this way
Argo CD deploys whatever commit the Application points at. It has two different "go back" tools:

* **`argocd app rollback`** re-applies the manifests of an earlier entry of the Application history. It is
  fast and needs no Git access, but it does not touch Git: the Application's target is still `main`, whose head
  still holds the bad change, so the Application is `OutOfSync` and a rollback is refused or undone as soon as
  automated sync is on. It is an emergency brake, not a fix.
* **`git revert`** creates a new commit that undoes an earlier one. History only moves forward, every clone
  stays valid, and the Application can sync normally to the new head.

A force push (`git reset --hard` + `git push --force`) would also make the cluster healthy, but it rewrites
history others already pulled and erases the evidence of what happened.

## The fix
`git revert HEAD`, push, sync. Optionally roll back first to restore service while the fix is prepared. Verify the
Application is at the head of `main`, Healthy, and that the log still contains both the bad commit and its revert.

## In real life
In a GitOps team the audit trail *is* the Git history: who changed what, when, and who undid it. Protected
branches forbid force pushes for exactly this reason. Rollback is what you reach for at 3 a.m.; the revert is
what you leave behind so the next sync does not redeploy the bug.

## Commands worth remembering
```bash
argocd app history reports
argocd app rollback reports ID
git revert --no-edit HEAD         # or: git revert <sha>
git log --oneline --graph
kubectl -n reports logs deploy/report-worker
```

## Common mistakes
- Stopping after `argocd app rollback`: the cluster is fine, Git is still wrong, the Application is OutOfSync.
- `git reset --hard HEAD~1 && git push --force`: it works for you and breaks everybody else's clone.
- Reverting but forgetting to sync: the manual Application stays on the bad revision.

## Argo CD 2.x vs 3.x
Rollback semantics are the same in 2.x and 3.x: it is only available when automated sync is off, and it
deploys the stored revision without changing the Application's target.
