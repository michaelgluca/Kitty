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
#
# Some police sites (police.uk, btp.police.uk) sit behind Cloudflare and refuse
# every non-browser client with a 403, whatever the User-Agent. Those entries carry
# a third field, "manual YYYY-MM-DD", recording when a person verified them in a
# real browser. CI does not pretend to check them, but it FAILS once that date is
# more than MANUAL_MAX_AGE_DAYS old, so they cannot quietly rot.
set -euo pipefail
cd "$(dirname "$0")/.."

ALLOWLIST="${1:-docs/url-allowlist.txt}"
MANUAL_MAX_AGE_DAYS=90
[ -f "$ALLOWLIST" ] || { echo "OK: no allowlist yet (no content shipped)."; exit 0; }

# A real browser User-Agent. Some charity and police sites sit behind bot
# protection that refuses curl's default agent.
UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15'
BODY=$(mktemp); trap 'rm -f "$BODY"' EXIT

fail=0; checked=0; manual=0
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  # Trim with sed, not xargs: xargs interprets quotes, so a fragment containing an
  # apostrophe ("Scotland's", "Men's") would crash the whole check.
  trim() { printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'; }
  url=$(trim "${line%%|*}")
  want=""; mode=""
  if [ "$line" != "${line#*|}" ]; then
    rest=${line#*|}
    if [ "$rest" != "${rest#*|}" ]; then
      want=$(trim "${rest%%|*}"); mode=$(trim "${rest#*|}")
    else
      want=$(trim "$rest")
    fi
  fi
  checked=$((checked + 1))

  case "$mode" in
    manual\ *)
      verified=${mode#manual }
      age=$(python3 -c '
import datetime, sys
d = datetime.date.fromisoformat(sys.argv[1])
print((datetime.date.today() - d).days)
' "$verified" 2>/dev/null || echo "bad")
      if [ "$age" = "bad" ]; then
        printf '  FAIL  manual  %s\n        unreadable date "%s" — use manual YYYY-MM-DD\n' "$url" "$verified"; fail=1
      elif [ "$age" -gt "$MANUAL_MAX_AGE_DAYS" ]; then
        printf '  FAIL  stale   %s\n        verified by hand %s days ago (limit %s). Load it in a browser, check the title contains "%s", then update the date.\n' "$url" "$age" "$MANUAL_MAX_AGE_DAYS" "$want"; fail=1
      else
        printf '  hand  %s  (verified in a browser %s, %s days ago)\n' "$url" "$verified" "$age"
        manual=$((manual + 1))
      fi
      continue ;;
    "") ;;
    *) printf '  FAIL  %s  unknown mode "%s"\n' "$url" "$mode"; fail=1; continue ;;
  esac

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

if [ "$fail" -eq 0 ]; then
  auto=$((checked - manual))
  echo "OK: $auto checked automatically — each resolves, without redirect, to the expected page."
  # Said separately rather than folded into the count: these were not checked on
  # this run, and the summary must not imply that they were.
  [ "$manual" -gt 0 ] && echo "    $manual more verified by hand in a browser within the last $MANUAL_MAX_AGE_DAYS days; not checkable from CI."
fi
exit "$fail"
