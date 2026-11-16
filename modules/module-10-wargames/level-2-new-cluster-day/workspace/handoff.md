# Handoff from Platform: first day on the new cluster

The old cluster is gone. Argo CD on the new one is installed and empty. `platform/tidewater-gitops` is private;
the read-only machine user for Argo CD already exists:

| What            | Value                                                           |
|-----------------|-----------------------------------------------------------------|
| Gitea user      | `tidewater-reader` (read-only collaborator on the repo)          |
| Password        | `reader-pass-4Kd9`                                               |
| Repo (for Argo) | http://gitea.gitea.svc.cluster.local:3000/platform/tidewater-gitops.git |

Do not use the `player` admin account inside Argo CD, and do not make the repo public.
The runbook is in the repo's README. Changes go through Git; Argo CD reverts hand edits to anything the root manages.
