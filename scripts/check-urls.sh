#!/usr/bin/env bash
# Every URL the app can send a user to must still be the RIGHT page, not merely a
# page. Three checks per URL, each prompted by a real failure:
#
#   1. HTTP 200.
#   2. No redirect to a different address. chat.womensaid.org.uk passed a naive
#      checker by redirecting elsewhere; the chat had closed months earlier.
#   3. The page title contains the expected fragment. emergencysms.org.uk returns
#      200 with the title "Best Casinos Not on Gamstop", and a wrong Apple article
#      ID returns 200 on an unrelated article.
set -euo pipefail
cd "$(dirname "$0")/.."

ALLOWLIST="${1:-docs/url-allowlist.txt}"
[ -f "$ALLOWLIST" ] || { echo "OK: no allowlist yet (no content shipped)."; exit 0; }

# A real browser User-Agent. Some charity and police sites sit behind bot
# protection that refuses curl's default agent.
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15'
BODY=$(mktemp); trap 'rm -f "$BODY"' EXIT

fail=0; checked=0
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  # Trim with sed, not xargs: xargs interprets quotes, so a fragment containing an
  # apostrophe ("Scotland's", "Men's") would crash the whole check.
  trim() { printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
  url=$(trim "${line%%|*}")
  if [ "$line" != "${line#*|}" ]; then want=$(trim "${line#*|}"); else want=""; fi
  checked=$((checked + 1))

  meta=$(curl -sS -L --max-time 25 -A "$UA" -o "$BODY" -w '%{http_code} %{url_effective}' "$url" 2>/dev/null || echo "000 -")
  code=${meta%% *}; final=${meta#* }

  if [ "$code" != "200" ]; then
    hint=""
    [ "$code" = "403" ] && hint="  (often bot protection: load it in a browser before assuming it is dead)"
    printf '  FAIL  %s  %s%s\n' "$code" "$url" "$hint"; fail=1; continue
  fi

  if [ "${final%/}" != "${url%/}" ]; then
    printf '  FAIL  redirect  %s\n        -> %s\n        Check the destination is still the same service, then make the content and allowlist use it directly.\n' "$url" "$final"
    fail=1; continue
  fi

  if [ -n "$want" ]; then
    title=$(python3 -c '
import html, re, sys
text = open(sys.argv[1], errors="ignore").read()
m = re.search(r"<title[^>]*>(.*?)</title>", text, re.S | re.I)
print(html.unescape(" ".join(m.group(1).split())) if m else "")
' "$BODY")
    if ! printf '%s' "$title" | grep -qiF -- "$want"; then
      printf '  FAIL  title  %s\n        expected to contain: %s\n        actual title:        %s\n        The page may have moved, been replaced, or been taken over.\n' "$url" "$want" "${title:-(none)}"
      fail=1; continue
    fi
  fi
  printf '  ok    %s\n' "$url"
done < "$ALLOWLIST"

[ "$fail" -eq 0 ] && echo "OK: all $checked URLs resolve, without redirect, to the expected page."
exit "$fail"
