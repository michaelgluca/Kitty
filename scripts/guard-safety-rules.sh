#!/usr/bin/env bash
# Hard code rules from CLAUDE.md that carry real-world consequences.
#
# Each pattern matches the hazard itself, not prose describing it. An earlier version
# flagged the comment that says "never use telprompt:" and the test that asserts the
# hijacked domain is absent. A guard that cries wolf gets switched off, which is
# worse than having no guard.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=_scan.sh
. scripts/_scan.sh

fail=0

# Shipping Swift only. SafetyTesting is test infrastructure whose whole job is
# fixtures, and Tests/ is tests.
shipping=$(git ls-files '*.swift' | grep -v '/Tests/' | grep -v '^Packages/SafetyTesting/' || true)
all=$(git ls-files || true)

scan "force unwrap or force try in shipping code. The 2023 build had 19, several in the emergency send path." \
  "$shipping" 'try!|as!|\)!|\]!' || fail=1

# Only inside a string literal — the URL actually being built, not a comment warning
# against it.
scan 'telprompt: used in a URL. Use tel: so the system call confirmation is always shown.' \
  "$shipping" '"telprompt:' || fail=1

scan "a live emergency number appears as a literal. These belong in SafetyContent, behind an explicit user confirmation." \
  "$shipping" '"(sms:|tel:)?(18000|999|112)"' || fail=1

# emergencysms.org.uk was taken over and now serves a gambling affiliate site;
# emergencysms.net is dead. Both are still linked from UK police and fire pages, so a
# well-meaning edit could reintroduce one. Match only a real URL, so the many places
# that legitimately warn about these domains do not trip the check.
scan "a known-hostile or dead emergency domain is linked. Use relayuk.bt.com." \
  "$all" '://[^"'"'"'[:space:]]*emergencysms\.(org\.uk|net)' || fail=1

[ "$fail" -eq 0 ] && echo "OK: safety code rules pass."
exit "$fail"
