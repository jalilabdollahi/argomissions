# The Drift That Stays

## What broke
Live objects had drifted from Git (replicas 5 instead of 2, discount cap 40 instead of 5). The Application had
automated sync, so the team assumed Git always wins. It did not: Argo CD reported the drift and left it.

## Why Argo CD behaves this way
`syncPolicy.automated` has two independent triggers. The first fires when the *target revision* changes (a new
commit): Argo CD syncs. The second, **selfHeal**, fires when the *live state* changes while Git did not: Argo CD
syncs again to undo it. Without `selfHeal` a manual `kubectl edit` produces `OutOfSync` and nothing else, on
purpose: an engineer debugging an incident may need a temporary live change, and Argo CD will not fight them
unless you ask it to. With `selfHeal` it does, with a short backoff (5 s by default) between healing attempts,
and the application controller watches the live objects, so the revert comes within seconds.

## The fix
`argocd app set pricing-api --self-heal` (or `automated.selfHeal: true`). A one-off `argocd app sync` would
revert today's edits only; the next `kubectl edit` would stay forever.

## In real life
Self-heal is what makes "Git is the only way to change production" enforceable, and it makes configuration
drift visible immediately instead of at the next deployment. The cost: emergency hotfixes by hand are reverted.
Teams then either commit the fix to Git or temporarily pause auto-sync (`argocd app set X --sync-policy none`).

## Commands worth remembering
```bash
argocd app diff NAME                       # live vs Git
argocd app set NAME --self-heal            # enable (--self-heal=false to disable)
argocd app get NAME -o yaml | grep -A4 syncPolicy
```

## Common mistakes
- Syncing by hand and believing the problem is solved: the next manual edit drifts again.
- "Fixing" the OutOfSync by copying the live values into Git: that makes production take the 40% discount.
- Expecting self-heal to also delete extra live resources: that needs `prune` (next mission).
