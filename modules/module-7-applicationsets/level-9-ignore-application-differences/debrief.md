# The Set Reverts My Change

## What broke
Nothing was misconfigured: the ApplicationSet did exactly what it is built for. The on-call engineer changed
`targetRevision` on a generated Application and the ApplicationSet controller put it back to the value the template
produces (`main`), within seconds, every time.

## Why Argo CD behaves this way
An ApplicationSet is the single source of truth for the Applications it generates. On every reconcile it renders the
template for every set of parameters and, for each existing Application, rewrites the Application's `spec` (and
labels, annotations, finalizers) when they differ from the rendered result. Any change made directly on a child
Application is therefore overwritten, unless you say otherwise. It is also triggered by events on the owned
Applications, which is why the revert is almost instant and not on a timer.

`spec.ignoreApplicationDifferences` is the escape hatch. It lists fields (`jsonPointers`, or `jqPathExpressions`
for finer control, optionally with a `name` to restrict it to one Application) that the controller compares but never
overwrites on existing Applications. New Applications still get the template value, and every other field is still
enforced. Note the cost: for the ignored field Git no longer describes the cluster, so such overrides must be
deliberate, temporary and visible.

## The fix
Either let the controller ignore `/spec/source/targetRevision`, apply the ApplicationSet, then set the revision on
`feedhub-prod`; or move the decision into Git/the generator (a `revision` element parameter used by the template),
which keeps everything declarative and reviewed. The second one is what you want for anything that should last.

## In real life
This is the classic "someone pinned a canary for an incident and it silently moved back" story. The same
mechanism is used for fields that other controllers write on Applications (for example the `syncPolicy.automated`
toggled by a promotion tool, or `targetRevision` bumped by a release pipeline), which are legitimately not owned by the
template. Use it narrowly: ignoring all of `/spec` turns the ApplicationSet into a creator-only tool.

## Commands worth remembering
```bash
kubectl explain applicationset.spec.ignoreApplicationDifferences
argocd appset get feedhub
argocd app set feedhub-prod --revision hotfix-1.8.1
kubectl -n argocd get application feedhub-prod -o jsonpath='{.metadata.ownerReferences}'
```

## Common mistakes
- Ignoring the wrong pointer (`/spec/targetRevision` does not exist in an Application) and wondering why nothing changed.
- Patching the Application first, adding the ignore rule second: the first change is already lost.
- Deleting the ownerReference from the Application to make it "stop reverting": it then lives outside the fleet
  and no longer follows the template at all.

## Argo CD 2.x vs 3.x
`ignoreApplicationDifferences` exists since 2.9 and behaves the same in 3.x. In both versions the `jsonPointers`
are evaluated against the Application resource, not against the template.
