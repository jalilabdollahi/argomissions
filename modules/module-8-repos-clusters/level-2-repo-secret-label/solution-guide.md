# Walkthrough — The Secret Argo CD Ignores

1. **Confirm the symptom.**
   ```bash
   argocd app get parcel-tracker      # ComparisonError ... authentication required: Unauthorized
   argocd repo list                   # the parcel-tracker repository is not there
   kubectl -n argocd get secret repo-parcel-tracker --show-labels
   ```
2. **Spot the label.** The Secret has `argocd.argoproj.io/secret-type=repo`. Argo CD only recognises
   `repository` (a repo entry), `repo-creds` (credential template), `cluster`, `gpg-key`... `repo` matches nothing, so
   the Secret is just a Secret.
3. **Fix it.**
   ```bash
   kubectl -n argocd label secret repo-parcel-tracker argocd.argoproj.io/secret-type=repository --overwrite
   ```
   (Or `argocd repo add URL --username argo-reader --password ...`, which writes a correct Secret for you.)
4. **Refresh and verify.**
   ```bash
   argocd repo list                                 # shows the repo, status Successful
   argocd app get parcel-tracker --hard-refresh     # Synced / Healthy
   ```
