# Handoff from Platform

Argo CD needs read access to `platform/vault-ui` now that the repo is private.

| What            | Value                                               |
|-----------------|-----------------------------------------------------|
| Gitea user      | `argo-reader` (read-only collaborator on the repo)  |
| Password        | `reader-pass-7Q2x`                                  |
| Repo (for Argo) | http://gitea.gitea.svc.cluster.local:3000/platform/vault-ui.git |

Do not use the `player` admin account for this, and do not make the repo public.
