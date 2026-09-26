#!/usr/bin/env bash
# Hard code rules from CLAUDE.md that carry real-world consequences.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=_scan.sh
. scripts/_scan.sh

fail=0
swift=$(git ls-files '*.swift' | grep -v '/Tests/' || true)
all=$(git ls-files || true)

scan "force unwrap or force try in shipping code. The 2023 build had 19, several in the emergency send path." \
  "$swift" 'try!|as!|\)!|\]!' || fail=1

scan "telprompt: found. Use tel: so the system call confirmation is always shown." \
  "$swift" 'telprompt:' || fail=1

scan "a live emergency number appears as a literal. These belong in SafetyContent, behind an explicit user confirmation." \
  "$swift" '"(sms:)?(18000|999|112)"' || fail=1

# emergencysms.org.uk was taken over and now serves a gambling affiliate site;
# emergencysms.net is dead. Both are still linked from UK police and fire pages.
scan "a known-hostile or dead emergency domain is referenced. Use relayuk.bt.com." \
  "$(printf '%s\n' "$all" | grep -v '^scripts/guard-safety-rules.sh$' || true)" \
  'emergencysms\.(org\.uk|net)' || fail=1

[ "$fail" -eq 0 ] && echo "OK: safety code rules pass."
exit "$fail"
