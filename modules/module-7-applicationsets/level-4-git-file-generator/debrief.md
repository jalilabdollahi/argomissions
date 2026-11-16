# Config Field Typo

## What broke
`tenants/globex/config.json` spelled one key `nameSpace`; the template reads `{{.namespace}}`. The
ApplicationSet uses `missingkey=error`, so rendering the globex parameters failed with `map has no entry for key
"namespace"`, and, because generation is all-or-nothing, not a single tenant got an Application.

## Why Argo CD behaves this way
The git *files* generator parses every file matching the pattern (JSON or YAML) and treats its top-level keys as
the parameters of one Application. A Go template by default prints `<no value>` for a missing key; with
`goTemplateOptions: ["missingkey=error"]` (a good practice) it fails instead. When any parameter set fails to
render, the controller aborts that reconcile and reports `ErrorOccurred` on the ApplicationSet. Existing
Applications are left alone, but new ones are not created. The input of the set lives in Git, so that is
where the fix goes; the ApplicationSet then picks it up on its next Git poll (about every 3 minutes unless a
webhook or the `application-set-refresh` annotation triggers it).

## The fix
Correct the key in `tenants/globex/config.json`, commit and push. All three Applications appear.

## In real life
Fleet and tenant files are edited by many people, and a single typo in one of them breaks onboarding for everyone.
Teams add a JSON schema check in CI, keep `missingkey=error` on so that typos fail loudly, and sometimes use
`default` in the template for genuinely optional fields. Note that the error message does not name the file:
you find it by comparing the inputs.

## Commands worth remembering
```bash
kubectl -n argocd get applicationset NAME -o jsonpath='{.status.conditions}' | jq
grep -H KEY tenants/*/config.json
kubectl -n argocd annotate applicationset NAME argocd.argoproj.io/application-set-refresh=true
```

## Common mistakes
- Creating the missing Application by hand: it is not owned by the set, and the set still fails for the others.
- Fixing the file locally but not pushing: the set reads Git, not your workspace.
- Removing `missingkey=error` to "make it work": the Application is then created with an empty namespace.
