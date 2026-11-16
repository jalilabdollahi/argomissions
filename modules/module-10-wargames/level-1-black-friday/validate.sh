#!/bin/bash
set -uo pipefail
source "$AM_LIB"

# A war game reports every symptom it finds, not just the first one.
bad=0
bad() { echo "❌ $1"; bad=$((bad + 1)); }

PROJECT=blackfriday
CART=bf-cart
PROMO=bf-promo

# ── the freeze ──────────────────────────────────────────────────────────────
kubectl -n argocd get appproject "$PROJECT" -o json >"$AM_TMP/project.json" 2>/dev/null || { echo "❌ AppProject '$PROJECT' does not exist"; exit 1; }
deny="$(jq '[.spec.syncWindows[]? | select(.kind=="deny")] | length' "$AM_TMP/project.json")"
if [ "${deny:-0}" -lt 1 ]; then
  bad "Project $PROJECT has no deny sync window any more: nothing holds back an unreviewed deploy during the freeze"
else
  am_ok "Project $PROJECT still has a deny sync window"
fi
if am_app_exists "$CART"; then
  am_argocd app get "$CART" >"$AM_TMP/get-cart.txt" 2>&1
  if grep -q "SyncWindow: *Sync Denied" "$AM_TMP/get-cart.txt"; then
    bad "A manual sync of '$CART' is still blocked by a sync window: the next urgent fix would hit the same wall"
  else
    am_ok "A manual sync of '$CART' is not blocked"
  fi
fi

# ── the project's destinations ──────────────────────────────────────────────
if jq -e '[.spec.destinations[]? | select((.namespace // "") == "*" or (.namespace // "") == "")] | length > 0' "$AM_TMP/project.json" >/dev/null; then
  bad "Project $PROJECT allows every namespace: it is no longer a boundary for the storefront"
fi
if jq -e '[.spec.clusterResourceWhitelist[]? | select((.kind // "") == "*" or (.group // "") == "*")] | length > 0' "$AM_TMP/project.json" >/dev/null; then
  bad "Project $PROJECT may create any kind of cluster-wide object: that is far more than the storefront needs"
fi
if ! am_app_exists "$PROMO"; then
  bad "Application '$PROMO' does not exist"
else
  [ "$(am_app "$PROMO" '{.spec.project}')" = "$PROJECT" ] || bad "Application '$PROMO' left project $PROJECT"
  [ "$(am_app "$PROMO" '{.spec.destination.namespace}')" = bf-promo ] || bad "Application '$PROMO' no longer targets namespace bf-promo"
  if am_app_conditions "$PROMO" | grep -q "InvalidSpecError"; then
    bad "Application '$PROMO' is Unknown: $(am_app_conditions "$PROMO" | grep InvalidSpecError | head -1 | cut -c1-170)"
  fi
fi

# ── the autoscaler and the cart ─────────────────────────────────────────────
[ "$(kubectl -n bf-scaler get deploy load-scaler -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)" = 1 ] \
  && am_ok "the autoscaler keeps running" \
  || bad "The platform's autoscaler (load-scaler in namespace bf-scaler) is not running: the fight was removed, not resolved"

