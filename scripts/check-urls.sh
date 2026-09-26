#!/usr/bin/env bash
# Every outbound URL shipped in the app must be on the reviewed allowlist and must resolve.
# A dead or hijacked link in a safety app is a safety incident: emergencysms.org.uk was
# still linked from UK police and fire pages after it became a gambling affiliate site.
set -euo pipefail

ALLOWLIST="docs/url-allowlist.txt"
[ -f "$ALLOWLIST" ] || { echo "OK: no allowlist yet (no content shipped)."; exit 0; }

fail=0
while IFS= read -r url; do
  case "$url" in ''|\#*) continue ;; esac
  code=$(curl -sS -o /dev/null -w '%{http_code}' -L --max-time 20 "$url" 2>/dev/null || echo "000")
  if [ "$code" = "200" ]; then
    printf '  %s  %s\n' "$code" "$url"
  else
    printf '  %s  %s   <-- FAIL\n' "$code" "$url"
    fail=1
  fi
done < "$ALLOWLIST"

[ "$fail" -eq 0 ] && echo "OK: every allowlisted URL resolves."
exit "$fail"
