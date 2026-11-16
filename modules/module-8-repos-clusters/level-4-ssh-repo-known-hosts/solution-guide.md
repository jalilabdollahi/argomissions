# Walkthrough — Host Key Verification Failed

1. **Read the error.**
   ```bash
   argocd app get fleet-agent       # ... ssh: handshake failed: knownhosts: key is unknown
   argocd cert list --cert-type ssh # github, gitlab, bitbucket, ... no gitea.gitea.svc.cluster.local
   ```
   The deploy key is registered on the repo in Gitea (Settings > Deploy Keys) and is not the problem.
2. **Get the server's host keys** from where Argo CD connects (the repo-server pod has `ssh-keyscan`):
   ```bash
   kubectl -n argocd exec deploy/argocd-repo-server -- ssh-keyscan gitea.gitea.svc.cluster.local
   ```
   Verify them out of band if you can: Gitea's keys are in `/var/lib/gitea/ssh/*.pub` in the gitea pod.
3. **Register them.**
   ```bash
   kubectl -n argocd exec deploy/argocd-repo-server -- ssh-keyscan gitea.gitea.svc.cluster.local 2>/dev/null \
     | argocd cert add-ssh --batch
   ```
   (Equivalent: add the lines to `argocd-ssh-known-hosts-cm` under `ssh_known_hosts`.)
4. **Refresh and wait.** The repo-server sees the ConfigMap after its volume refreshes (up to about a minute):
   `argocd app get fleet-agent --hard-refresh` until it is Synced / Healthy.
5. Do not set `insecure: "true"` on the repository or use `--insecure-ignore-host-key`.
