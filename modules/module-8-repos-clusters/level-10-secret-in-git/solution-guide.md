# Walkthrough - The Leaked Password

1. **Confirm the leak and the ownership.**
   ```bash
   git -C smtp-gateway log --stat                         # deploy/secret.yaml since the first commit
   kubectl -n smtp-gw get secret smtp-credentials -o jsonpath='{.metadata.annotations}'   # tracking-id: Argo CD owns it
   ```
2. **Take the Secret out of Git** (no history rewriting - the leak must stay documented):
   ```bash
   cd smtp-gateway && git rm deploy/secret.yaml && git commit -m "Remove SMTP credentials" && git push
   argocd app get smtp-gateway --refresh        # OutOfSync: Secret "requires pruning"
   ```
3. **Retire the owned Secret and create the new one by another channel.**
   ```bash
   argocd app sync smtp-gateway --prune         # Argo CD deletes the Secret it created
   kubectl -n smtp-gw create secret generic smtp-credentials \
     --from-literal=username=mailer --from-literal=password="$(openssl rand -hex 12)"
   ```
   Alternative: edit the live Secret's password in place and remove the annotation `argocd.argoproj.io/tracking-id`
   so Argo CD stops considering it its own (do it after the Git commit, or Argo CD re-applies the old value).
4. **Make the pods use it.** Environment variables are fixed at container start:
   ```bash
   kubectl -n smtp-gw rollout restart deploy/smtp-gateway
   ```
5. **Verify.** `argocd app get smtp-gateway` is Synced/Healthy, `argocd app resources smtp-gateway` lists no Secret,
   the file is gone at `main` while `git log -S<old password>` still finds the old commit.
   The password was also changed at the SMTP provider in real life: it is burnt for good.
