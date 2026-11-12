#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo 'Usage: bash scripts/verify-release.sh <Android emulator device id>' >&2
  exit 2
fi

cd "$(dirname "$0")/.."
innenflow_flutter="${FLUTTER_BIN:-flutter}"

# Flutter 3.44 skips plugin-registry regeneration with --no-pub. Keep these
# operations serial, and let each build mode generate its own registry.
"$innenflow_flutter" analyze --no-fatal-infos
"$innenflow_flutter" test --reporter expanded
ORG_GRADLE_PROJECT_innenflowTestBuild=true "$innenflow_flutter" test \
  integration_test/release_smoke_test.dart -d "$1" --no-uninstall --reporter expanded
"$innenflow_flutter" build appbundle --release
