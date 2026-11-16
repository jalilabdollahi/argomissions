# Walkthrough — Rebuild The Platform

1. **Read the repo.**
   ```bash
   cat lighthouse-gitops/README.md
   find lighthouse-gitops -name '*.yaml' | sort
   ```
   Projects in `platform/projects/`, children in `platform/apps/`, one retired child in `platform/apps/_archive/`,
   workloads in `workloads/` (to be deployed by the children, not by the root).
2. **Design the root.** It is an Application whose source is the folder `platform` of the repo:
   * the files are two levels deep, so `directory.recurse: true`;
   * `_archive/` must not be picked up: `directory.exclude: 'apps/_archive/*'` (the glob is relative to `path`, so it is `apps/_archive/*`, not `_archive/*`);
   * it creates Applications and AppProjects, which live in namespace `argocd`: destination namespace `argocd`;
   * repoURL is the in-cluster Gitea URL `http://gitea.gitea.svc.cluster.local:3000/platform/lighthouse-gitops.git`.
3. **Write it** (`lighthouse-bootstrap.yaml`):
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: lighthouse-bootstrap
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: http://gitea.gitea.svc.cluster.local:3000/platform/lighthouse-gitops.git
       targetRevision: main
       path: platform
       directory:
         recurse: true
         exclude: 'apps/_archive/*'
     destination:
       server: https://kubernetes.default.svc
       namespace: argocd
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
   ```
   ```bash
   kubectl apply -f lighthouse-bootstrap.yaml
   ```
4. **Watch the bring-up.** `argocd app get lighthouse-bootstrap` lists the two AppProjects (wave -1), `lighthouse-cache`
   (wave 0), then `lighthouse-gateway` and `lighthouse-catalog` (wave 1). Each child syncs itself.
5. **Verify.** `argocd app list` shows root + 3 children Synced and Healthy, no `lighthouse-billing-legacy`;
   each Service answers its version. Run `check`.
   (A good habit for a real cluster: commit `lighthouse-bootstrap.yaml` to the repo, in a folder the root does not read.)
