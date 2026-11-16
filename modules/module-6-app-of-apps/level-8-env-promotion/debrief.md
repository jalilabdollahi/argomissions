# Staging Before Prod

## What broke
The policy lived in people's heads ("staging follows main, prod runs tags"), but the files said something else:
both child Applications in `meterhub-gitops` had `targetRevision: main`. Production therefore deployed every
commit merged to the service repo, including the unfinished metering code in `v1.3.0-rc1`.

## Why Argo CD behaves this way
`targetRevision` is what an Application tracks: a branch (moves with every commit), a tag (a fixed commit unless
someone force-moves it), a commit SHA, or `HEAD`. Argo CD resolves it to a commit on every refresh and syncs that
commit. Nothing in the Application tells Argo CD "this is production": the only thing that separates the
environments is what is written in the child's spec, and in an app-of-apps that spec is a file in the root's
repo, owned by the root. With self-heal on the root, a hand edit of the child (`argocd app set --revision`, the UI
form) is reverted on the next reconcile.

## The fix
Edit the prod child in the environment repo: `targetRevision: v1.2.0`. The prod root syncs the change into the
child Application, the child redeploys that tag. Staging stays on `main`. A promotion is then a one-line pull
request that moves the tag in `envs/prod/` (`v1.2.0` to `v1.3.0` once staging proved it).

## In real life
"Prod tracks main" is the most common accidental promotion policy, usually copied from a staging file. Teams put the
environments in different folders (as here), different repos, or use an ApplicationSet; the review of
`envs/prod/**` is then the release gate. Tags are not immutable in Git: protect them in the Git server, or pin a
commit SHA when you need a hard guarantee.

## Commands worth remembering
```bash
git ls-remote --tags <repo>                 # which releases exist
argocd app get <app>                        # Target revision and the commit it resolved to
argocd app history <app>
argocd app diff <app> --revision <tag>
```

## Common mistakes
* `argocd app set meterhub-prod --revision v1.2.0`: reverted by the root's self-heal, and not reviewed anyway.
* Pinning both environments to the tag: staging then stops testing what comes next.
* Pointing prod at a long-lived `release` branch without protecting it: it is a moving target again.
