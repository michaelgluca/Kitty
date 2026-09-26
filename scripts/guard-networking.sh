#!/usr/bin/env bash
# Constraint 1: nothing may transmit to a developer-controlled endpoint.
# MapKit is allowed; it is Apple's, and Apple is not us. See ADR-0002.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=_scan.sh
. scripts/_scan.sh

fail=0
swift=$(git ls-files '*.swift' | grep -v '/Tests/' || true)
configs=$(git ls-files '*.plist' '*.pbxproj' '*.xcconfig' || true)

scan "networking symbol found. There is no backend (ADR-0002) and no direct network layer is permitted." \
  "$swift" 'URLSession|URLRequest|dataTask|downloadTask|uploadTask|NWConnection|WKWebView|NSURLConnection' || fail=1

scan "a framework whose purpose is developer-side data collection was imported (ADR-0007)." \
  "$swift" '^[[:space:]]*import[[:space:]]+(CloudKit|MetricKit|CrashReportExtension)\b' || fail=1

scan "App Transport Security exception found." \
  "$configs" 'NSAllowsArbitraryLoads' || fail=1

[ "$fail" -eq 0 ] && echo "OK: no networking layer, no collection frameworks, no ATS exceptions."
exit "$fail"
