# Custody platform - audit notes

Accounts in Argo CD (local):
| account    | who                         | password           | should be able to |
|------------|-----------------------------|--------------------|-------------------|
| kim        | platform lead               | kim-pw-5521        | everything        |
| sam        | custody developer           | sam-pw-5521        | look, not touch   |
| deploy-bot | the release pipeline (CI)   | deploy-bot-pw-5521 | get + sync the apps of project `custody`, nothing else |

Gitea machine user for Argo CD: `argo-reader` / `reader-pass-8Rt3` (read-only). Gitea admin (`player`) is for humans.
Repos: platform/custody-api (service + DB secret + RBAC), platform/custody-batch (nightly batch). Both private.
Argo CD reaches Gitea at http://gitea.gitea.svc.cluster.local:3000
