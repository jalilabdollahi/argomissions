# A Token For The Pipeline

## What broke
Nothing in the cluster was broken: the pipeline simply had no credential. The Secret held a template placeholder,
so every call to Argo CD died with `Unauthenticated ... token is malformed`. The tempting shortcut is to paste the
admin password or an admin session token into the Secret. That would work, and it would hand the CI system the
keys to every project, every cluster and every Secret Argo CD knows about.

## Why Argo CD behaves this way
An AppProject can define **roles**. A role is a named set of policies (`p, proj:<project>:<role>, applications,
<action>, <project>/<app>, allow`), and a role can own **JWT tokens**. The token is a signed JWT whose subject
is `proj:settlements:deployer`; Argo CD checks its signature, looks the token id up in the project's role
(`jwtTokens`), and evaluates only that role's policies. Anything not explicitly allowed is denied. Because the
policies live in the project, the blast radius of a leaked token is the project, and revoking it is one command.

Details that bite: the `--object` argument of `argocd proj role add-policy` is relative to the project (`*`,
not `settlements/*`); a token is displayed once; tokens may carry an expiry (`--expires-in`) and should.

## The fix
Create role `deployer`, allow `get` and `sync` on `applications` for the project's apps, create a token and
store it in the Secret the pipeline reads. Verify with `argocd account can-i ... --auth-token` that sync works
and delete does not.

## In real life
CI tokens are the most commonly over-privileged credential around Argo CD: a shared `admin` token in a CI
variable survives people leaving the team, and nobody remembers what it can reach. Project roles give each
pipeline its own, auditable, revocable identity. Teams typically keep the role in the AppProject manifest in Git and
rotate the token on a schedule (create the new one, update the Secret, delete the old one by its `iat`).

## Commands worth remembering
```bash
argocd proj role create PROJECT ROLE
argocd proj role add-policy PROJECT ROLE --action sync --permission allow --object '*'
argocd proj role create-token PROJECT ROLE --expires-in 720h --token-only
argocd proj role list-tokens PROJECT ROLE
argocd proj role delete-token PROJECT ROLE IAT
argocd account can-i sync applications PROJECT/APP --auth-token "$TOKEN"
```

## Common mistakes
- Using the admin password or the admin session token: it works, so nobody notices the pipeline can delete everything.
- Giving the role `*` as the action because "it is only CI": a token that can sync can also delete.
- Printing the token and never storing it (it cannot be shown again), or passing `settlements/*` as `--object`.
