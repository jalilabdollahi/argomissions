# Deploy On Merge

## What broke
Nothing was broken, the Application was just *manual*. Argo CD compared Git with the cluster every few minutes
and correctly reported `OutOfSync`, but a manual Application only reports. Three releases piled up in `main`
while the gateway kept running v1.0.

## Why Argo CD behaves this way
Every Application has a **sync policy**. Without `spec.syncPolicy.automated` the application controller never
starts a sync operation on its own: a human (or a pipeline calling `argocd app sync`) has to. That is a feature:
many teams want a person to approve production changes. When `automated` is present the controller starts a sync
as soon as it sees that the target revision differs from what was last synced, and it does so for the *latest*
commit, not commit by commit (v1.1 and v1.2 are skipped, the cluster goes straight to v1.3).

Automated sync also has guard rails: it will not retry a sync of the *same* revision that already failed with the
same parameters, and by default it neither prunes nor heals drift (those are the next missions).

## The fix
Set the policy on the Application: `argocd app set metrics-gw --sync-policy automated`, the UI toggle, or
`syncPolicy.automated: {}` in the YAML. A single `argocd app sync` would have deployed v1.3 once and changed
nothing about the next merge.

## In real life
"Deploy on merge" is the default for dev and staging; production often stays manual or uses a promotion step.
Because the Application is itself usually stored in Git, turning auto-sync on is a reviewed change like any other.
Remember the other side: with automated sync, a bad commit on `main` reaches the cluster within seconds.

## Commands worth remembering
```bash
argocd app get NAME                              # Sync Policy, Sync Status, revision
argocd app set NAME --sync-policy automated      # enable
argocd app set NAME --sync-policy none           # back to manual
argocd app history NAME                          # what was deployed, when
```

## Common mistakes
- Running `argocd app sync` once and calling it done: the policy is still manual.
- Expecting every intermediate commit to be deployed: automated sync deploys the newest revision.
- Enabling auto-sync on a production app without a review step on `main`.
