#!/bin/bash
# Correct too: the revision becomes a parameter of the list elements, so the template itself produces it.
set -euo pipefail
source "$AM_LIB"

kubectl -n argocd patch applicationset feedhub --type json -p '[
  {"op":"add","path":"/spec/generators/0/list/elements/0/revision","value":"main"},
  {"op":"add","path":"/spec/generators/0/list/elements/1/revision","value":"main"},
  {"op":"add","path":"/spec/generators/0/list/elements/2/revision","value":"hotfix-1.8.1"},
  {"op":"replace","path":"/spec/template/spec/source/targetRevision","value":"{{.revision}}"}]'
on_hotfix() { [ "$(am_app feedhub-prod '{.spec.source.targetRevision}')" = hotfix-1.8.1 ]; }
am_wait 60 on_hotfix
am_wait_app feedhub-prod sync=Synced health=Healthy --timeout 150
