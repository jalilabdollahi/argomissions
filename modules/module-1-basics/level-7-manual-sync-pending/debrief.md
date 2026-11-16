# The Commit Nobody Shipped

## What broke
Nothing failed. The commit "release v2.3" was merged and Argo CD saw it right away: the Application turned
`OutOfSync`. But the Application uses a **manual** sync policy, so Argo CD only reported the difference. The
release manager assumed that merging means deploying, so for hours the cluster kept running v2.2.

## Why Argo CD behaves this way
Argo CD separates *detecting* a difference from *acting* on it. The controller keeps comparing Git with the
cluster and sets the sync status (`Synced` / `OutOfSync`). Applying the change is a **sync operation**, started
by a person, the CLI, the API, or by `spec.syncPolicy.automated`. Without it, an `OutOfSync` Application is a
pending change waiting for a decision, which is what many teams want for production: a human reviews
`argocd app diff` and presses Sync at the agreed time. The Application's history lists each sync with the commit
it deployed, so "what is live" is always answerable.

## The fix
Review the diff and sync. No Git change is needed: the manifests were right, they just were not applied.

## In real life
"It is merged, so it is live" is a classic miscommunication in teams that adopt GitOps with manual sync.
Alerts on Applications that stay OutOfSync for hours, a dashboard column for sync status, or a release checklist
that includes the sync step all help. Teams that never want the gap enable automated sync (covered in the next
module), accepting that every merge deploys. Note that patching the live Deployment to the new value looks like
shipping, but it bypasses Argo CD: the history does not record it and it only works by coincidence.

## Commands worth remembering
```bash
argocd app diff NAME            # what a sync would change (exit code 1 = there is a diff)
argocd app history NAME         # which commits were deployed, and when
argocd app sync NAME
argocd app list                 # sync and health at a glance
```

## Common mistakes
- Hand-editing the live Deployment (`kubectl set`, `kubectl patch`) to "get it out": Argo CD did not deploy the
  release, and the next sync or edit surprises someone.
- Syncing without reading the diff: with manual sync the diff is the review step.
- Assuming `Synced` in the list means the latest commit is live: check the revision and `argocd app history`.
