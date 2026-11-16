# The Hotfix That Flips Back

## What broke
Nothing was out of order on the child Application: `argocd app set` worked, the hotfix deployed. But
`courier-routing` is not a free-standing object, it is a resource of `courier-fleet`. The root's self-heal compared the
live child with `apps/api.yaml` in Git, found `targetRevision` different and rewrote it to `main`. Every attempt
through the CLI or the UI form was undone.

## Why Argo CD behaves this way
An Application is a Kubernetes resource like any other. When it is created by a root, the root owns it: the root's
desired state is the file in Git, and with `selfHeal: true` (and automated sync) any difference between the live
Application and that file is drift that gets corrected, usually within seconds. `argocd app set` is just a patch
on the child object, so it loses against its owner. The same holds for ApplicationSets, Helm releases managed by an
Application, and `argocd-cm` itself.

## The fix
Make the change where the owner reads it: set `targetRevision: hotfix-routing` in `apps/api.yaml` of the root's
repo, commit, push. The root syncs the child spec, the child tracks the branch. The history in Git also records who
shipped the hotfix and when it should go back to `main`.

## In real life
During an incident the fastest tool is the CLI, and in an app-of-apps cluster the CLI is the wrong tool: the fix
"works" for a few seconds and then vanishes, usually while the on-call is typing the status update. Keep a runbook
that says "child specs are changed in the fleet repo", and keep the pull request small and fast to merge for the
emergency case. If you must pin a hotfix, pin the commit SHA when you need a guarantee that the branch cannot move.

## Commands worth remembering
```bash
argocd app get <child>               # who tracks what
argocd app history <child>
argocd app diff <root>               # what the root would change in the child
argocd app get <root> --refresh
```

## Common mistakes
* Repeating `argocd app set` faster than the root reverts it, or disabling the root's self-heal "for the
  incident": the repo no longer describes production, and the root is OutOfSync.
* Editing the child in the UI instead of Git: same result, different button.
* Forgetting to move the child back to `main` after the hotfix is merged: the Application keeps tracking a
  branch that may be deleted.
