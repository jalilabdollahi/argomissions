# Audit Findings

## What broke
Nothing was down, which is the problem: the platform worked because of four shortcuts. `policy.default: role:admin`
made every account an administrator, including the developer who deleted an Application and the pipeline that
only deployed because of it. A database password lived in Git. Argo CD authenticated to Git as a human admin, once
per repository. And the project `custody` could create any cluster-scoped object.

## Why Argo CD behaves this way
Authorisation in Argo CD is `argocd-rbac-cm`: `policy.default` is the role of anybody who is authenticated but not
mentioned in `policy.csv`, so a generous default is a hidden grant to every present and future account.
Fixing it removes a permission something may rely on, so the pipeline needs its own narrow role first.
Argo CD renders what Git contains; it has no idea a Secret is "sensitive". With `prune`, deleting the manifest from
Git deletes the live object, and the commit that held the value stays in history: removing it is clean-up, rotating
it is the fix. Repository credentials come in two forms, `repository` secrets (per URL) and `repo-creds` templates
(per URL prefix); a per-repo secret always wins over a template, so both have to be dealt with. A project's
`clusterResourceWhitelist` is the allow-list of cluster-scoped kinds its Applications may create; `*/*` turns every
Application into a potential cluster admin. Tightening it too far blocks the next sync, so it has to list what
the repositories really contain.

## The fix
an empty `policy.default` plus explicit roles for `kim` (admin), `sam` (read-only) and `deploy-bot` (get and sync on `custody/*`); one `repo-creds` template for
`argo-reader` (with read access to both repos in Gitea); a whitelist of `ClusterRole` and `ClusterRoleBinding`;
the Secret manifest removed from Git and the Secret re-created out of band with a new password.

## In real life
Audits find exactly this, and fixes collide: tightening RBAC breaks the pipeline at 17:55 on a Friday, removing the
secret from Git prunes it and the next pod restart fails with `CreateContainerConfigError`, switching credentials
exposes a repo the machine user never had access to. Sequence the work, test each identity, and keep a note of
what depended on the old behaviour. Treat any secret that was ever in a Git history as public.

## Commands worth remembering
```bash
argocd account can-i sync applications 'custody/*'        # as the account, with its own --config
argocd account list ; argocd proj get custody ; argocd repocreds list ; argocd repo list
kubectl -n argocd get cm argocd-rbac-cm -o yaml
git log -p --all -S'password' -- deploy/                  # where did it enter the history?
```

## Common mistakes
- Setting the default to read-only and walking away: the release pipeline fails at the next deploy, or, once it has a role, still reads everything the default role allows.
- Re-encoding the Secret as base64 or encrypting nothing: it is still the same password in Git.
- Deleting the repository secrets "because they are insecure" without a replacement: every private repo goes dark.

## Argo CD 2.x vs 3.x
In 3.x `update` and `delete` policies no longer cascade to sub-resources and `logs` is enforced, so a policy
written for 2.x may grant less (or, via a generous default, more) than you think. Read-only roles keep working.
