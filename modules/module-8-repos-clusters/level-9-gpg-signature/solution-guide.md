# Walkthrough - Unsigned Commit Rejected

1. **Symptom.**
   ```bash
   argocd app get treasury-core
   # ComparisonError: GIT/GPG: Failed verifying revision <sha> by '...': unsigned (key_id=)
   ```
2. **Look at the project and the keyring.**
   ```bash
   kubectl -n argocd get appproject treasury -o jsonpath='{.spec.signatureKeys}'   # [{"keyID":"..."}]
   argocd gpg list                                                                  # the same key is trusted
   ```
3. **Look at the commits.** The v1 commit is signed, the colleague's v2 commit is not:
   ```bash
   cd treasury-core
   git log --format='%h %G? %GK %s' -3        # N = no signature
   ```
   (`git config gpg.program` shows how git reaches the release key.)
4. **Sign.** Either add a signed commit on top, or re-sign the unsigned tip:
   ```bash
   git commit --allow-empty -S -m "Sign off treasury-core v2"; git push
   # or: git commit --amend -S --no-edit; git push --force-with-lease
   ```
5. **Sync and verify.**
   ```bash
   argocd app sync treasury-core
   git log --format='%h %G? %s' -1             # G = good signature
   kubectl -n treasury get cm treasury-config -o jsonpath='{.data}'
   ```
   Do not touch `signatureKeys`: removing it, or adding your own key, defeats the control.
