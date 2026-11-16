# Black Friday Freeze: incident runbook

Four faults, two of them hidden behind the others. Work outside-in and re-check after every change.

## 1. Triage (5 min)
```bash
argocd app list
argocd app get bf-cart        # SyncWindow: Sync Denied, OutOfSync
argocd app get bf-promo       # Unknown, InvalidSpecError ... do not match any of the allowed destinations
argocd proj windows list blackfriday
kubectl -n bf-cart get deploy bf-cart -o jsonpath='{.spec.replicas}'   # 6, Git says 2
kubectl -n bf-scaler get deploy load-scaler                            # somebody else's controller
```
Nothing deploys while the deny window is active, so the autoscaler problem is invisible until the window lets
a sync through (the freeze hides it). The destination problem is independent of the window.

## 2. The freeze must let an approved human through
```bash
argocd proj windows enable-manual-sync blackfriday 0
```
Do not delete the window: the freeze is still wanted for automated syncs. (Narrowing it to the real freeze
hours also works, but then automated sync and self-heal run again, so the autoscaler fight starts at once.)

## 3. Tell Argo CD who owns `spec.replicas`
Git pins 2, the autoscaler wants 6. Exclude the field from comparison *and* from syncs:
```bash
argocd app patch bf-cart --type merge --patch '{"spec":{
  "ignoreDifferences":[{"group":"apps","kind":"Deployment","jsonPointers":["/spec/replicas"]}],
  "syncPolicy":{"syncOptions":["RespectIgnoreDifferences=true"]}}}'
```
Self-heal stays on. Do this BEFORE the first sync, otherwise the sync resets the Deployment to 2 and the
autoscaler immediately raises it again.

## 4. Ship the cart
```bash
argocd app sync bf-cart
argocd app wait bf-cart --health
```
`bf-cart` answers `bf-cart v9.0 black-friday` and keeps 6 replicas, generation stable.

## 5. The promo banner: two project problems and one manual sync
```bash
argocd proj add-destination blackfriday https://kubernetes.default.svc bf-promo
argocd app sync bf-promo          # fails: resource :Namespace is not permitted in project blackfriday
argocd proj allow-cluster-resource blackfriday '' Namespace
argocd app sync bf-promo
```
(`CreateNamespace=true` makes Argo CD create a cluster-scoped Namespace object, which a project must allow;
pre-creating the namespace and removing the option is the other valid answer.) `bf-promo` is a manual-sync
Application, so nothing deploys it until somebody syncs.

## 6. Verify
Both Applications Synced and Healthy at the head of their repos, `argocd proj windows list blackfriday` still shows
the deny window, `kubectl -n bf-cart get deploy bf-cart -o jsonpath='{.metadata.generation}'` does not move.
