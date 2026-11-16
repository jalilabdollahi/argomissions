# Walkthrough - Waiting For The Poll

1. **Look at the delivery from both ends.** In Gitea (repo -> Settings -> Webhooks -> Recent Deliveries) the delivery
   answers `400 Webhook processing failed`. On the Argo CD side:
   ```bash
   kubectl -n argocd logs deploy/argocd-server | grep -i webhook
   # Gogs webhook HMAC verification failed ... Webhook processing failed: HMAC verification failed
   ```
   The URL works and Argo CD answers: it does not accept the signature.
2. **Compare the secrets.** `argocd-secret` has `webhook.gitea.secret` with the hook's secret, yet nothing changes:
   Argo CD has no such key.
   ```bash
   kubectl -n argocd get secret argocd-secret -o json | jq -r '.data | keys[]' | grep webhook
   ```
3. **Find the key that is really used.** Gitea sends `X-Gitea-Event`, `X-Gogs-Event` and `X-GitHub-Event` headers.
   Argo CD takes the Gogs handler, whose secret is `webhook.gogs.secret` (holding an old value from a previous server).
4. **Fix it.**
   ```bash
   kubectl -n argocd patch secret argocd-secret --type merge \
     -p "{\"data\":{\"webhook.gogs.secret\":\"$(kubectl -n argocd get secret argocd-secret -o jsonpath='{.data.webhook\.gitea\.secret}')\"}}"
   ```
   (Alternative: re-create the Gitea hook with the secret that Argo CD holds.)
5. **Verify.** Press "Test Delivery" on the hook: the response is 200 and the Argo CD log shows
   `Received push event repo: ..., revision: main, touchedHead: true`.
