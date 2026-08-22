#!/usr/bin/env bash

set -euo pipefail

project_root=$(realpath -m -- "$(dirname -- "${BASH_SOURCE[0]}")/../..")
cd "$project_root"

mkdir -p build
test ! -e "$project_root/Commons" && test ! -L "$project_root/Commons"
test ! -e "$project_root/Ui" && test ! -L "$project_root/Ui"
harness=$(mktemp "$project_root/qml-settings-overlay-test.XXXXXX.qml")
trap 'rm -f "$harness" "$project_root/Commons" "$project_root/Ui"' EXIT

ln -s /usr/share/omarchy/shell/Commons "$project_root/Commons"
ln -s /usr/share/omarchy/shell/Ui "$project_root/Ui"
cp tests/qml/settings_overlay_harness.qml "$harness"

timeout 10s env QT_LOGGING_RULES='qt.qpa.services=false' \
  quickshell --no-color -p "$harness" > build/settings-overlay-qml-test.log 2>&1 || {
    cat build/settings-overlay-qml-test.log
    exit 1
  }

cat build/settings-overlay-qml-test.log
rg -q 'KEYGUIDE_SETTINGS_OVERLAY_TEST_PASS' build/settings-overlay-qml-test.log
! rg -q 'KEYGUIDE_SETTINGS_OVERLAY_TEST_FAIL' build/settings-overlay-qml-test.log
