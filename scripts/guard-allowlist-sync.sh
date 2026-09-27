#!/usr/bin/env bash
# The URL allowlist must match the content pack exactly.
#
# check-urls.sh only verifies what is on the allowlist. If a URL is added to the
# content but not the allowlist, it ships unchecked — and a hijacked or dead link in
# a safety app is a safety incident. This closes that gap in both directions.
set -euo pipefail
cd "$(dirname "$0")/.."

CONTENT="Packages/SafetyContent/Sources/SafetyContent/Resources/uk-content.json"
ALLOWLIST="docs/url-allowlist.txt"

[ -f "$CONTENT" ] || { echo "OK: no content pack yet."; exit 0; }
[ -f "$ALLOWLIST" ] || { echo "FAIL: $CONTENT exists but $ALLOWLIST does not."; exit 1; }

in_content=$(python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
urls = {s["url"] for s in d.get("services", []) if s.get("url")}
urls |= {r["learnMoreURL"] for r in d.get("emergencyRoutes", []) if r.get("learnMoreURL")}
urls |= {g["url"] for g in d.get("guides", []) if g.get("url")}
for u in sorted(urls): print(u)
' "$CONTENT")

in_allowlist=$(grep -vE '^[[:space:]]*(#|$)' "$ALLOWLIST" | sed 's/[[:space:]]*|.*$//' | sort -u)

missing=$(comm -23 <(printf '%s\n' "$in_content") <(printf '%s\n' "$in_allowlist") || true)
stale=$(comm -13 <(printf '%s\n' "$in_content") <(printf '%s\n' "$in_allowlist") || true)

fail=0
if [ -n "$missing" ]; then
  echo "FAIL: URLs in the content pack but not on the allowlist, so they would ship unchecked:"
  printf '    %s\n' $missing
  fail=1
fi
if [ -n "$stale" ]; then
  echo "FAIL: URLs on the allowlist that no longer appear in the content pack:"
  printf '    %s\n' $stale
  fail=1
fi

[ "$fail" -eq 0 ] && echo "OK: allowlist matches the content pack ($(printf '%s\n' "$in_content" | grep -c .) URLs)."
exit "$fail"
