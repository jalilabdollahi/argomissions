# Walkthrough - The Parameter That Wins

1. **Look beyond the sync status.**
   ```bash
   argocd app get media-gateway           # Synced, Healthy - at the latest commit
   argocd app manifests media-gateway | grep -- -text   # -text=media-gateway 1.9.1-hotfix
   ```
2. **Find the override.**
   ```bash
   kubectl -n argocd get application media-gateway -o jsonpath='{.spec.source.helm}'
   # {"parameters":[{"name":"release.version","value":"1.9.1-hotfix"}]}
   ```
   `argocd app get` also lists it as `Helm Parameters: release.version=1.9.1-hotfix`.
3. **Remove it** (do not edit values.yaml again - the override would still win):
   ```bash
   argocd app unset media-gateway -p release.version
   ```
   (UI: App Details, Parameters, remove the entry.) The Application has automated sync, so it rolls out by itself;
   `argocd app wait media-gateway --health` waits for it.
4. **Verify.**
   ```bash
   argocd app manifests media-gateway | grep -- -text   # -text=media-gateway 2.1
   kubectl -n media run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s media-gateway
   ```
   Then run `check` in the game.
