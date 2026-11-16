# Who Owns This?

## What broke
Nothing Argo CD could see. `query-service` was Synced and Healthy because Argo CD only compares what is in Git
with what it created. A Deployment someone had applied with `kubectl` months ago, running in the same namespace,
was invisible to it, costing money and answering requests nobody remembered.

## Why Argo CD behaves this way
Sync status is about *managed* resources only. To also report **orphaned resources** (objects in the
destination namespaces of a project's applications that no Application owns), the AppProject has to ask for it:
`spec.orphanedResources`. With `warn: true` every Application of the project gets an `OrphanedResourceWarning`
condition with the count, and `argocd app resources APP --orphaned` lists them (the list also shows children
like the ReplicaSet and Pod of an orphaned Deployment). The result is recomputed on refresh. The setting never
deletes anything: Argo CD tells, people decide.

Legitimate unmanaged objects (here a certificate issued by hand) are declared with `orphanedResources.ignore`:
entries with `group`, `kind` and `name`, each optional and glob-capable. Keep them narrow: `kind: "*"`
silences the warning for everything, forever.

## The fix
Enable the monitoring on the project, read the list, delete the object that is truly stray, and add a narrow ignore
rule for the documented Secret. Both parts matter: deleting the Secret would break the certificate rotation
runbook, and ignoring the Deployment would keep paying for it.

## In real life
Orphan warnings are how teams find the leftovers of `kubectl apply` during incidents, abandoned test
workloads and objects created by other controllers. Start with `warn: true` and an ignore list that documents
every known exception (with the runbook in an annotation), and treat any new warning as a review item.

## Commands worth remembering
```bash
argocd proj get PROJECT
argocd app get APP --hard-refresh
argocd app resources APP --orphaned
kubectl -n argocd get app APP -o jsonpath='{.status.conditions}'
kubectl -n argocd patch appproject PROJECT --type merge -p '{"spec":{"orphanedResources":{"warn":true}}}'
```

## Common mistakes
- Deleting everything the warning lists: the documented exception goes with it.
- Silencing the warning with a wildcard ignore rule instead of naming the exceptions.
- Expecting Argo CD to prune orphans: `prune` only removes objects it created from Git.
