#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/pure-build-env.sh"
cd "$PURE_PROJECT_ROOT"
"$PURE_PROJECT_ROOT/scripts/pure-build-patch.sh" --offline
flutter build apk --no-pub --release --target-platform android-arm64 --split-per-abi --dart-define=pili.name=0.1.1 --build-name=0.1.1 --build-number=2 "$@"
