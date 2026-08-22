#!/usr/bin/env bash

set -euo pipefail

project_root=$(realpath -m -- "$(dirname -- "${BASH_SOURCE[0]}")/../..")
cd "$project_root"

mkdir -p build
harness=$(mktemp "$project_root/qml-settings-service-test.XXXXXX.qml")
data_home=$(mktemp -d "$project_root/qml-settings-service-data.XXXXXX")
trap 'rm -f "$harness"; rm -rf "$data_home"' EXIT

cp tests/qml/settings_service_harness.qml "$harness"
settings_path="$data_home/omarchy-keyguide/settings.json"
captured_marker="$data_home/watcher-captured"
release_read_marker="$data_home/release-read"
write_done_marker="$data_home/write-done"
release_patch_marker="$data_home/release-patch"

env \
  PYTHONPATH="$project_root/src/backend" \
  XDG_DATA_HOME="$data_home" \
  PYTHONDONTWRITEBYTECODE=1 \
  python3 -m keyguide_backend settings patch '{"opacity": 0.94}' >/dev/null

timeout 10s env \
  KEYGUIDE_TEST_DATA_HOME="$data_home" \
  KEYGUIDE_TEST_PYTHONPATH="$project_root/src/backend" \
  KEYGUIDE_TEST_SETTINGS_PATH="$settings_path" \
  KEYGUIDE_TEST_RACE_HELPER="$project_root/tests/qml/settings_watcher_race.py" \
  KEYGUIDE_TEST_CATALOG_HELPER="$project_root/tests/qml/catalog_service_helper.py" \
  KEYGUIDE_TEST_CAPTURED_MARKER="$captured_marker" \
  KEYGUIDE_TEST_RELEASE_READ_MARKER="$release_read_marker" \
  KEYGUIDE_TEST_WRITE_DONE_MARKER="$write_done_marker" \
  KEYGUIDE_TEST_RELEASE_PATCH_MARKER="$release_patch_marker" \
  QT_LOGGING_RULES='qt.qpa.services=false' \
  quickshell --no-color -p "$harness" > build/settings-service-qml-test.log 2>&1 || {
    cat build/settings-service-qml-test.log
    exit 1
  }

cat build/settings-service-qml-test.log
rg -q 'KEYGUIDE_SETTINGS_SERVICE_TEST_PASS' build/settings-service-qml-test.log
! rg -q 'KEYGUIDE_SETTINGS_SERVICE_TEST_FAIL' build/settings-service-qml-test.log
