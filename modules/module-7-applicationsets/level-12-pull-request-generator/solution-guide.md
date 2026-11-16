# Walkthrough — Preview Environments

1. **See what is asked and what exists.**
   ```bash
   kubectl -n argocd get applicationset pulse-previews -o jsonpath='{.spec.generators[0].pullRequest}{"\n"}'
   argocd appset get pulse-previews                 # conditions are healthy, zero Applications
   curl -s http://localhost:3300/api/v1/repos/platform/pulse-web/pulls?state=all | jq '[.[] | {number, state, head: .head.ref, labels: [.labels[].name]}]'
   ```
   (Gitea UI: the repo's *Pull Requests* tab, filter by label.) PR #1 is open with the label `deploy-preview`, PR #2 is
   labelled but closed, PR #3 is open without a label.
2. **Understand.** The generator only returns open PRs that carry *all* the labels listed in `labels`. The
   ApplicationSet asks for `preview`; the label the team uses is `deploy-preview`. Nothing matches, and nothing is wrong
   from the controller's point of view, so there is no error.
3. **Fix the label in the ApplicationSet** (`pulse-previews-appset.yaml`):
   ```yaml
         labels:
         - deploy-preview
   ```
   `kubectl apply -f pulse-previews-appset.yaml`.
4. **Watch the preview appear.**
   ```bash
   argocd app list                                    # pulse-pr-1 only
   kubectl get ns | grep pulse-pr                     # pulse-pr-1; nothing for the closed or the unlabelled PR
   kubectl -n pulse-pr-1 run t --rm -i --image=curlimages/curl:8.10.1 --restart=Never -- curl -s pulse-web
   # pulse-web checkout-redesign
   ```
5. Run `check` in the game. (Closing the PR in Gitea would make the Application, and with `prune`, its
   resources disappear at the next generator run.)
