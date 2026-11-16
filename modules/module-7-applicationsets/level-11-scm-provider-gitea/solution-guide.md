# Walkthrough — Every Repo An App

1. **Read the error.**
   ```bash
   kubectl -n argocd get applicationset mesh-fleet -o jsonpath='{.status.conditions[?(@.type=="ErrorOccurred")].message}'
   # error fetching Gitea token: key "access-token" in secret argocd/gitea-scm-token not found
   ```
2. **Compare with the Secret.**
   ```bash
   kubectl -n argocd get secret gitea-scm-token -o json | jq '.data | keys'     # ["token"]
   ```
   The generator's `tokenRef` asks for `access-token`, the Secret stores the token as `token`.
3. **Fix the reference** in `mesh-appset.yaml`:
   ```yaml
         tokenRef:
           secretName: gitea-scm-token
           key: token
   ```
   and `kubectl apply -f mesh-appset.yaml`. (Or leave the ApplicationSet alone and add an `access-token` key
   to the Secret. The controller does not watch Secrets, so it retries only after its error back-off, which grows to
   minutes: ask for a refresh with
   `kubectl -n argocd annotate applicationset mesh-fleet argocd.argoproj.io/application-set-refresh=true`.)
4. **Check what was generated.**
   ```bash
   argocd appset get mesh-fleet
   argocd app list          # mesh-pinger, mesh-quill, mesh-ember; no wiki-notes thanks to repositoryMatch '^mesh-'
   ```
   The generator also lists `wiki-notes`, `repositoryMatch` is what keeps it out.
5. **Verify** each Service answers (`curl mesh-pinger.mesh-pinger` from a pod: `mesh-pinger v1`), then run `check`.
