# The Chart Migration: incident runbook

Four faults. The first one hides the other three, so every step is "fix, re-read, look again".

## 1. Triage
```bash
argocd app get stockroom-db-v2        # ComparisonError: ... values/prod.yaml: no such file or directory
argocd app get stockroom-db-v2 -o yaml | grep -A12 helm:
git -C stockroom-db ls-files chart    # the file is values/production.yaml
```
The manifests cannot even be rendered, so Argo CD cannot show you a diff yet.

## 2. Point at the right values file
```bash
argocd app set stockroom-db-v2 --values values/production.yaml
argocd app diff stockroom-db-v2
```
Now the diff is readable and it is alarming: new objects named `stockroom-db-v2`, a new PVC `stockroom-db-v2-storage`,
and the old Deployment, Service and PVC `stockroom-db-data` marked for pruning. Do not sync. Also the message value
is `stockroom-db hotfix-2.9`, not what `values/production.yaml` says.

## 3. Release name, parameter, volume
```bash
argocd app set stockroom-db-v2 --release-name stockroom-db        # objects keep the consumers' names
argocd app unset stockroom-db-v2 --parameter message              # a parameter always beats the values file
```
The chart derives the claim name from the release (`<release>-storage`), which is not the existing claim.
In your clone add to `chart/values/production.yaml`:
```yaml
persistence:
  claimName: stockroom-db-data
```
Commit and push (or use `argocd app set ... -p persistence.claimName=stockroom-db-data`).

## 4. Check the diff again, then sync without pruning
```bash
argocd app diff stockroom-db-v2     # Deployment/Service/PVC updated in place, nothing created, nothing pruned
argocd app sync stockroom-db-v2
```

## 5. Verify
`curl` the service from a pod: `/` answers `stockroom-db prod 3.0`, `/seq` answers `seq=4821 shipments=1873`;
`kubectl -n stockroom get pvc` shows only `stockroom-db-data`, with its original age.
