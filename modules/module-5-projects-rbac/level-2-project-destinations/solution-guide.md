# Walkthrough — Destination Not Permitted

1. **Read the condition.**
   ```bash
   argocd app get rx-dispatch
   # InvalidSpecError  application destination server 'https://kubernetes.default.svc' and namespace 'pharmacy'
   #                   do not match any of the allowed destinations in project 'clinic'
   ```
2. **Read the project's destinations.**
   ```bash
   argocd proj get clinic
   # DESTINATIONS: https://kubernetes.default.svc  clinic-*
   ```
3. **Add the destination the team really needs** (exact namespace, same cluster):
   ```bash
   argocd proj add-destination clinic https://kubernetes.default.svc pharmacy
   ```
4. **Refresh and watch.** `argocd app get rx-dispatch --hard-refresh`; automated sync does the rest.
5. **Verify.**
   ```bash
   argocd app get rx-dispatch
   kubectl -n pharmacy get deploy,svc
   ```
