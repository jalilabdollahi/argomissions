# Walkthrough — Master Of Nothing

1. **Read the error.**
   ```bash
   argocd app get invoices
   ```
   `unable to resolve 'master' to a commit SHA: revision not found`. Argo CD asked Git for `master`.
2. **Check what the repo has.**
   ```bash
   cd invoices
   git branch -a        # only main
   git ls-remote --heads origin
   ```
3. **Change the Application, not the repo.**
   ```bash
   argocd app set invoices --revision main
   ```
   (UI: **App Details** → **Edit** → Target Revision. `HEAD` also works: it follows the default branch.)
4. **Sync.**
   ```bash
   argocd app sync invoices
   argocd app wait invoices --health
   ```
5. **Verify.**
   ```bash
   argocd app get invoices     # Synced, Healthy, revision = head of main
   kubectl -n invoices run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s invoices
   ```
   Then run `check` in the game.
