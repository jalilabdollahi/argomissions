# Walkthrough — Every App Is OutOfSync

1. **Find the common cause.**
   ```bash
   argocd app list
   argocd app diff tallyline-ingest      # label complyd.argomissions.io/scan: pending in Git, scan-<epoch> live
   argocd app diff tallyline-rollup      # the same label, same story
   kubectl -n tallyline-ingest get deploy tallyline-ingest -o json | jq '.metadata.managedFields[] | {manager, operation}'
   ```
   The field manager `complyd` (the security team's scanner in `complyd-system`) rewrites the label every
   10 seconds. Deleting the scanner is not an option, and syncing only clears the diff for a moment.
2. **Do not fix it three times.** A `spec.ignoreDifferences` on each Application would work today, but the scanner
   stamps every Deployment, so every new Application would break the same way. Argo CD has a global setting.
3. **Add the customization to argocd-cm.** In a file `ignore.yaml`:
   ```yaml
   data:
     resource.customizations.ignoreDifferences.apps_Deployment: |
       jsonPointers:
       - /metadata/labels/complyd.argomissions.io~1scan
   ```
   ```bash
   kubectl -n argocd patch configmap argocd-cm --type merge --patch-file ignore.yaml
   ```
   (`jqPathExpressions` or `managedFieldsManagers: [complyd]` work too. Do not ignore `/spec` or all of
   `/metadata`: that would hide real drift.) The controller reads argocd-cm live; no restart.
4. **Refresh and verify.**
   ```bash
   for a in ingest rollup gateway; do argocd app get tallyline-$a --refresh | grep 'Sync Status'; done
   ```
   All three are Synced and stay Synced while the label keeps changing
   (`kubectl -n tallyline-ingest get deploy -L complyd.argomissions.io/scan`).
