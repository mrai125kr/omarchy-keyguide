#!/bin/bash
set -euo pipefail

project_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$project_root"

fake_bin=$(mktemp -d "$project_root/qml-session-lock-bin.XXXXXX")
state_file=$(mktemp "$project_root/qml-session-lock-state.XXXXXX")
harness=$(mktemp "$project_root/qml-session-lock-test.XXXXXX.qml")
trap 'rm -rf "$fake_bin"; rm -f "$state_file" "$harness"' EXIT

printf '%s' unknown > "$state_file"
ln -s "$project_root/tests/qml/session_lock_probe.sh" \
  "$fake_bin/omarchy-hyprland-session-locked"
cp tests/qml/session_lock_fallback_harness.qml "$harness"

timeout 12s env \
  PATH="$fake_bin:$PATH" \
  KEYGUIDE_TEST_LOCK_STATE="$state_file" \
  QT_QPA_PLATFORM=offscreen \
  QT_LOGGING_RULES='qt.qpa.services=false' \
  quickshell --no-color -p "$harness" \
  > build/session-lock-fallback-qml-test.log 2>&1 || {
    cat build/session-lock-fallback-qml-test.log
    exit 1
  }

cat build/session-lock-fallback-qml-test.log
rg -q 'KEYGUIDE_SESSION_LOCK_FALLBACK_TEST_PASS' \
  build/session-lock-fallback-qml-test.log
! rg -q 'KEYGUIDE_SESSION_LOCK_FALLBACK_TEST_FAIL' \
  build/session-lock-fallback-qml-test.log
