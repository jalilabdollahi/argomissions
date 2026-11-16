#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=catalog
am_app_exists "$APP" || am_fail "No Application named '$APP' in namespace argocd"

src_path="$(am_app "$APP" '{.spec.source.path}')"
[ "${src_path%/}" = "deploy/catalog" ] \
  || am_fail "Application '$APP' reads path '${src_path:-<repo root>}', which is not where the manifests are in the repo head"
am_ok "Application '$APP' reads deploy/catalog"

am_repo_checkout catalog "$AM_TMP/catalog" || am_fail "Cannot clone the catalog repo"
[ ! -e "$AM_TMP/catalog/k8s" ] || am_fail "The repo head has a k8s/ folder again: the restructure must stay"
[ -f "$AM_TMP/catalog/deploy/catalog/deployment.yaml" ] || am_fail "The repo head no longer has the manifests in deploy/catalog"
am_ok "The restructured layout is untouched in Git"

am_require_app_at_head "$APP" catalog

body="$(am_http http://catalog.catalog catalog)" || am_fail "Service catalog in namespace catalog does not answer"
[ "$body" = "catalog v2.0" ] || am_fail "Service catalog answers '$body'"
am_pass "catalog is live from its new path"
