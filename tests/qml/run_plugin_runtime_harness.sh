#!/usr/bin/env bash

set -euo pipefail

repository_root=$(pwd -P)
harness=$(mktemp ./qml-plugin-runtime-test.XXXXXX.qml)
trap 'rm -f "$harness"' EXIT
cp tests/qml/plugin_runtime_harness.qml "$harness"

timeout 10s env \
  KEYGUIDE_TEST_REPOSITORY_ROOT="$repository_root" \
  QT_LOGGING_RULES='qt.qpa.services=false' \
  quickshell --no-color -p "$harness" \
  > build/plugin-runtime-qml-test.log 2>&1 || {
    cat build/plugin-runtime-qml-test.log
    exit 1
  }

cat build/plugin-runtime-qml-test.log
rg -q 'KEYGUIDE_PLUGIN_RUNTIME_TEST_PASS' build/plugin-runtime-qml-test.log
! rg -q 'KEYGUIDE_PLUGIN_RUNTIME_TEST_FAIL' build/plugin-runtime-qml-test.log
