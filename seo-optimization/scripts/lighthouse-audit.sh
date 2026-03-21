#!/usr/bin/env bash
set -euo pipefail
URL="${1:?Usage: lighthouse-audit.sh <URL> [desktop|mobile|both]}"
MODE="${2:-both}"
FLAGS="--headless --no-sandbox --disable-gpu"
run_audit() {
  local p="$1" o="$2" f="--output=json --output-path=$o --chrome-flags=\"$FLAGS\""
  [ "$p" = "desktop" ] && f="$f --preset=desktop"
  echo "Running $p audit..."
  eval npx lighthouse "$URL" $f 2>/dev/null
  jq -r '.categories | to_entries[] | "  \(.key): \(.value.score * 100)%"' "$o"
}
case "$MODE" in
  desktop) run_audit "desktop" "lighthouse-desktop.json" ;;
  mobile) run_audit "mobile" "lighthouse-mobile.json" ;;
  both) run_audit "desktop" "lighthouse-desktop.json"; run_audit "mobile" "lighthouse-mobile.json" ;;
esac
