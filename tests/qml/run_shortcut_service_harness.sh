#!/usr/bin/env bash

set -euo pipefail

project_root=$(realpath -m -- "$(dirname -- "${BASH_SOURCE[0]}")/../..")
cd "$project_root"

mkdir -p build
harness=$(mktemp "$project_root/qml-shortcut-service-test.XXXXXX.qml")
test_root=$(mktemp -d "$project_root/qml-shortcut-service-data.XXXXXX")
trap 'rm -f "$harness"; rm -rf "$test_root"' EXIT

cp tests/qml/shortcut_service_harness.qml "$harness"

timeout 10s env \
  KEYGUIDE_TEST_SHORTCUT_HELPER="$project_root/tests/qml/shortcut_service_helper.py" \
  KEYGUIDE_TEST_SHORTCUT_LOG="$test_root/commands.log" \
  QT_LOGGING_RULES='qt.qpa.services=false' \
  quickshell --no-color -p "$harness" > build/shortcut-service-qml-test.log 2>&1 || {
    cat build/shortcut-service-qml-test.log
    exit 1
  }

cat build/shortcut-service-qml-test.log
rg -q 'KEYGUIDE_SHORTCUT_SERVICE_TEST_PASS' build/shortcut-service-qml-test.log
! rg -q 'KEYGUIDE_SHORTCUT_SERVICE_TEST_FAIL' build/shortcut-service-qml-test.log
test "$(wc -l < "$test_root/commands.log")" -eq 9
