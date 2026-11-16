# Walkthrough — Field Is Immutable

1. **Read the failure.**
   ```bash
   argocd app get ticket-desk
   ```
   The Service is `Synced` (it was patched to the new selector), the Deployment is `OutOfSync` with
   `spec.selector ... field is immutable`. The Service now selects `app.kubernetes.io/name=ticket-desk`, which the
   old pods do not carry: that is why nothing answers.
2. **Confirm what is live and what Git wants.**
   ```bash
   kubectl -n helpdesk get deploy ticket-desk -o jsonpath='{.spec.selector}'   # {"matchLabels":{"app":"ticket-desk"}}
   grep -A1 selector ticket-desk/deploy/deployment.yaml                         # app.kubernetes.io/name
   argocd app diff ticket-desk
   ```
3. **Do not revert Git.** The new labels are the intended state. Retrying the plain sync cannot work: Kubernetes
   rejects any update of `spec.selector`. Even `Replace=true` (`kubectl replace`) fails with the same error.
4. **Delete and re-create the Deployment through Argo CD.**
   ```bash
   argocd app sync ticket-desk --force
   ```
   `--force` makes Argo CD delete an object it cannot update and create it again. (UI: Sync → tick **Force**.)
   The alternative is to delete the Deployment yourself and sync:
   ```bash
   kubectl -n helpdesk delete deploy ticket-desk
   argocd app sync ticket-desk
   ```
5. **Verify.**
   ```bash
   argocd app get ticket-desk                     # Synced, Healthy
   kubectl -n helpdesk get deploy,pods,svc
   kubectl -n helpdesk run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s ticket-desk
   ```
   Expected answer: `ticket-desk v1.1`. Then run `check` in the game.

Expect a short gap while the pods are re-created: the Deployment is deleted, not rolled.
