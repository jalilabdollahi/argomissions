# Walkthrough — Staging Before Prod

1. **Compare the environments.**
   ```bash
   argocd app get meterhub-prod
   argocd app get meterhub-staging
   ```
   Both show `Target: main` and the same commit: production and staging are identical, and production moved to the
   unreleased `v1.3.0-rc1` on its own as soon as it was merged.
2. **Find the release.** `git ls-remote --tags http://localhost:3300/platform/meterhub-service.git` lists `v1.2.0`.
3. **Find where the child is defined.** `argocd app get meterhub-env-prod` shows the child comes from
   `envs/prod/meterhub.yaml` in `meterhub-gitops` (automated, self-heal on). Pinning with `argocd app set` or by editing
   the child in the UI would be reverted within seconds, because Git is the source of truth for the child's spec.
4. **Pin production in Git.**
   ```bash
   cd meterhub-gitops
   sed -i 's/targetRevision: main/targetRevision: v1.2.0/' envs/prod/meterhub.yaml
   git commit -am "prod: pin meterhub to v1.2.0" && git push
   ```
5. **Watch it roll.** `argocd app get meterhub-env-prod --refresh`: the root updates the child, the child syncs
   the tag. `argocd app get meterhub-prod` now shows `Target: v1.2.0`.
6. **Verify.**
   ```bash
   kubectl -n meterhub-prod run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s meterhub
   ```
   prints `meterhub v1.2.0`; staging still prints `meterhub v1.3.0-rc1`. Run `check`.
