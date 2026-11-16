# Drift Storm

## What broke
Four kinds of drift at once. A child Application was edited live (pinned to an old commit) and the root, which is synced by
hand and has no self-heal, never noticed. A Deployment was debugged in place and nothing put it back. A controller from another
team rewrites an annotation that Git also declares. And two folders declare the same ConfigMap, which stayed
hidden only because the pinned child never deployed the release that contains the duplicate.

## Why Argo CD behaves this way
Automated sync without self-heal only reacts to *new revisions in Git*: a live change to a resource (or to a child
Application) that Git did not touch is shown as OutOfSync and then left alone. Self-heal is the setting that
re-applies Git when live state drifts. In an app-of-apps the children are ordinary Kubernetes objects of the root,
so the root's self-heal is what keeps `targetRevision`, sync policy and ignore rules of every child as Git says.
That is also why the rule that tells Argo CD to ignore somebody else's field must live in the child's manifest
in Git: a rule patched into the live Application is reverted by the root.
`ignoreDifferences` removes a field from the comparison, so another controller can own it without making the
Application permanently OutOfSync. A resource that two Applications declare is reported as `SharedResourceWarning`
and the second Application stays OutOfSync: Git must declare it once.

## The fix
`ignoreDifferences` for the epoch annotation and `selfHeal: true` in `apps/ingest.yaml`; `argocd app set
stormwatch-root --sync-policy automated --self-heal`; one `thresholds` ConfigMap with both keys; a root sync that restores the child
that was pinned by hand.

## In real life
"Just pin it for the night" is the most common way a GitOps platform quietly stops being GitOps. The pin hides
every later change to the child, including the duplicate resource that appears the moment the pin is lifted.
The countermeasure is boring: self-heal on the root, ignore rules in Git, one owner per resource, and an alert on
Applications that stay OutOfSync.

## Commands worth remembering
```bash
argocd app diff APP                      # what differs from Git (also for the root: its children)
argocd app set ROOT --self-heal
argocd app get APP -o yaml | yq .spec.ignoreDifferences
kubectl -n NS get RESOURCE -o yaml --show-managed-fields
```

## Common mistakes
- Fixing a child with `argocd app set`/`patch` while the root heals: the change lasts until the next root sync.
- Turning on self-heal before the ignore rule is in Git: Argo CD and the controller start rewriting each other.
- Silencing the shared ConfigMap with a second name: consumers still read the old one.

## Argo CD 2.x vs 3.x
Annotation-based tracking (3.x default) puts the owner in the resource id (`tracking-id`), which is what shows who owns
`thresholds`. On 3.6.1 the second Application just stays OutOfSync with `SharedResourceWarning`; there is no flip-flop.
