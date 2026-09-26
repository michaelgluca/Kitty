#!/usr/bin/env bash
# ADR-0007: zero third-party dependencies. Fail the build if one appears.
set -euo pipefail
fail=0

note() { printf '  %s\n' "$1"; }

# Xcode project package references
if git ls-files '*.pbxproj' | xargs -r grep -l 'XCRemoteSwiftPackageReference\|remoteSwiftPackageReferences' 2>/dev/null | grep -q .; then
  echo "FAIL: a remote Swift package reference exists in the Xcode project."
  git ls-files '*.pbxproj' | xargs -r grep -n 'XCRemoteSwiftPackageReference' || true
  fail=1
fi

# Package.swift remote dependencies (local path: deps are fine and expected)
while IFS= read -r manifest; do
  if grep -E '\.package\s*\(\s*(url|id)\s*:' "$manifest" >/dev/null 2>&1; then
    echo "FAIL: remote dependency declared in $manifest"
    grep -nE '\.package\s*\(\s*(url|id)\s*:' "$manifest"
    fail=1
  fi
done < <(git ls-files '*Package.swift')

# Other package managers have no place here
for f in Podfile Cartfile Package.resolved.remote; do
  if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    echo "FAIL: $f is present. This project uses SwiftPM only, with no remote dependencies."
    fail=1
  fi
done

# Vendored source
if git ls-files | grep -Eq '(^|/)(Pods|Carthage|Vendor|ThirdParty)/'; then
  echo "FAIL: vendored third-party source tree found."
  fail=1
fi

[ "$fail" -eq 0 ] && echo "OK: no third-party dependencies (ADR-0007)."
exit "$fail"
