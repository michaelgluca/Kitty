#!/usr/bin/env bash
# ADR-0003: SafetyDomain is the platform-neutral core. It must not import a UI or
# Apple-only framework, because that is what keeps the emergency logic testable
# without a device and the later Kotlin port and watchOS companion cheap.
#
# This is a static check rather than a Linux build so it is deterministic and needs
# no toolchain. It is the rule most easily eroded by one convenient import.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=_scan.sh
. scripts/_scan.sh

sources=$(git ls-files 'Packages/SafetyDomain/Sources/*.swift' || true)
if [ -z "$sources" ]; then
  echo "OK: no SafetyDomain sources yet."
  exit 0
fi

forbidden='^[[:space:]]*import[[:space:]]+(SwiftUI|UIKit|AppKit|WatchKit|MapKit|CoreLocation|Contacts|ContactsUI|MessageUI|LocalAuthentication|Security|ActivityKit|WidgetKit|AlarmKit|CloudKit|Combine)\b'

if ! scan "SafetyDomain imported a UI or Apple-only framework. It must stay platform-neutral (ADR-0003). Convert at the SafetyServices boundary instead." "$sources" "$forbidden"; then
  exit 1
fi

echo "OK: SafetyDomain is platform-neutral."
