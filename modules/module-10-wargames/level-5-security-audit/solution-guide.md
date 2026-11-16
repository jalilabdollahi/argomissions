# Runbook: close the four audit findings

1. **Finding 1 - access.** `kubectl -n argocd get cm argocd-rbac-cm -o yaml` shows `policy.default: role:admin`.
   Set `policy.default` to empty (a default role applies to *every* account, the pipeline included: even `role:readonly`
   would let deploy-bot read clusters and repositories) and add to `policy.csv`: `g, kim, role:admin`,
   `g, sam, role:readonly`, a role `custody-deployer`
   with `applications, get` and `applications, sync` on `custody/*`, and `g, deploy-bot, role:custody-deployer`.
   Do the role for deploy-bot in the same change: the pipeline only worked through the admin default
   (`argocd account can-i sync applications custody/custody-api` as deploy-bot, with its own `--config`).
2. **Finding 3 - repo credentials.** `argocd repo list` / `kubectl -n argocd get secret -l argocd.argoproj.io/secret-type`
   show two `repository` secrets with user `player`. Create one template:
   `argocd repocreds add http://gitea.gitea.svc.cluster.local:3000/platform --username argo-reader --password reader-pass-8Rt3`
   and delete the two per-repo secrets. `custody-batch` then fails to load (the machine user cannot read it):
   give `argo-reader` read access to `platform/custody-batch` in Gitea (repo Settings > Collaborators, or
   `PUT /api/v1/repos/platform/custody-batch/collaborators/argo-reader {"permission":"read"}`), then hard-refresh.
3. **Finding 4 - project.** `argocd proj get custody`: `*/*`. The repo contains ClusterRole and ClusterRoleBinding
   `custody-metrics-reader`. Replace the whitelist with those two kinds
   (`argocd proj allow-cluster-resource custody rbac.authorization.k8s.io ClusterRole`, same for ClusterRoleBinding,
   and remove the wildcard; or edit the AppProject).
4. **Finding 2 - the password.** `git rm deploy/db-secret.yaml`, push, let `custody-api` sync (self-heal and prune remove
   the live Secret too). The old password is compromised for good: generate a new one and create the Secret
   out of band, e.g. `kubectl -n custody create secret generic custody-db --from-literal=password=$(openssl rand -hex 12)`,
   then restart the API pod so it picks it up. (Real clusters: Sealed Secrets / External Secrets / Vault; the
   point here is that the value never enters Git.) Rotate the password in the database too.
5. Verify: both Applications Synced/Healthy at head, `argocd account can-i` as each account, `argocd repocreds list`.
