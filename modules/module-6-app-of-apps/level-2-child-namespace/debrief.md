# Debrief — Children In The Wrong Namespace

## What broke
The root's destination namespace was `billing-system`. The child Application manifests in Git have no
`metadata.namespace`, so Argo CD created them in the destination namespace of the root. They were valid objects in
the wrong place: the application controller only reconciles Applications in the `argocd` namespace, so they had no
status, no sync and no workloads. The root itself was perfectly happy: it had applied exactly what Git said.

## Why Argo CD behaves this way
`destination.namespace` is the default namespace for every namespaced object whose manifest does not name one. For an
app-of-apps root the "workload" is the Application custom resource, which only works in a namespace the controller
(and the API server's project checks) watch. Argo CD can reconcile Applications in other namespaces, but only after an
administrator enables apps-in-any-namespace (`--application-namespaces`, plus `sourceNamespaces` on the project); it
is off by default and was off here. No error is raised for an ignored Application.

## The fix
Set the root's destination namespace to `argocd` (or name `namespace: argocd` in the child manifests). The correct
children appear and sync. The copies created earlier are still tracked by the root and are no longer in Git's desired
state, so the root becomes OutOfSync with `requiresPruning` until they are pruned (`argocd app sync billing-root
--prune`), which also removes the stray objects.

## In real life
Roots are often copied from a template with the namespace of the previous project, or the destination is set to the
team's namespace "for tidiness". Look for Applications with empty status columns: `kubectl get applications -A`
shows what the `argocd app list` hides.

## Commands worth remembering
- `kubectl get applications.argoproj.io -A` — every Application object, in every namespace.
- `argocd app get ROOT` — the resource list with namespaces and prune markers.
- `argocd app sync ROOT --prune` — remove what Git no longer wants.

## Common mistakes
- Fixing the destination and stopping there: the orphaned copies keep the root OutOfSync.
- Applying the children by hand into `argocd`: they run, but the root does not maintain them.
- Enabling apps-in-any-namespace to "make it work" instead of fixing where the objects are created.
