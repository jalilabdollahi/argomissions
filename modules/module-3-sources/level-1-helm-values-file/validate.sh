#!/bin/bash
set -uo pipefail
source "$AM_LIB"

APP=weather-api
am_app_exists "$APP" || am_fail "Application '$APP' does not exist (it must stay, not be deleted)"

am_require_app_at_head "$APP" weather-api

[ "$(am_ready_replicas weather-api weather)" -ge 2 ] \
  || am_fail "Deployment weather/weather-api has fewer than 2 ready pods (production should run 2)"
am_ok "Deployment weather-api runs the production replica count"

body="$(am_http http://weather-api.weather weather)" || am_fail "Service weather-api in namespace weather does not answer"
[ "$body" = "weather-api prod 3.2" ] \
  || am_fail "Service weather-api answers '$body' - that is not the production configuration"
am_pass "weather-api is Synced and serving the production values"
