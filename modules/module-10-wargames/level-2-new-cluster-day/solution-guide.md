# First Day On The New Cluster: incident runbook

Four faults in a chain: each one only becomes visible after the one before it is fixed.

## 1. Bootstrap the root
```bash
cat tidewater-gitops/README.md
kubectl apply -f tidewater-gitops/bootstrap/root.yaml
argocd app get tidewater-root
```
The root is created but `Unknown`: `ComparisonError: ... authentication required`. The root exists only after you
apply it: nothing in Git can create the Application that reads Git.

## 2. Give Argo CD credentials for the private repo
The machine user is in `handoff.md` (never `player`, never make the repo public):
```bash
argocd repo add http://gitea.gitea.svc.cluster.local:3000/platform/tidewater-gitops.git \
  --username tidewater-reader --password reader-pass-4Kd9
argocd app get tidewater-root --hard-refresh
```
(A Secret with label `argocd.argoproj.io/secret-type: repository` is the declarative equivalent.) The root syncs:
the project first (sync-wave -1), then the three child Applications.

## 3. Read each child
```bash
argocd app list
argocd app get tidewater-ledger   # sync failed: namespaces "tidewater-ledger" not found
argocd app get tidewater-batch    # InvalidSpecError ... namespace 'tidewater-jobs' do not match any of the allowed destinations
argocd app get tidewater-gateway  # fine
```
Do NOT patch the children or create the namespace by hand: the root heals the Applications back, and a hand-made
namespace would not exist on the next new cluster. Both fixes belong in Git.

## 4. Fix both in Git
In your clone:
* `platform/apps/tidewater-ledger.yaml`: add under `syncPolicy`
  ```yaml
  syncOptions:
  - CreateNamespace=true
  ```
* `platform/projects/tidewater.yaml`: add a destination for `tidewater-jobs`
  ```yaml
  - server: https://kubernetes.default.svc
    namespace: tidewater-jobs
  ```
```bash
git add -A && git commit -m "Create the ledger namespace, allow tidewater-jobs" && git push
argocd app get tidewater-root --refresh
```
The ledger's first automated sync is still *Running* (it retries with the parameters it started with, which lack
the new option). End it so the next automated sync uses the fixed spec:
```bash
argocd app terminate-op tidewater-ledger
```

## 5. Verify
All four Applications Synced and Healthy at the head of `main`; the Services answer; the repo is still private;
`kubectl get namespace tidewater-ledger -o yaml` is owned by the sync, not by a person.
