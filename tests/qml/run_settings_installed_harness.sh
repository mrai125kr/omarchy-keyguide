#!/usr/bin/env bash

set -euo pipefail

project_root=$(realpath -m -- "$(dirname -- "${BASH_SOURCE[0]}")/../..")
cd "$project_root"

mkdir -p build
test ! -e "$project_root/Commons" && test ! -L "$project_root/Commons"
test ! -e "$project_root/Ui" && test ! -L "$project_root/Ui"
install_root=$(mktemp -d "$project_root/qml-settings-installed-install.XXXXXX")
harness=$(mktemp "$project_root/qml-settings-installed-test.XXXXXX.qml")
trap 'rm -rf "$install_root"; rm -f "$harness" "$project_root/Commons" "$project_root/Ui"' EXIT

make -s build
PREFIX_ROOT="$install_root" bash scripts/install.sh
installed_home="$install_root$HOME"
plugin_root="$installed_home/.config/omarchy/plugins/mrai.keyguide"

python3 - "$project_root" "$installed_home" <<'PY'
from pathlib import Path
import sys

project_root = Path(sys.argv[1])
installed_home = Path(sys.argv[2])
install_map = (
    ("build/keyguide-observer", ".local/lib/omarchy-keyguide/bin/keyguide-observer"),
    (
        "src/backend/keyguide_backend/__init__.py",
        ".local/lib/omarchy-keyguide/keyguide_backend/__init__.py",
    ),
    (
        "src/backend/keyguide_backend/__main__.py",
        ".local/lib/omarchy-keyguide/keyguide_backend/__main__.py",
    ),
    (
        "src/backend/keyguide_backend/bindings.py",
        ".local/lib/omarchy-keyguide/keyguide_backend/bindings.py",
    ),
    (
        "src/backend/keyguide_backend/catalog.py",
        ".local/lib/omarchy-keyguide/keyguide_backend/catalog.py",
    ),
    (
        "src/backend/keyguide_backend/compat.py",
        ".local/lib/omarchy-keyguide/keyguide_backend/compat.py",
    ),
    (
        "src/backend/keyguide_backend/groups.py",
        ".local/lib/omarchy-keyguide/keyguide_backend/groups.py",
    ),
    (
        "src/backend/keyguide_backend/layout.py",
        ".local/lib/omarchy-keyguide/keyguide_backend/layout.py",
    ),
    (
        "src/backend/keyguide_backend/presentation.py",
        ".local/lib/omarchy-keyguide/keyguide_backend/presentation.py",
    ),
    (
        "src/backend/keyguide_backend/settings.py",
        ".local/lib/omarchy-keyguide/keyguide_backend/settings.py",
    ),
    ("src/plugin/manifest.json", ".config/omarchy/plugins/mrai.keyguide/manifest.json"),
    ("src/plugin/ActionSearchModel.js", ".config/omarchy/plugins/mrai.keyguide/ActionSearchModel.js"),
    ("src/plugin/BarWidget.qml", ".config/omarchy/plugins/mrai.keyguide/BarWidget.qml"),
    ("src/plugin/Hud.qml", ".config/omarchy/plugins/mrai.keyguide/Hud.qml"),
    ("src/plugin/HudModel.js", ".config/omarchy/plugins/mrai.keyguide/HudModel.js"),
    ("src/plugin/I18n.js", ".config/omarchy/plugins/mrai.keyguide/I18n.js"),
    ("src/plugin/Service.qml", ".config/omarchy/plugins/mrai.keyguide/Service.qml"),
    ("src/plugin/Settings.qml", ".config/omarchy/plugins/mrai.keyguide/Settings.qml"),
    ("src/plugin/VisibilityModel.js", ".config/omarchy/plugins/mrai.keyguide/VisibilityModel.js"),
    (
        "src/plugin/components/ActionSearch.qml",
        ".config/omarchy/plugins/mrai.keyguide/components/ActionSearch.qml",
    ),
    (
        "src/plugin/components/BindingRow.qml",
        ".config/omarchy/plugins/mrai.keyguide/components/BindingRow.qml",
    ),
    (
        "src/plugin/components/HudPreview.qml",
        ".config/omarchy/plugins/mrai.keyguide/components/HudPreview.qml",
    ),
    (
        "assets/omarchy-keyguide.svg",
        ".local/share/icons/hicolor/scalable/apps/omarchy-keyguide.svg",
    ),
    (
        "packaging/omarchy-keyguide-settings.desktop",
        ".local/share/applications/omarchy-keyguide-settings.desktop",
    ),
)
for source_relative, destination_relative in install_map:
    source = project_root / source_relative
    destination = installed_home / destination_relative
    if source.read_bytes() != destination.read_bytes():
        raise SystemExit(
            f"installed artifact differs from source: {destination_relative}"
        )
PY

ln -s /usr/share/omarchy/shell/Commons "$project_root/Commons"
ln -s /usr/share/omarchy/shell/Ui "$project_root/Ui"
cp tests/qml/settings_overlay_harness.qml "$harness"

timeout 10s env \
  KEYGUIDE_TEST_PLUGIN_ROOT="$plugin_root" \
  QT_LOGGING_RULES='qt.qpa.services=false' \
  quickshell --no-color -p "$harness" > build/settings-installed-qml-test.log 2>&1 || {
    cat build/settings-installed-qml-test.log
    exit 1
  }

cat build/settings-installed-qml-test.log
rg -q 'KEYGUIDE_SETTINGS_OVERLAY_TEST_PASS' build/settings-installed-qml-test.log
! rg -q 'KEYGUIDE_SETTINGS_OVERLAY_TEST_FAIL' build/settings-installed-qml-test.log

PREFIX_ROOT="$install_root" bash scripts/uninstall.sh
test ! -e "$plugin_root" && test ! -L "$plugin_root"
