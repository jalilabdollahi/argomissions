# Walkthrough — Secrets Are Blocked

1. **Read the failure and the policy.**
   ```bash
   argocd app get mail-relay          # resource :Secret is not permitted in project mailroom
   argocd proj get mailroom           # Denied Namespaced Resources: /Secret
   kubectl -n argocd get appproject mailroom -o jsonpath='{.metadata.annotations}'
   ```
   The blacklist is deliberate: SEC-114 says Secrets are not rendered from Git.
2. **Provide the Secret outside Argo CD.** The value is in `mail-relay/deploy/secret.yaml` (base64):
   ```bash
   grep token mail-relay/deploy/secret.yaml
   kubectl -n mailroom create secret generic relay-credentials --from-literal=token=relay-token-7f3a
   ```
3. **Take the Secret out of Git** and push:
   ```bash
   cd mail-relay && git rm deploy/secret.yaml && git commit -m "Secret is provided by the platform (SEC-114)" && git push
   ```
4. **Sync.** `argocd app sync mail-relay`, then `argocd app wait mail-relay --health`.
5. **Verify.**
   ```bash
   kubectl -n mailroom get secret relay-credentials      # exists, no argocd tracking annotation
   kubectl -n mailroom get deploy,svc
   ```
   In real life also rotate the token: it is still in Git history.
