# Walkthrough — Keep The Data

1. **See what would happen.** The claim is tracked by the Application and the policy is `Automated (Prune)`:
   ```bash
   argocd app get media-store
   kubectl -n media get pvc uploads -o jsonpath='{.metadata.uid}{"\n"}'
   kubectl -n media get cm storage-audit -o yaml
   ```
   Remove `deploy/pvc.yaml` straight away and the next sync prunes the claim (it hangs in `Terminating` while
   the pod mounts it and is gone when the pod restarts). Do not try it.
2. **Protect the live object first.** Edit `media-store/deploy/pvc.yaml`:
   ```yaml
   metadata:
     name: uploads
     annotations:
       argocd.argoproj.io/sync-options: Prune=false
   ```
   Commit and push; wait until the app is Synced at that commit and check
   `kubectl -n media get pvc uploads -o jsonpath='{.metadata.annotations}'` shows `Prune=false`.
   Argo CD takes the prune options from the live object, so this must be applied before the file is removed.
3. **Remove the manifest.** `git rm deploy/pvc.yaml`, commit, push. The sync result for the claim now says
   `ignored (no prune)` and the claim lives on — but the Application is `OutOfSync`, because a tracked object
   that is not in Git is a difference, whether or not it may be pruned.
4. **Tell Argo CD the leftover is expected.** Add the compare option next to the first annotation (in step 2,
   or on the live claim with `kubectl annotate pvc uploads argocd.argoproj.io/compare-options=IgnoreExtraneous`):
   ```yaml
       argocd.argoproj.io/compare-options: IgnoreExtraneous
   ```
   With it the extraneous claim no longer counts for the Application's sync status. The simplest path is to
   put both annotations in the step 2 commit.
5. **Verify.** `argocd app get media-store` is `Synced`/`Healthy`, the claim shows `ignored (no prune)`, and
   its UID still equals the one in `storage-audit`. Then run `check` in the game.
