# Walkthrough — The Hook That Never Ran

1. **See that the Job is invisible.**
   ```bash
   kubectl -n helpdesk get jobs          # No resources found
   argocd app get ticket-desk            # Deployment and Service only, no Job
   ```
   The Job is in Git (`ticket-desk/deploy/reindex-job.yaml`), the sync succeeded, yet nothing ran it.
2. **Read the annotation.**
   ```bash
   grep -n argocd ticket-desk/deploy/reindex-job.yaml
   # argocd.argoproj.io/hook: PreSynk
   ```
   `PreSynk` is not a hook phase. Argo CD sees a hook annotation, finds no valid phase in it and neither
   applies the Job as a normal resource nor runs it as a hook: it silently skips it.
3. **Fix the typo in Git.**
   ```bash
   cd ticket-desk
   sed -i.bak 's/PreSynk/PreSync/' deploy/reindex-job.yaml && rm deploy/reindex-job.yaml.bak
   git commit -am "reindex-tickets: fix hook annotation" && git push
   ```
4. **Sync the new head.** The desired non-hook manifests did not change, so the Application may look
   `Synced`, but hooks only run in a sync operation:
   ```bash
   argocd app get ticket-desk --refresh
   argocd app sync ticket-desk
   ```
5. **Verify.**
   ```bash
   argocd app get ticket-desk                 # Job reindex-tickets, HOOK PreSync, Succeeded
   kubectl -n helpdesk logs job/reindex-tickets   # index rebuilt: 18204 tickets
   ```
