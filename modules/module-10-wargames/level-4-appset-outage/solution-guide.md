# The Generator Ate The Fleet: incident runbook

## 1. Triage
```bash
argocd app list                                   # only orbit-control; the three orbit-* apps are gone
kubectl -n argocd get applicationset orbit-fleet -o yaml
git -C orbit-control log --stat -3                # "Simplify generator globs" touched appsets/orbit-fleet.yaml
git -C orbit-control show HEAD                    # path: services/*  ->  path: service/*
```
The git generator now matches no folder. An ApplicationSet whose generator returns nothing deletes every Application it
generated, and each Application's `resources-finalizer` deletes its workloads: that is how three apps and their
namespaces' contents vanished with no error condition.

## 2. Look at what on-call changed
```bash
argocd app get orbit-control      # sync policy: Manual. Nothing merged to Git reaches the cluster.
argocd proj get orbit             # sourceRepos: only orbit-control, not orbit-services
```

## 3. Fix, in this order
* Put the automation back on (otherwise a Git fix just sits there):
  ```bash
  argocd app set orbit-control --sync-policy automated --auto-prune --self-heal
  ```
* Undo the offending commit with a NEW commit (history only grows):
  ```bash
  cd orbit-control && git revert --no-edit HEAD
  ```
* In the same change, make the next mistake harmless. In `appsets/orbit-fleet.yaml`:
  ```yaml
  spec:
    syncPolicy:
      preserveResourcesOnDeletion: true
  ```
  Applications generated with this flag carry no `resources-finalizer`, so deleting an Application (or the set) leaves its workloads alone.
  ```bash
  git add -A && git commit -m "Protect the fleet" && git push
  ```
* Let the project read the services again:
  ```bash
  argocd proj add-source orbit http://gitea.gitea.svc.cluster.local:3000/platform/orbit-services.git
  ```
Do NOT edit the ApplicationSet in the cluster (orbit-control heals it back) and do NOT force-push.

## 4. Verify
`argocd app list` shows the three apps Synced and Healthy; `kubectl -n argocd get applications -o custom-columns=N:.metadata.name,OWNER:.metadata.ownerReferences[0].name,FIN:.metadata.finalizers`
shows owner `orbit-fleet` and no finalizers; `git log` still contains the tidy-up commit followed by its revert.
