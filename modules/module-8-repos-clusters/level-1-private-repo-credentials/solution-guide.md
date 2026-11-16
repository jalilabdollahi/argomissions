# Walkthrough — Authentication Required

1. **Read the error.**
   ```bash
   argocd app get vault-ui     # ComparisonError ... failed to list refs: authentication required: Unauthorized
   argocd repo list            # nothing: Argo CD holds no credentials for the repo
   ```
   Check in Gitea that the repo is private and that `argo-reader` is a read collaborator (handoff.md).
2. **Give Argo CD the machine user's credentials**, for the exact URL the Application uses:
   ```bash
   argocd repo add http://gitea.gitea.svc.cluster.local:3000/platform/vault-ui.git \
     --username argo-reader --password 'reader-pass-7Q2x'
   ```
   Declarative equivalent:
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: repo-vault-ui
     namespace: argocd
     labels:
       argocd.argoproj.io/secret-type: repository
   stringData:
     type: git
     url: http://gitea.gitea.svc.cluster.local:3000/platform/vault-ui.git
     username: argo-reader
     password: reader-pass-7Q2x
   ```
3. **Refresh** so you do not wait for the next reconciliation: `argocd app get vault-ui --hard-refresh`.
   The automated sync then deploys; `argocd app get vault-ui` shows Synced / Healthy.
4. **Verify**: `kubectl -n vault-ui run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s vault-ui`
   answers `vault-ui v2.4`. Do not make the repo public and do not use `player`.
