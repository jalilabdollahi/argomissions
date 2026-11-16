# Walkthrough — Update Is Not Delete

1. **Reproduce as mira** (own config file, your admin session stays):
   ```bash
   argocd login localhost:9080 --plaintext --username mira --password mira-pw-4821 --config /tmp/mira-cli
   argocd app actions run rewards-engine restart --kind Deployment --resource-name rewards-engine --group apps --config /tmp/mira-cli
   # rpc error: code = PermissionDenied desc = permission denied
   ```
2. **Read her role.** `kubectl -n argocd get cm argocd-rbac-cm -o yaml` shows `applications, update, loyalty/*`.
   In Argo CD 3.x `update` and `delete` only cover the Application object. The resources it manages (and their
   actions) have their own policy forms:
   - run an action: `applications, action/<group>/<kind>/<action>, <project>/<app>`
   - delete a managed resource: `applications, delete/<group>/<kind>/<namespace>/<name>, <project>/<app>`
   - patch a managed resource: `applications, update/<group>/<kind>/<namespace>/<name>, <project>/<app>`
3. **Add exactly what she needs** to `policy.csv`:
   ```
   p, role:loyalty-oncall, applications, action/apps/Deployment/restart, loyalty/*, allow
   p, role:loyalty-oncall, applications, delete/*/Pod/*/*, loyalty/*, allow
   ```
   `kubectl -n argocd edit cm argocd-rbac-cm`. Argo CD reloads it within seconds.
4. **Verify.** Run the restart action again as mira; it works. Then check that `delete/*` and `action/*` were
   not needed: she still cannot delete a Secret or run `scale`.
