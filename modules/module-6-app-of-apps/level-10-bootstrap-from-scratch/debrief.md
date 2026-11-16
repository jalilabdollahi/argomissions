# Rebuild The Platform

## What broke
Nothing, and that was the problem: the cluster was empty and the *entry point* of the whole GitOps setup, the root
Application, only existed in the previous cluster's etcd. The repo described everything else precisely: projects,
children, waves. Bootstrapping means writing the one object that is not in Git yet, and getting its source right.

## Why Argo CD behaves this way
A directory-source Application renders every YAML/JSON file directly in `path`; sub-folders are ignored unless
`directory.recurse` is true, and `directory.exclude` / `directory.include` (globs relative to `path`, so `apps/_archive/*` and not `_archive/*`) narrow the
set. A root is nothing special to Argo CD: it is an Application whose manifests happen to be Applications and
AppProjects, so it must target the namespace they live in (`argocd`), and it must stay out of folders that hold
ordinary workloads (those would be created in `argocd`). Children get their own sync policies; the sync-waves in
the repo order the projects before the children within the root's sync. Argo CD marks every object it creates
with a tracking annotation naming the root, which is how ownership (and pruning) works.

## The fix
`path: platform`, `directory.recurse: true`, `exclude: 'apps/_archive/*'`, destination `argocd` in the in-cluster
server, automated sync with prune and self-heal. After that, one `kubectl apply` rebuilds the platform and the root
keeps it in line with Git.

## In real life
Disaster recovery and new-cluster provisioning end in exactly this step: Terraform or a bootstrap script installs
Argo CD and applies *one* root manifest. Keep that manifest in Git (outside of the folder it reads, or in its own
`bootstrap/` repo), test the bootstrap on a scratch cluster regularly, and exclude retired or experimental
folders explicitly: a recursive root deploys whatever is in the tree, including things nobody wanted any more.

## Commands worth remembering
```bash
argocd app create <root> --repo <url> --path <dir> --directory-recurse --directory-exclude '<glob>' \
  --dest-server https://kubernetes.default.svc --dest-namespace argocd
argocd app manifests <root>        # what the root would apply
argocd app get <root>              # waves and the resource tree
argocd app list -o name
```

## Common mistakes
* Applying each child by hand with `kubectl apply -f platform/apps`: it runs, but there is no owner, so Git
  changes, pruning and rebuilds do not work.
* `recurse: true` without `exclude`: the retired component is deployed again, with a real Deployment and Service.
* Pointing the root at the repo root, or giving it a destination namespace other than `argocd`: the workloads
  land in the wrong namespace, or the Applications are ignored.
