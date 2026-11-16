# Walkthrough — The Permission That Vanishes

1. **Who owns the ConfigMap?**
   ```bash
   kubectl -n argocd get configmap argocd-rbac-cm -o yaml | grep tracking-id
   argocd app get argocd-settings
   ```
   The tracking annotation names Application `argocd-settings`; its sync policy is `automated` with
   `selfHeal: true`. Any difference between the live ConfigMap and Git is reverted within seconds.
2. **Do not fight it.** Turning self-heal off would let the manual edit stay, but the Application would be
   `OutOfSync` forever, the next sync (or the next person) would erase the line, and the repo would no longer
   describe the cluster.
3. **Change Git.** In your clone:
   ```bash
   cd argocd-settings
   $EDITOR config/argocd-rbac-cm.yaml
   ```
   Append to the `policy.csv` block (keep the existing lines):
   ```
       p, role:oncall, applications, sync, default/*, allow
       g, payments-oncall, role:oncall
   ```
   ```bash
   git commit -am "rbac: payments-oncall may sync in default" && git push
   ```
4. **Let Argo CD apply it.** The automated sync picks the commit up within a minute; to be quick:
   `argocd app get argocd-settings --refresh`. The sync deploys the new `policy.csv`; Argo CD's RBAC reloads it
   without a restart.
5. **Verify.**
   ```bash
   argocd admin settings rbac can payments-oncall sync applications 'default/x' --namespace argocd     # Yes
   argocd admin settings rbac can payments-oncall delete applications 'default/x' --namespace argocd   # No
   ```
   Then run `check`.
