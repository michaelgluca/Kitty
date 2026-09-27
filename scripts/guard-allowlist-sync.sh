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
urls = set()
def walk(node):
    # Recurse into every dict and list in the pack, rather than listing sections by
    # name, so a future section (rights sources nested under a topic, a refuge note
    # nested under its own key, ...) cannot ship an unchecked link just because this
    # script was never updated for it.
    # Every "url" and "learnMoreURL" anywhere is a link a person can open.
    # "source" strings are the pages an entry was verified against, never shown,
    # and are deliberately not collected.
    if isinstance(node, dict):
        for key, value in node.items():
            if key in ("url", "learnMoreURL") and isinstance(value, str):
                urls.add(value)
            else:
                walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)
walk(d)
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
