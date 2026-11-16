# Walkthrough — Selector Is Immutable

1. **Read the error.**
   ```bash
   argocd app get ledger-api       # Sync Status OutOfSync, last operation Failed
   ```
   The message ends in `spec.selector: Invalid value: {"matchLabels":{"app":"ledger-api","cost-center":"cc-4711","team":"ledger"}}: field is immutable`.
2. **Find the cause.** `git -C ledger-api log -p -1` shows the commit adding `commonLabels` to
   `deploy/kustomization.yaml`. `argocd app manifests ledger-api` shows the labels inside the Deployment
   selector, while `kubectl -n ledger get deploy ledger-api -o jsonpath='{.spec.selector}'` still has only `app`.
3. **Change the Kustomization.** Labels must go on the objects and the pod template, but not into selectors:
   ```yaml
   labels:
   - pairs:
       team: ledger
       cost-center: cc-4711
     includeSelectors: false
     includeTemplates: true
   ```
   (remove `commonLabels:`). Check locally: `kubectl kustomize ledger-api/deploy`.
4. **Push and sync.**
   ```bash
   cd ledger-api && git commit -am "labels without selectors" && git push
   argocd app get ledger-api --refresh
   argocd app sync ledger-api
   argocd app wait ledger-api --health
   ```
5. **Verify.** `kubectl -n ledger get pods --show-labels` shows `team=ledger,cost-center=cc-4711`, the selector is
   unchanged. Then run `check`.
