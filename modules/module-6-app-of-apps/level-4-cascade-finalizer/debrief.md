# Debrief — Deleting The Child Left Everything

## What broke
Retiring `tariff-legacy` meant deleting its manifest from the root's folder. The root has prune enabled, so it deleted
the child Application object, and Argo CD stopped there: the Deployment and Service the child had deployed kept running
in `tariff-old`, carrying a tracking annotation for an Application that no longer exists.

## Why Argo CD behaves this way
Deleting an Application and deleting what it deployed are separate things. The cascade only happens when the
Application has the finalizer `resources-finalizer.argocd.argoproj.io`: Kubernetes keeps the object in `Terminating`,
the controller deletes every managed resource, and then removes the finalizer. Without it the object disappears at once
(the same as `argocd app delete --cascade=false`). In an app-of-apps layout the root deletes the child by pruning, so the
child's own manifest must say what should happen: the finalizer belongs in the Application YAML in Git, not in a CLI flag.
Resources left behind are not "orphaned resources" in the project sense; nothing tracks them any more.

## The fix
Add the finalizer to the child Application manifests (the live Application changes on the next root sync). Then remove
what the first retirement left behind: re-add the retired Application with the finalizer, let it adopt the workload,
and delete it again so the cascade removes it, or delete the leftovers by hand. Do not leave it running "just in case".

## In real life
Teams discover this months later: costs and old versions keep running after the service was "removed from GitOps".
The reverse is also real: with the finalizer a mistaken deletion removes production (see the next mission). Decide
per child, in Git.

## Commands worth remembering
- `kubectl -n argocd get application NAME -o jsonpath='{.metadata.finalizers}'` — will it cascade?
- `kubectl get deploy -A -o json | jq '.items[]|select(.metadata.annotations["argocd.argoproj.io/tracking-id"]|startswith("APP:"))'` — find resources of a deleted app.
- `argocd app delete NAME --cascade=false` — delete the Application only (the default behaviour without the finalizer).

## Common mistakes
- Adding the finalizer and forgetting the workload that is already orphaned.
- Deleting the leftovers with kubectl and leaving the Application manifests without the finalizer.
- Putting the finalizer only on the live object with `kubectl patch`: the root's next sync removes it again.
