# Walkthrough — Orphaned Children

1. **Read the symptom.**
   ```bash
   argocd app list                       # root Synced/Healthy; trace-* Unknown with InvalidSpecError
   argocd app get trace-collector        # not allowed in project "tracing-team", or the project does not exist
   kubectl -n argocd get appprojects     # only "default"
   ```
2. **Read the repo.** `README.md` says the team project may deploy only from this repo into the namespaces
   `tracing-collector` and `tracing-query`. The root's folder `apps/` has the two Applications and no AppProject.
3. **Add the project to the root's folder**, `apps/project.yaml`:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: AppProject
   metadata:
     name: tracing-team
     namespace: argocd
     annotations:
       argocd.argoproj.io/sync-wave: "-1"      # before the Applications (wave 0)
   spec:
     sourceRepos:
     - http://gitea.gitea.svc.cluster.local:3000/platform/tracing-gitops.git
     destinations:
     - {server: https://kubernetes.default.svc, namespace: tracing-collector}
     - {server: https://kubernetes.default.svc, namespace: tracing-query}
     clusterResourceWhitelist:
     - {group: "", kind: Namespace}
   ```
   (Alternative: leave the project at wave 0 and give the Applications `sync-wave: "1"`.)
4. **Push and let the root sync.**
   ```bash
   git add -A && git commit -m "add AppProject tracing-team" && git push
   argocd app get tracing-root --refresh
   ```
5. **Verify.** `argocd app list` shows all three Synced/Healthy, the conditions are gone, and
   `kubectl -n argocd get appproject tracing-team -o jsonpath='{.metadata.annotations}'` shows the tracking id of the root.
