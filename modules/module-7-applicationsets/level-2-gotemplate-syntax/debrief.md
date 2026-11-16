# Template Mismatch

## What broke
The ApplicationSet had `goTemplate: true` but its template was written for the default engine:
`{{path.basename}}` instead of `{{.path.basename}}`. The controller could not even parse the template, so it
generated nothing: `failed to parse template {{path.basename}}: template: base:1: function "path" not defined`.

## Why Argo CD behaves this way
ApplicationSets have two template engines. The default one (fasttemplate) replaces `{{key}}` and
`{{path.basename}}` with the generator's flattened parameters. With `goTemplate: true` the real Go
`text/template` engine is used: parameters are a nested object, you read them with a leading dot
(`{{.path.basename}}`), you get conditionals, `range` and the Sprig functions, and `goTemplateOptions:
["missingkey=error"]` turns a missing key into an error instead of a silent `<no value>`. The two syntaxes are
not compatible. A Go template that starts with `{{path...` makes the parser look for a function called `path`.
Because the error appears while rendering the very first parameter set, the whole set generates zero
Applications.

## The fix
Use `{{.path.basename}}` for the name and `{{.path.path}}` for the source path (or turn `goTemplate` off and
keep the old placeholders). Every placeholder in the whole template must use the same syntax.

## In real life
Teams copy ApplicationSet snippets from blog posts and the docs, which mix both syntaxes; the failure is
usually a Degraded set with an empty application list and no Application-level error to look at. Go templates
are worth it as soon as you need defaults, conditions or string functions; `missingkey=error` is worth turning
on early because typos fail loudly.

## Commands worth remembering
```bash
kubectl -n argocd get applicationset NAME -o jsonpath='{.status.conditions}' | jq
argocd appset get NAME
kubectl -n argocd logs deploy/argocd-applicationset-controller | grep NAME
```

## Common mistakes
- Fixing the Application name but forgetting `path:` or the destination: the same parse error remains.
- Creating the three Applications by hand: they run, but the ApplicationSet still generates nothing and owns nothing.
- Writing `{{ .path.basename }}` for some fields and `{{path.basename}}` for others in one template.