if am_app_exists "$CART"; then
  app_json="$(am_app_json "$CART")"
  [ "$(echo "$app_json" | jq -r '.spec.syncPolicy.automated.selfHeal // false')" = true ] \
    || bad "Application '$CART' no longer heals drift: the team wants self-heal to stay on for everything else"
  am_repo_checkout bf-cart "$AM_TMP/cart" || bad "cannot clone the bf-cart repo"
  dep="$(am_yaml_docs_json "$AM_TMP/cart/deploy" | jq -c '[.[] | select(.kind=="Deployment" and .metadata.name=="bf-cart")][0]')"
  git_replicas="$(echo "$dep" | jq -r '.spec.replicas // "unset"')"
  if [ "$git_replicas" != unset ]; then
    ignores="$(echo "$app_json" | jq '[.spec.ignoreDifferences[]?
        | select((.group // "apps") == "apps" and (.kind // "Deployment") == "Deployment" and (.name // "bf-cart") == "bf-cart")
        | select(((.jsonPointers // []) | index("/spec/replicas")) != null
              or ((.jqPathExpressions // []) | map(gsub("\\s";"")) | index(".spec.replicas")) != null
              or ((.managedFieldsManagers // []) | index("load-scaler")) != null)] | length')"
    if [ "$ignores" -lt 1 ]; then
      bad "Git pins bf-cart to $git_replicas replicas and the Application has no rule about who owns that field: Argo CD and the autoscaler will keep overwriting each other"
    elif ! echo "$app_json" | jq -e '(.spec.syncPolicy.syncOptions // []) | index("RespectIgnoreDifferences=true")' >/dev/null; then
      bad "The Application ignores the replica difference when comparing, but any sync would still push Git's $git_replicas replicas over the autoscaler's"
    fi
  fi
  sync="$(am_app_sync "$CART")"; rev="$(am_app_rev "$CART")"; head="$(am_repo_head bf-cart)"
  if [ "$sync" != Synced ]; then
    bad "Application '$CART' is ${sync:-Unknown} (the Black Friday release v9.0 is not what is running, or replicas keep drifting)"
  elif [ "$rev" != "$head" ]; then
    bad "Application '$CART' is synced to ${rev:0:7}, but bf-cart/main is at ${head:0:7}"
  elif [ "$(am_app_health "$CART")" != Healthy ]; then
    bad "Application '$CART' health is $(am_app_health "$CART")"
  else
    am_ok "Application '$CART' is Synced and Healthy at bf-cart@${head:0:7}"
  fi
  g1="$(am_jsonpath deploy/bf-cart '{.metadata.generation}' bf-cart)"
  sleep 12
  g2="$(am_jsonpath deploy/bf-cart '{.metadata.generation}' bf-cart)"
  [ "$g1" = "$g2" ] || bad "The bf-cart Deployment spec is still being rewritten (generation $g1 -> $g2 in 12 s): Argo CD and the autoscaler are still fighting"
  [ "$(am_jsonpath deploy/bf-cart '{.spec.replicas}' bf-cart)" = 6 ] || bad "Deployment bf-cart does not hold the autoscaler's 6 replicas"
  if [ "$(am_ready_replicas bf-cart bf-cart)" -ge 1 ]; then
    body="$(am_http http://bf-cart.bf-cart bf-cart 2)" || body="(no answer)"
    [ "$body" = "bf-cart v9.0 black-friday" ] || bad "Service bf-cart answers '$body' (the approved release is v9.0 black-friday)"
  else
    bad "Deployment bf-cart has no ready pods"
  fi
else
  bad "Application '$CART' does not exist"
fi

# ── the promo banner ────────────────────────────────────────────────────────
if am_app_exists "$PROMO"; then
  sync="$(am_app_sync "$PROMO")"; rev="$(am_app_rev "$PROMO")"; head="$(am_repo_head bf-promo)"
  if [ "$sync" = Synced ] && [ "$rev" = "$head" ] && [ "$(am_app_health "$PROMO")" = Healthy ]; then
    am_ok "Application '$PROMO' is Synced and Healthy at bf-promo@${head:0:7}"
    body="$(am_http http://bf-promo.bf-promo bf-promo 2)" || body="(no answer)"
    [ "$body" = "bf-promo v4.0 sale-banner" ] || bad "Service bf-promo answers '$body'"
  else
    bad "Application '$PROMO' is ${sync:-Unknown}/$(am_app_health "$PROMO"): the sale banner is not live"
  fi
fi

[ "$bad" -eq 0 ] || { echo "❌ $bad problem(s) left on the storefront"; exit 1; }
am_pass "Black Friday is go: release v9.0 and the banner are live, the freeze is still on, the autoscaler is free"
