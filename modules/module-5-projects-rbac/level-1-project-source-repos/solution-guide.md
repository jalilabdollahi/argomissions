# Walkthrough — Repo Not Permitted

1. **Read the condition.**
   ```bash
   argocd app get claims-intake
   # CONDITION         MESSAGE
   # InvalidSpecError  application repo http://gitea.gitea.svc.cluster.local:3000/platform/intake-gateway.git is not permitted in project 'claims'
   ```
2. **Read the project.**
   ```bash
   argocd proj get claims
   # Source repositories: http://gitea.gitea.svc.cluster.local:3000/platform/claims-*
   ```
   The only allowed pattern is `claims-*`; the Application reads `intake-gateway`.
3. **Change the policy, not the Application.** Add the one repository the team needs:
   ```bash
   argocd proj add-source claims http://gitea.gitea.svc.cluster.local:3000/platform/intake-gateway.git
   ```
   (or `kubectl -n argocd edit appproject claims`, or the UI: Settings → Projects → claims → Source repositories).
4. **Let Argo CD notice.** `argocd app get claims-intake --hard-refresh`. The Application has automated sync,
   so it deploys on its own.
5. **Verify.**
   ```bash
   argocd app get claims-intake            # Synced, Healthy
   kubectl -n claims get deploy,svc
   ```
