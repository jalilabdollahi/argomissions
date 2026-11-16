# Debrief — The Day The Root Was Deleted

## What broke
A harmless-looking cleanup commit deleted `apps/api.yaml`. The root `inventory-root` has automated prune, so it deleted
the child Application `stock-api`; the child carried `resources-finalizer.argocd.argoproj.io`, so Argo CD then deleted
everything the child had deployed. One file removed in Git took a production service down within a minute, exactly as
designed. The service was recoverable only because Git still had the old manifest.

## Why Argo CD behaves this way
In an app-of-apps the child Application is just another resource of the root: removing it from Git means "prune it", and a
finalizer on it means "when you delete it, delete what it owns". The two defaults chain into a cascade. Two sync options
on the child Application break the chain at the two places it can start. `argocd.argoproj.io/sync-options: Prune=false`
makes the root skip pruning the child (the root shows `OutOfSync`, "ignored (no prune)", until someone decides). On Argo CD
3.6.1 `Delete=false` does not do that, a child with only `Delete=false` was still pruned; it applies when the root itself is
deleted: the children are kept (and keep their workloads) instead of being removed through the root's cascade. Use both,
comma separated.

## The fix
Restore the manifest with a new commit (`git revert` or checkout from the commit before the accident), never with a force
push: the history shows what happened and how it was corrected. Add `Prune=false,Delete=false` to every child manifest
in Git so the root applies the protection to the live objects. Removing a service now takes two deliberate steps: remove
the protection, then the manifest.

## In real life
The blast radius of a root is every service under it: a bad merge, a wrong path in the root, an `argocd app delete` of the
wrong application, or a bootstrap tool that "recreates" the root. Critical children (databases, ingress, the platform
itself) deserve the protection, or a separate, more restricted root and project. Combine with branch protection and code
review for the folder the root watches.

## Commands worth remembering
- `git log --stat` / `git revert COMMIT` — find and undo the change without rewriting history.
- `kubectl -n argocd get application NAME -o jsonpath='{.metadata.annotations}'` — which sync options a child has.
- `argocd app get ROOT` — resources shown `ignored (no prune)` are protected from pruning.

## Common mistakes
- Force-pushing the old state: the service returns, the audit trail and everyone else's clones do not.
- Adding only `Delete=false` and believing the child is safe from the manifest being removed.
- Restoring only the manifest: the next accident is a repeat.

## Argo CD 2.x vs 3.x
Nothing in this mission changed with 3.x; the cascade and sync options behave as in 2.x. Annotation-based resource
tracking (the default since 3.0) is why the leftover objects of a deleted app can be found by `tracking-id`.
