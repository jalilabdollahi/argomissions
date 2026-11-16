# Walkthrough — Expired Credentials

1. **Read the symptom.**
   ```bash
   argocd app get mailroom        # ComparisonError ... authentication required
   argocd repo list               # the repository's connection status is Failed
   git -C mailroom log --oneline  # v3.2 exists in Git (clone it from Gitea if you want to see it)
   ```
2. **Find the cause.** Argo CD authenticates with the token in Secret `repo-mailroom`. In Gitea, signed in as
   `argo-reader` (password in `workspace/handoff.md`), Settings > Applications no longer lists that token: it was revoked.
3. **Rotate.** Create a new token (name it uniquely, scope `read:repository`), and store it:
   ```bash
   argocd repo add http://gitea.gitea.svc.cluster.local:3000/platform/mailroom.git \
     --username argo-reader --password <NEW_TOKEN> --upsert
   ```
   Or: `kubectl -n argocd patch secret repo-mailroom --type merge -p '{"stringData":{"password":"<NEW_TOKEN>"}}'`.
4. **Refresh and verify.** `argocd app get mailroom --hard-refresh`: the automated sync deploys v3.2.
   `argocd repo list` shows the repository as Successful again.
