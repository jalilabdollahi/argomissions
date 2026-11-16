# Preview Environments

## What broke
The ApplicationSet filtered pull requests on the label `preview`, but the team labels the PRs that deserve an
environment `deploy-preview`. The generator found no matching PR and so generated no Application. The set was
perfectly healthy: no error, no event, just an empty result.

## Why Argo CD behaves this way
The pull request generator calls the provider API (here Gitea, from the applicationset-controller pod) for the open
pull requests of one repository, keeps those that satisfy the `labels` and the optional `filters` (`branchMatch`,
`targetBranchMatch`, `titleMatch`), and returns one parameter set per PR: `number`, `title`, `branch`, `branch_slug`,
`target_branch`, `head_sha`, `head_short_sha`, `labels`. The template turns each into an Application. When a PR is
merged or closed it disappears from the result and the ApplicationSet deletes the Application (and, with the
default resources finalizer, the whole preview environment).

Because every provider is polled, `requeueAfterSeconds` (30 minutes by default, 30 s here) is the latency of
a new PR getting its environment; a webhook on the ApplicationSet endpoint makes it immediate. Using `{{.head_sha}}` as
`targetRevision` pins the environment to the commit that was open; each push to the PR branch changes the parameter and
the Application is updated.

A label filter that matches nothing is not an error: it is how you opt PRs in or out. The price is silent failure when the
label name drifts (a typo, a renamed label, a label that exists in another repository).

## The fix
Make the generator and the team agree on the label (`deploy-preview`). Do not drop the filter to "make it work": that
gives every open PR an environment, which is what the label was meant to prevent. (Adding the label the set
expects to the PR in Gitea is also valid, as long as the closed and the unlabelled PRs stay without a preview.)

## In real life
Preview environments are the classic use of this generator, and they need a cleanup story: namespaces per PR cost
cluster capacity, so teams label to opt in, prune with `automated.prune`, give the namespace a TTL, and keep the
token's scope minimal (read access only; on Gitea `read:issue` is needed to list PRs and labels). Secrets in preview
environments are another well-known foot-gun.

## Commands worth remembering
```bash
argocd appset get pulse-previews
kubectl -n argocd get applicationset pulse-previews -o jsonpath='{.spec.generators[0].pullRequest}'
curl -s http://localhost:3300/api/v1/repos/platform/pulse-web/pulls?state=all | jq '.[] | {number, state, labels: [.labels[].name]}'
kubectl -n argocd logs deploy/argocd-applicationset-controller | tail
```

## Common mistakes
- Removing `labels` and ending up with an environment for every open PR.
- Creating `pulse-pr-1` by hand: it will not follow the PR (not removed when the PR closes) and is not owned by the set.
- Waiting for the 30-minute default requeue after a change of the Gitea side; configure `requeueAfterSeconds` or a webhook.
