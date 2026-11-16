# The Generator Ate The Fleet

## What broke
A "tidy-up" commit changed the git generator's path from `services/*` to `service/*`. That matches nothing, so the
ApplicationSet `orbit-fleet` generated zero Applications and did what it is designed to do: it deleted the
Applications it had created before. Each of them carried Argo CD's `resources-finalizer`, so deleting the Application
deleted the Deployments and Services too. Around the incident three more things stood in the way:
1. On-call had **paused the automation of `orbit-control`**, so a Git fix would never have reached the cluster.
2. On-call had **tightened project `orbit`** to a repository the services are not in (`InvalidSpecError ... is not permitted in project`).
3. **Nothing protected the fleet**: the next generator typo would delete the workloads again.

## Why Argo CD behaves this way
An ApplicationSet owns its Applications (owner references): it creates, updates and deletes them to match the
generator's output, and an empty output is a valid output, not an error. The finalizer on an Application means
"deleting me deletes what I deployed". Setting `spec.syncPolicy.preserveResourcesOnDeletion: true` on the set makes
the controller generate Applications without that finalizer. History matters too: Git is the audit trail and the
thing Argo CD reconciles against, so a revert is a new commit; a force-push erases evidence and breaks every clone.

## The fix
Re-enable automation on `orbit-control`, `git revert` the tidy-up and add `preserveResourcesOnDeletion: true` in
the same pushed change, and add the services repository back to project `orbit`. The set then regenerates the
three Applications, now without finalizers.

## In real life
Generators are the sharpest tool in GitOps: one wrong line removes a whole fleet, and the failure looks like success
(no error, a clean sync). Teams add review rules for ApplicationSet changes, `preserveResourcesOnDeletion` (and, where
enabled, the controller's `applicationsSync` policy) on production sets, and a dry-run of the generator output
(`argocd appset generate`) in CI. The incident also shows the cost of panic actions: paused automation, a narrowed
project and a proposed force-push each made the recovery longer.

## Commands worth remembering
```bash
argocd appset get orbit-fleet
argocd appset generate appsets/orbit-fleet.yaml        # what a set would produce, before you merge it
git revert --no-edit HEAD
kubectl -n argocd get applications -o custom-columns=N:.metadata.name,OWNER:.metadata.ownerReferences[0].name,FIN:.metadata.finalizers
argocd proj add-source PROJECT URL
argocd app set APP --sync-policy automated --auto-prune --self-heal
```

## Common mistakes
- Force-pushing `main` back to "yesterday": the fleet returns, the audit trail and every colleague's clone do not.
- Editing the ApplicationSet with `kubectl edit`: `orbit-control` heals it back to Git's broken version.
- Opening the project to `*` repositories to silence the InvalidSpecError.
- Fixing Git but leaving automation off: the repository is right and the cluster is still empty.

## Argo CD 2.x vs 3.x
Behaviour verified on 3.6.1: an empty generator deletes the generated Applications without any error condition, and
`preserveResourcesOnDeletion` also removes the finalizer from Applications that already exist. The set's
`applicationsSync` policy field is accepted in the spec, but only takes effect when the controller runs with policy
override enabled (it is off by default), so it is not a protection you can count on.
