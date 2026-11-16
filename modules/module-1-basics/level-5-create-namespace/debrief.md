# No Room At The Inn

## What broke
The Application targets namespace `ledger`, but that namespace did not exist. Argo CD applied the Deployment
and Service, the API server answered `namespaces "ledger" not found` for both, and the sync operation failed.
The Application stayed `OutOfSync`, with an operation history entry that says why.

## Why Argo CD behaves this way
`spec.destination.namespace` only tells Argo CD which namespace to put namespaced objects in: it applies
exactly what Git renders, and by default does not add a Namespace of its own. Creating namespaces silently could
hide typos (a misspelled namespace would just appear), so it is opt-in through a **sync option**:
`CreateNamespace=true` in `spec.syncPolicy.syncOptions`. With it, Argo CD creates the namespace before applying
the resources if it is missing.

Options are part of the Application, and the CLI and UI copy them into every sync operation they start.
Teams who want labels or annotations on the namespace can instead keep a Namespace manifest in Git (ordered
with a sync wave) or use `managedNamespaceMetadata`.

## The fix
Add `CreateNamespace=true` to the Application's sync options and sync again. The namespace is now created
through the Application on any cluster that lacks it.

## In real life
A manual `kubectl create namespace` is the classic one-time fix that disappears on the next cluster: the
staging copy, the disaster-recovery rebuild, or the new region fail the same way, and the person who made the
original namespace is not around. Putting the option in the Application (kept in Git) makes the bootstrap
repeatable. Note that Argo CD does not delete a namespace it created when the Application is deleted.

## Commands worth remembering
```bash
argocd app get NAME                              # last operation, failed resources
argocd app set NAME --sync-option CreateNamespace=true
argocd app history NAME
kubectl get events -A --sort-by=.lastTimestamp
```

## Common mistakes
- `kubectl create namespace ledger` and sync: it works today, but the Application still cannot deploy to a
  cluster that does not have the namespace.
- Setting the option but not syncing again: the failed operation stays the last word.
- Patching `syncOptions` in the resource and starting a sync with a bare API call: an `operation` does not
  inherit the Application's options by itself (the CLI and the UI copy them in).
