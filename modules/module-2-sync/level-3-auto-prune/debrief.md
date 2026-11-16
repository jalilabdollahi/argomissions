# Automated, But Not Tidy

## What broke
The `gallery-classic` manifest was deleted from Git, but the Service kept running and the Application stayed
`OutOfSync` for ever. Automated sync was on, so the team expected Git changes of every kind to be applied.

## Why Argo CD behaves this way
Argo CD treats deletion as the dangerous half of a sync. A live object tracked by the Application but absent
from Git is "orphaned": it is reported (`OutOfSync`, *requires pruning*) and never removed unless pruning is
explicitly allowed. For a manual sync that means the **Prune** checkbox / `--prune`; for an automated policy it
is `syncPolicy.automated.prune: true`. Without it Argo CD does not even attempt an automated sync when the only
difference is something to delete, so the Application can stay `OutOfSync` indefinitely with no failed operation
to look at. Pruning only touches objects Argo CD itself tracks (its `tracking-id` annotation), never unrelated
things in the namespace.

## The fix
`argocd app set gallery-web --auto-prune`: the policy now deletes whatever leaves Git, now and for every future
commit. `kubectl delete svc gallery-classic` or a one-off `argocd app sync --prune` clears today's orphan and
leaves the policy exactly as it was.

## In real life
Forgotten orphans are a classic: an old Service or Ingress keeps routing traffic, an old CronJob keeps running,
a retired Secret stays readable. Prune makes Git deletions real, which is also why teams turn it on late and
protect data-holding objects (see the next missions: `Prune=false`, `allowEmpty`).

## Commands worth remembering
```bash
argocd app get NAME                      # resources that "require pruning" show OutOfSync
argocd app diff NAME
argocd app set NAME --auto-prune         # --auto-prune=false to switch it off
argocd app sync NAME --prune             # one-off prune
```

## Common mistakes
- Deleting the object with `kubectl`: the policy is unchanged and the next retired manifest has the same fate.
- Using a one-off `sync --prune` and thinking the Application is now "pruning".
- Enabling prune on an app whose repo might be briefly wrong or empty without understanding the blast radius.
