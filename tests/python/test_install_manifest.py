"""Manifest-driven installation and exact removal contract tests."""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import unittest


REPOSITORY = Path(__file__).resolve().parents[2]
FIXTURES = REPOSITORY / "tests/fixtures"
SOURCE_HOME = Path(os.environ["HOME"])
PLUGIN_ID = "mrai.keyguide"
ICON_RELATIVE_PATH = (
    ".local/share/icons/hicolor/scalable/apps/omarchy-keyguide.svg"
)
VISIBILITY_MODEL_RELATIVE_PATH = (
    ".config/omarchy/plugins/mrai.keyguide/VisibilityModel.js"
)
SHORTCUTS_RELATIVE_PATH = (
    ".local/lib/omarchy-keyguide/keyguide_backend/shortcuts.py"
)
SHORTCUT_EDIT_ROW_RELATIVE_PATH = (
    ".config/omarchy/plugins/mrai.keyguide/components/ShortcutEditRow.qml"
)
EXECUTABLE_PICKER_RELATIVE_PATH = (
    ".config/omarchy/plugins/mrai.keyguide/components/ExecutablePicker.qml"
)
BOUNDED_PROCESS_RELATIVE_PATH = (
    ".local/lib/omarchy-keyguide/keyguide_backend/bounded_process.py"
)
LOCALIZED_SEARCH_RELATIVE_PATHS = (
    ".local/lib/omarchy-keyguide/keyguide_backend/catalog.py",
    ".config/omarchy/plugins/mrai.keyguide/ActionSearchModel.js",
    ".config/omarchy/plugins/mrai.keyguide/I18n.js",
    ".config/omarchy/plugins/mrai.keyguide/components/ActionSearch.qml",
)

OWNED_RELATIVE_PATHS = (
    ".local/lib/omarchy-keyguide/bin/keyguide-observer",
    ".local/lib/omarchy-keyguide/keyguide_backend/__init__.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/__main__.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/bindings.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/catalog.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/compat.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/groups.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/layout.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/presentation.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/settings.py",
    SHORTCUTS_RELATIVE_PATH,
    ".config/omarchy/plugins/mrai.keyguide/manifest.json",
    ".config/omarchy/plugins/mrai.keyguide/ActionSearchModel.js",
    ".config/omarchy/plugins/mrai.keyguide/BarWidget.qml",
    BOUNDED_PROCESS_RELATIVE_PATH,
    ".config/omarchy/plugins/mrai.keyguide/Hud.qml",
    ".config/omarchy/plugins/mrai.keyguide/HudModel.js",
    ".config/omarchy/plugins/mrai.keyguide/I18n.js",
    ".config/omarchy/plugins/mrai.keyguide/Service.qml",
    ".config/omarchy/plugins/mrai.keyguide/Settings.qml",
    VISIBILITY_MODEL_RELATIVE_PATH,
    ".config/omarchy/plugins/mrai.keyguide/components/ActionSearch.qml",
    ".config/omarchy/plugins/mrai.keyguide/components/BindingRow.qml",
    EXECUTABLE_PICKER_RELATIVE_PATH,
    ".config/omarchy/plugins/mrai.keyguide/components/HudPreview.qml",
    SHORTCUT_EDIT_ROW_RELATIVE_PATH,
    ICON_RELATIVE_PATH,
    ".local/share/applications/omarchy-keyguide-settings.desktop",
)

PRE_ICON_OWNED_RELATIVE_PATHS = (
    ".local/lib/omarchy-keyguide/bin/keyguide-observer",
    ".local/lib/omarchy-keyguide/keyguide_backend/__init__.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/__main__.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/bindings.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/compat.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/groups.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/layout.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/presentation.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/settings.py",
    ".config/omarchy/plugins/mrai.keyguide/manifest.json",
    ".config/omarchy/plugins/mrai.keyguide/BarWidget.qml",
    ".config/omarchy/plugins/mrai.keyguide/Hud.qml",
    ".config/omarchy/plugins/mrai.keyguide/HudModel.js",
    ".config/omarchy/plugins/mrai.keyguide/Service.qml",
    ".config/omarchy/plugins/mrai.keyguide/Settings.qml",
    ".config/omarchy/plugins/mrai.keyguide/components/BindingRow.qml",
    ".config/omarchy/plugins/mrai.keyguide/components/HudPreview.qml",
    ".local/share/applications/omarchy-keyguide-settings.desktop",
)

PRE_VISIBILITY_MODEL_OWNED_RELATIVE_PATHS = (
    ".local/lib/omarchy-keyguide/bin/keyguide-observer",
    ".local/lib/omarchy-keyguide/keyguide_backend/__init__.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/__main__.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/bindings.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/compat.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/groups.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/layout.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/presentation.py",
    ".local/lib/omarchy-keyguide/keyguide_backend/settings.py",
    ".config/omarchy/plugins/mrai.keyguide/manifest.json",
    ".config/omarchy/plugins/mrai.keyguide/BarWidget.qml",
    ".config/omarchy/plugins/mrai.keyguide/Hud.qml",
    ".config/omarchy/plugins/mrai.keyguide/HudModel.js",
    ".config/omarchy/plugins/mrai.keyguide/Service.qml",
    ".config/omarchy/plugins/mrai.keyguide/Settings.qml",
    ".config/omarchy/plugins/mrai.keyguide/components/BindingRow.qml",
    ".config/omarchy/plugins/mrai.keyguide/components/HudPreview.qml",
    ICON_RELATIVE_PATH,
    ".local/share/applications/omarchy-keyguide-settings.desktop",
)


class InstallSandbox:
    """Run the make interface against an isolated PREFIX_ROOT."""

    def __init__(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name) / "prefix-root"
        self.root.mkdir()
        self.home = self.root / SOURCE_HOME.relative_to("/")
        self.manifest = (
            self.home
            / ".local/state/omarchy-keyguide/install-manifest.json"
        )
        self.fake_bin = Path(self.temporary_directory.name) / "fake-bin"
        self.fake_bin.mkdir()
        self.command_log = Path(self.temporary_directory.name) / "commands.log"
        self._write_failing_live_commands()
        self._preexisting = self.snapshot()

    def cleanup(self) -> None:
        self.temporary_directory.cleanup()

    def _write_failing_live_commands(self) -> None:
        for command in ("omarchy", "omarchy-shell", "hyprctl"):
            path = self.fake_bin / command
            path.write_text(
                "#!/bin/sh\n"
                f"printf '%s\\n' \"{command} $*\" >> \"$FAKE_COMMAND_LOG\"\n"
                "exit 97\n",
                encoding="utf-8",
            )
            path.chmod(0o755)

    def command_environment(self) -> dict[str, str]:
        return {
            **os.environ,
            "XDG_DATA_HOME": str(SOURCE_HOME / ".local/share"),
            "FAKE_COMMAND_LOG": str(self.command_log),
            "PATH": f"{self.fake_bin}:{os.environ['PATH']}",
            "KEYGUIDE_COMPAT_PROGRAM": "/bin/true",
        }

    def run_make(
        self,
        target: str,
        *,
        extra_env: dict[str, str] | None = None,
        timeout: float | None = None,
    ) -> subprocess.CompletedProcess[str]:
        environment = self.command_environment()
        environment.update(extra_env or {})
        return subprocess.run(
            ["make", "-s", target, f"PREFIX_ROOT={self.root}"],
            cwd=REPOSITORY,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=timeout,
        )

    def install(self) -> subprocess.CompletedProcess[str]:
        return self.run_make("install")

    def uninstall(self) -> subprocess.CompletedProcess[str]:
        return self.run_make("uninstall")

    def uninstall_removing_preferences(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["make", "-s", "uninstall", f"PREFIX_ROOT={self.root}", "REMOVE_PREFERENCES=1"],
            cwd=REPOSITORY, env=self.command_environment(), text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
        )

    def capture_preexisting(self) -> None:
        self._preexisting = self.snapshot()

    def preexisting_snapshot(self) -> dict[str, tuple[bytes, int]]:
        return self._preexisting

    def final_snapshot(
        self, *, exclude: set[Path] | None = None
    ) -> dict[str, tuple[bytes, int]]:
        return self.snapshot(exclude=exclude)

    def snapshot(
        self, *, exclude: set[Path] | None = None
    ) -> dict[str, tuple[bytes, int]]:
        excluded = {path.absolute() for path in (exclude or set())}
        result: dict[str, tuple[bytes, int]] = {}
        for path in sorted(self.root.rglob("*")):
            if not path.is_file() or path.absolute() in excluded:
                continue
            result[str(path.relative_to(self.root))] = (
                path.read_bytes(),
                stat.S_IMODE(path.stat().st_mode),
            )
        return result

    def owned_paths(self) -> list[Path]:
        return [self.home / relative for relative in OWNED_RELATIVE_PATHS]

    def inject_concurrent_owned_program_replacement(
        self, relative_path: str = OWNED_RELATIVE_PATHS[0]
    ) -> tuple[Path, bytes]:
        """Replace an owned path after cleanup observes it but before removal."""
        target = self.home / relative_path
        captured = self.fake_bin / "concurrent-owned-program-replacement"
        replacement = b"concurrent user-owned replacement\n"
        replacement_literal = repr(replacement).replace("\\", "\\\\")
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-owned-program-remove-observation-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            f"            if path == Path({str(target)!r}) and not Path({str(captured)!r}).exists():\n"
            f"                concurrent_bytes = {replacement_literal}\n"
            "                concurrent_path = path.with_name(path.name + '.concurrent')\n"
            "                concurrent_path.write_bytes(concurrent_bytes)\n"
            "                os.replace(concurrent_path, path)\n"
            f"                Path({str(captured)!r}).write_bytes(concurrent_bytes)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured, replacement

    def inject_concurrent_owned_program_nonregular(
        self, kind: str, relative_path: str = OWNED_RELATIVE_PATHS[0]
    ) -> tuple[Path, Path]:
        """Swap a symlink or FIFO into an owned path at the removal boundary."""
        if kind not in {"symlink", "fifo"}:
            raise AssertionError(f"unsupported nonregular injection: {kind}")
        target = self.home / relative_path
        marker = self.fake_bin / f"concurrent-owned-program-{kind}"
        link_target = self.fake_bin / "concurrent-owned-program-link-target"
        link_target.write_bytes(b"user-owned symlink target\n")
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-atomic-owned-program-remove-observation-checked'\n"
            "if needle in program and not marker.exists():\n"
            "    injection = '''\n"
            f"            if path == Path({str(target)!r}) and not Path({str(marker)!r}).exists():\n"
            "                concurrent_path = path.with_name(path.name + '.concurrent')\n"
            f"                kind = {kind!r}\n"
            "                if kind == 'symlink':\n"
            f"                    os.symlink({str(link_target)!r}, concurrent_path)\n"
            "                else:\n"
            "                    os.mkfifo(concurrent_path, 0o600)\n"
            "                os.replace(concurrent_path, path)\n"
            f"                Path({str(marker)!r}).touch()\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return marker, link_target

    def fail_after_first_owned_program_capture(self) -> Path:
        """Terminate cleanup after one journaled capture without rollback."""
        marker = self.fake_bin / "owned-program-capture-crashed"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-atomic-owned-program-capture-durable'\n"
            "if needle in program and not marker.exists():\n"
            "    injection = '''\n"
            f"            if not Path({str(marker)!r}).exists():\n"
            f"                Path({str(marker)!r}).touch()\n"
            "                os._exit(86)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return marker


class SimulatedUserInstall:
    """Exercise real-mode command decisions with a temporary HOME and fakes."""

    def __init__(
        self,
        *,
        plugin_enabled: bool | None,
        discovery_delay: int = 0,
        enable_exit: int = 0,
        enable_auto_insert: str | None = None,
        break_manifest_after_enable: bool = False,
        break_manifest_after_bar_put: bool = False,
        bar_put_mode: str = "anchored",
        disable_rewrites_shell_then_fails: bool = False,
        restart_fail_on_call: int | None = None,
    ) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        temporary_root = Path(self.temporary_directory.name)
        self.home = temporary_root / "home"
        self.home.mkdir()
        self.omarchy_path = temporary_root / "omarchy"
        self.default_shell = self.omarchy_path / "config/omarchy/shell.json"
        self.write_default_shell_layout()
        self.fake_bin = temporary_root / "fake-bin"
        self.fake_bin.mkdir()
        self.command_log = temporary_root / "commands.log"
        self.bar_home_log = temporary_root / "bar-home.log"
        self.catalog_count = temporary_root / "catalog-count"
        self.restart_count = temporary_root / "restart-count"
        self.lock_probe_count = temporary_root / "lock-probe-count"
        self.lock_restart_marker = temporary_root / "lock-restart-marker"
        self.lock_status_count = temporary_root / "lock-status-count"
        self.enabled_state = temporary_root / "plugin-enabled"
        self.shell_json = self.home / ".config/omarchy/shell.json"
        self.manifest = (
            self.home
            / ".local/state/omarchy-keyguide/install-manifest.json"
        )
        self._write_fake_omarchy(
            plugin_enabled,
            discovery_delay=discovery_delay,
            enable_exit=enable_exit,
            enable_auto_insert=enable_auto_insert,
            break_manifest_after_enable=break_manifest_after_enable,
            break_manifest_after_bar_put=break_manifest_after_bar_put,
            bar_put_mode=bar_put_mode,
            disable_rewrites_shell_then_fails=disable_rewrites_shell_then_fails,
            restart_fail_on_call=restart_fail_on_call,
        )

    def cleanup(self) -> None:
        self.temporary_directory.cleanup()

    def _write_fake_omarchy(
        self,
        plugin_enabled: bool | None,
        *,
        discovery_delay: int,
        enable_exit: int,
        enable_auto_insert: str | None,
        break_manifest_after_enable: bool,
        break_manifest_after_bar_put: bool,
        bar_put_mode: str,
        disable_rewrites_shell_then_fails: bool,
        restart_fail_on_call: int | None,
    ) -> None:
        if plugin_enabled is None:
            catalog_body = "  printf '%s\\n' 'not valid json'\n"
        elif plugin_enabled:
            catalog = json.dumps([{"id": PLUGIN_ID, "enabled": True}])
            catalog_body = f"  printf '%s\\n' {shlex.quote(catalog)}\n"
        else:
            catalog = json.dumps([{"id": PLUGIN_ID, "enabled": False}])
            enabled_catalog = json.dumps([{"id": PLUGIN_ID, "enabled": True}])
            catalog_body = (
                f"  if [ -f {shlex.quote(str(self.enabled_state))} ]; then\n"
                f"    printf '%s\\n' {shlex.quote(enabled_catalog)}\n"
                "    exit 0\n"
                "  fi\n"
                f"  count_file={shlex.quote(str(self.catalog_count))}\n"
                "  count=0\n"
                "  [ ! -f \"$count_file\" ] || count=$(cat \"$count_file\")\n"
                "  count=$((count + 1))\n"
                "  printf '%s\\n' \"$count\" > \"$count_file\"\n"
                f"  if [ \"$count\" -le {1 + discovery_delay} ]; then\n"
                "    printf '%s\\n' '[]'\n"
                "  else\n"
                f"    printf '%s\\n' {shlex.quote(catalog)}\n"
                "  fi\n"
            )
        bar_helper = self.fake_bin / "fake-bar-put"
        enable_body = ""
        if enable_exit == 0:
            enable_body += f"  touch {shlex.quote(str(self.enabled_state))}\n"
        if enable_auto_insert is not None:
            enable_body += (
                f"  KEYGUIDE_FAKE_BAR_MODE={shlex.quote(enable_auto_insert)} "
                f"  {shlex.quote(str(bar_helper))} "
                f"{shlex.quote(str(self.shell_json))} "
                f"{shlex.quote(str(self.shell_json))}\n"
            )
        if break_manifest_after_enable:
            enable_body += (
                "  chmod 0500 \"$HOME/.local/state/omarchy-keyguide\"\n"
            )
        bar_helper.write_text(
            f"#!{sys.executable}\n"
            "import json\n"
            "from pathlib import Path\n"
            "import sys\n"
            "path = Path(sys.argv[1])\n"
            "live_path = Path(sys.argv[2]) if len(sys.argv) > 2 else path\n"
            "import os\n"
            f"mode = {bar_put_mode!r}\n"
            "mode = os.environ.get('KEYGUIDE_FAKE_BAR_MODE', mode)\n"
            "if mode == 'remove_then_fail':\n"
            "    path.unlink(missing_ok=True)\n"
            "    raise SystemExit(0)\n"
            "if mode == 'malformed_then_fail':\n"
            "    path.parent.mkdir(parents=True, exist_ok=True)\n"
            "    path.write_bytes(b'{\"plugins\": [')\n"
            "    raise SystemExit(0)\n"
            "if path.exists():\n"
            "    document = json.loads(path.read_text(encoding='utf-8'))\n"
            "else:\n"
            "    document = {\n"
            "        'plugins': [],\n"
            "        'bar': {'layout': {\n"
            "            'left': [],\n"
            "            'center': [],\n"
            "            'right': [\n"
            "                {'id': 'omarchy.agents'},\n"
            "                {'id': 'omarchy.bluetooth'},\n"
            "            ],\n"
            "        }},\n"
            "    }\n"
            "layout = document.setdefault('bar', {}).setdefault('layout', {})\n"
            "sections = ('left', 'center', 'right')\n"
            "for section in sections:\n"
            "    layout.setdefault(section, [])\n"
            "def entry_id(entry):\n"
            "    return entry.get('id') if isinstance(entry, dict) else entry\n"
            "if not any(\n"
            "    entry_id(entry) == 'mrai.keyguide'\n"
            "    for section in sections\n"
            "    for entry in layout[section]\n"
            "):\n"
            "    destination = layout['center']\n"
            "    index = len(destination)\n"
            "    for section in sections:\n"
            "        ids = [entry_id(entry) for entry in layout[section]]\n"
            "        if 'omarchy.agents' in ids:\n"
            "            destination = layout[section]\n"
            "            index = ids.index('omarchy.agents') + 1\n"
            "            break\n"
            "    destination.insert(index, {'id': 'mrai.keyguide'})\n"
            "if mode == 'misplaced':\n"
            "    for section in sections:\n"
            "        layout[section] = [\n"
            "            entry for entry in layout[section]\n"
            "            if entry_id(entry) != 'mrai.keyguide'\n"
            "        ]\n"
            "    layout['center'].append({'id': 'mrai.keyguide'})\n"
            "elif mode == 'duplicate':\n"
            "    layout['left'].append({'id': 'mrai.keyguide'})\n"
            "elif mode == 'entry_settings':\n"
            "    for entry in layout['right']:\n"
            "        if entry_id(entry) == 'mrai.keyguide':\n"
            "            entry['opacity'] = 0.5\n"
            "elif mode == 'unrelated':\n"
            "    document['userEdit'] = True\n"
            "elif mode == 'boolean_to_integer':\n"
            "    document['userFlag'] = 1\n"
            "elif mode == 'keyguide_less_then_fail':\n"
            "    for section in sections:\n"
            "        layout[section] = [\n"
            "            entry for entry in layout[section]\n"
            "            if entry_id(entry) != 'mrai.keyguide'\n"
            "        ]\n"
            "elif mode == 'before_agents':\n"
            "    for section in sections:\n"
            "        layout[section] = [\n"
            "            entry for entry in layout[section]\n"
            "            if entry_id(entry) != 'mrai.keyguide'\n"
            "        ]\n"
            "    destination = layout['right']\n"
            "    index = 0\n"
            "    for section in sections:\n"
            "        ids = [entry_id(entry) for entry in layout[section]]\n"
            "        if 'omarchy.agents' in ids:\n"
            "            destination = layout[section]\n"
            "            index = ids.index('omarchy.agents')\n"
            "            break\n"
            "    destination.insert(index, {'id': 'mrai.keyguide'})\n"
            "path.parent.mkdir(parents=True, exist_ok=True)\n"
            "path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + '\\n', encoding='utf-8')\n"
            "if mode == 'mode_change':\n"
            "    path.chmod(0o600)\n"
            "if mode.startswith('concurrent_live_'):\n"
            "    live_path.parent.mkdir(parents=True, exist_ok=True)\n"
            "    if mode == 'concurrent_live_same_during':\n"
            "        live_path.write_bytes(path.read_bytes())\n"
            "    elif mode == 'concurrent_live_malformed_during':\n"
            "        live_path.write_bytes(b'{\"plugins\": [')\n"
            "    elif mode == 'concurrent_live_keyguide_less_during':\n"
            "        for section in sections:\n"
            "            layout[section] = [\n"
            "                entry for entry in layout[section]\n"
            "                if entry_id(entry) != 'mrai.keyguide'\n"
            "            ]\n"
            "        live_path.write_text(json.dumps(document, indent=2, ensure_ascii=False) + '\\n', encoding='utf-8')\n"
            "    else:\n"
            "        raise SystemExit(f'unknown concurrent mode: {mode}')\n",
            encoding="utf-8",
        )
        bar_helper.chmod(0o755)
        omarchy = self.fake_bin / "omarchy"
        restart_body = (
            f"  count_file={shlex.quote(str(self.restart_count))}\n"
            "  count=0\n"
            "  [ ! -f \"$count_file\" ] || count=$(cat \"$count_file\")\n"
            "  count=$((count + 1))\n"
            "  printf '%s\\n' \"$count\" > \"$count_file\"\n"
            "  if [ -n \"${FAKE_LOCK_TRANSITION_ON_RESTART_CALL:-}\" ] "
            "&& [ \"${FAKE_LOCK_TRANSITION_ON_RESTART_CALL}\" = \"$count\" ]; then\n"
            f"    : > {shlex.quote(str(self.lock_restart_marker))}\n"
            f"    rm -f {shlex.quote(str(self.lock_status_count))}\n"
            "  fi\n"
        )
        if restart_fail_on_call is not None:
            restart_body += (
                f"  [ \"$count\" -ne {restart_fail_on_call} ] || exit 89\n"
            )
        restart_body += "  exit 0\n"
        if bar_put_mode == "fail_before":
            bar_put_body = "  exit 87\n"
        elif bar_put_mode in {
            "mutate_then_fail",
            "malformed_then_fail",
            "keyguide_less_then_fail",
            "remove_then_fail",
        }:
            bar_put_body = (
                f"  printf '%s\\n' \"$HOME\" >> {shlex.quote(str(self.bar_home_log))}\n"
                f"  {shlex.quote(str(bar_helper))} "
                "\"$HOME/.config/omarchy/shell.json\" "
                f"{shlex.quote(str(self.shell_json))}\n"
                "  exit 87\n"
            )
        else:
            bar_put_body = (
                f"  printf '%s\\n' \"$HOME\" >> {shlex.quote(str(self.bar_home_log))}\n"
                f"  {shlex.quote(str(bar_helper))} "
                "\"$HOME/.config/omarchy/shell.json\" "
                f"{shlex.quote(str(self.shell_json))}\n"
            )
            if break_manifest_after_bar_put:
                bar_put_body += (
                    "  chmod 0500 \"$HOME/.local/state/omarchy-keyguide\"\n"
                )
            bar_put_body += "  exit 0\n"
        disable_body = ""
        if disable_rewrites_shell_then_fails:
            disable_body += (
                f"  printf '%s\\n' '{{\"plugins\":[],\"disableIntermediate\":true}}' > "
                f"{shlex.quote(str(self.shell_json))}\n"
                "  exit 88\n"
            )
        disable_body += f"  rm -f {shlex.quote(str(self.enabled_state))}\n"
        script = (
            "#!/bin/sh\n"
            "printf '%s\\n' \"$*\" >> \"$FAKE_COMMAND_LOG\"\n"
            "if [ \"$*\" = 'plugin list --json' ]; then\n"
            + catalog_body
            + "  exit 0\n"
            "fi\n"
            f"if [ \"$*\" = 'plugin enable {PLUGIN_ID}' ]; then\n"
            + enable_body
            + f"  exit {enable_exit}\n"
            "fi\n"
            f"if [ \"$*\" = 'plugin disable {PLUGIN_ID}' ]; then\n"
            + disable_body
            + "  exit 0\n"
            "fi\n"
            f"if [ \"$*\" = 'bar put {PLUGIN_ID} --after omarchy.agents' ]; then\n"
            + bar_put_body
            + "fi\n"
            "if [ \"$*\" = 'restart shell' ]; then\n"
            + restart_body
            + "fi\n"
        )
        omarchy.write_text(script, encoding="utf-8")
        omarchy.chmod(0o755)
        lock_probe = self.fake_bin / "omarchy-hyprland-session-locked"
        lock_probe.write_text(
            "#!/bin/sh\n"
            f"count_file={shlex.quote(str(self.lock_probe_count))}\n"
            "count=0\n"
            "[ ! -f \"$count_file\" ] || count=$(cat \"$count_file\")\n"
            "count=$((count + 1))\n"
            "printf '%s\\n' \"$count\" > \"$count_file\"\n"
            f"if [ -f {shlex.quote(str(self.lock_restart_marker))} ] "
            "&& [ \"${FAKE_COMPOSITOR_LOCK_AFTER_RESTART:-0}\" = 1 ]; then\n"
            "  exit 0\n"
            "fi\n"
            "if [ \"${FAKE_LOCK_PROBE_LOCK_ON_CALL:-}\" = \"$count\" ]; then\n"
            "  exit 0\n"
            "fi\n"
            "exit ${FAKE_LOCK_PROBE_EXIT:-1}\n",
            encoding="utf-8",
        )
        lock_probe.chmod(0o755)
        shell = self.fake_bin / "omarchy-shell"
        shell.write_text(
            "#!/bin/sh\n"
            "if [ \"$*\" = 'lock status' ]; then\n"
            f"  if [ -f {shlex.quote(str(self.lock_restart_marker))} ] "
            "&& [ -n \"${FAKE_LOCK_STATUS_FAIL_AFTER_RESTART_COUNT:-}\" ]; then\n"
            f"    count_file={shlex.quote(str(self.lock_status_count))}\n"
            "    count=0\n"
            "    [ ! -f \"$count_file\" ] || count=$(cat \"$count_file\")\n"
            "    count=$((count + 1))\n"
            "    printf '%s\\n' \"$count\" > \"$count_file\"\n"
            "    if [ \"$count\" -le "
            "\"${FAKE_LOCK_STATUS_FAIL_AFTER_RESTART_COUNT}\" ]; then\n"
            "      exit 97\n"
            "    fi\n"
            "  fi\n"
            "  if [ \"${FAKE_LOCK_STATUS_JSON+x}\" = x ]; then\n"
            "    printf '%s\\n' \"$FAKE_LOCK_STATUS_JSON\"\n"
            "  else\n"
            "    printf '%s\\n' '{\"requested\":false,\"pending\":false,\"sessionLocked\":false,\"secure\":false}'\n"
            "  fi\n"
            "  exit ${FAKE_LOCK_STATUS_EXIT:-0}\n"
            "fi\n"
            "exit 97\n",
            encoding="utf-8",
        )
        shell.chmod(0o755)
        for command in ("hyprctl",):
            forbidden = self.fake_bin / command
            forbidden.write_text("#!/bin/sh\nexit 97\n", encoding="utf-8")
            forbidden.chmod(0o755)

    def run_install_script(
        self,
        *,
        extra_env: dict[str, str] | None = None,
        timeout: float | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", "scripts/install.sh"],
            cwd=REPOSITORY,
            env=self.command_environment(extra_env),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=timeout,
        )

    def run_make(
        self,
        target: str,
        *,
        extra_env: dict[str, str] | None = None,
        timeout: float | None = None,
    ) -> subprocess.CompletedProcess[str]:
        environment = self.command_environment(extra_env)
        return subprocess.run(
            ["make", "-s", target, "PREFIX_ROOT="],
            cwd=REPOSITORY,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=timeout,
        )

    def command_environment(
        self, extra_env: dict[str, str] | None = None
    ) -> dict[str, str]:
        environment = {
            **os.environ,
            "HOME": str(self.home),
            "OMARCHY_PATH": str(self.omarchy_path),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "FAKE_COMMAND_LOG": str(self.command_log),
            "PATH": f"{self.fake_bin}:{os.environ['PATH']}",
            "KEYGUIDE_COMPAT_PROGRAM": "/bin/true",
        }
        environment.pop("PREFIX_ROOT", None)
        environment.update(extra_env or {})
        return environment

    def run_uninstall_script(
        self,
        *,
        args: list[str] | None = None,
        extra_env: dict[str, str] | None = None,
        timeout: float | None = None,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["bash", "scripts/uninstall.sh", *(args or [])],
            cwd=REPOSITORY,
            env=self.command_environment(extra_env),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
            timeout=timeout,
        )

    def run_preserve_uninstall_to_upgrade_ready(self) -> subprocess.CompletedProcess[str]:
        document = json.loads(self.manifest.read_text(encoding="utf-8"))
        owned = set(document["owned_files"])
        new_only = [
            str(self.home / relative)
            for relative in OWNED_RELATIVE_PATHS
            if str(self.home / relative) not in owned
        ]
        return subprocess.run(
            ["bash", "scripts/uninstall.sh", *new_only],
            cwd=REPOSITORY,
            env=self.command_environment(
                {
                    "KEYGUIDE_PRESERVE_UPGRADE": "1",
                    "KEYGUIDE_EXPECTED_PLUGIN_WAS_ENABLED": (
                        "true" if document["plugin_was_enabled"] else "false"
                    ),
                    "REMOVE_PREFERENCES": "0",
                }
            ),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

    def default_shell_document(
        self,
        *,
        left: list[str] | None = None,
        center: list[str] | None = None,
        right: list[str] | None = None,
    ) -> dict[str, object]:
        return {
            "version": 1,
            "idle": {
                "screensaver": 150,
                "lock": 300,
            },
            "bar": {
                "position": "top",
                "transparent": False,
                "centerAnchor": "omarchy.clock",
                "layout": {
                    "left": [{"id": item} for item in left or ["omarchy.menu"]],
                    "center": [
                        {"id": item}
                        for item in center
                        or ["omarchy.indicators", "omarchy.clock"]
                    ],
                    "right": [
                        {"id": item}
                        for item in right
                        or ["omarchy.agents", "omarchy.bluetooth"]
                    ],
                },
            },
            "plugins": [],
        }

    def write_default_shell_layout(
        self,
        *,
        left: list[str] | None = None,
        center: list[str] | None = None,
        right: list[str] | None = None,
    ) -> None:
        self.default_shell.parent.mkdir(parents=True, exist_ok=True)
        self.default_shell.write_text(
            json.dumps(
                self.default_shell_document(
                    left=left,
                    center=center,
                    right=right,
                ),
                indent=2,
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )

    def expected_default_bar_shell_with_keyguide(self) -> bytes:
        document = self.default_shell_document()
        right = document["bar"]["layout"]["right"]  # type: ignore[index]
        right.insert(1, {"id": PLUGIN_ID})
        return (
            json.dumps(
                document,
                indent=2,
                ensure_ascii=False,
                sort_keys=True,
            )
            + "\n"
        ).encode()

    def commands(self) -> list[str]:
        if not self.command_log.exists():
            return []
        return self.command_log.read_text(encoding="utf-8").splitlines()

    def lock_sensitive_snapshot(self) -> dict[str, object]:
        """Capture every endpoint that a lock gate must leave untouched."""
        watched = {
            "manifest": self.manifest,
            "shell": self.shell_json,
            "plugin": self.home / ".config/omarchy/plugins/mrai.keyguide",
            "installed": self.home / ".local/lib/omarchy-keyguide",
        }
        snapshot: dict[str, object] = {}
        for label, root in watched.items():
            if not root.exists() and not root.is_symlink():
                snapshot[label] = ("absent",)
            elif root.is_file() or root.is_symlink():
                snapshot[label] = (
                    "file",
                    root.read_bytes(),
                    stat.S_IMODE(root.stat().st_mode),
                )
            else:
                snapshot[label] = tuple(
                    (
                        str(path.relative_to(root)),
                        path.read_bytes(),
                        stat.S_IMODE(path.stat().st_mode),
                    )
                    for path in sorted(root.rglob("*"))
                    if path.is_file() and not path.is_symlink()
                )
        return snapshot

    def write_shell_layout(
        self,
        *,
        left: list[str] | None = None,
        center: list[str] | None = None,
        right: list[str] | None = None,
    ) -> None:
        self.shell_json.parent.mkdir(parents=True, exist_ok=True)
        document = {
            "plugins": [],
            "bar": {
                "layout": {
                    "left": [{"id": item} for item in left or []],
                    "center": [{"id": item} for item in center or []],
                    "right": [{"id": item} for item in right or []],
                }
            },
        }
        self.shell_json.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

    def widget_order(self, section: str = "right") -> list[str]:
        document = json.loads(self.shell_json.read_text(encoding="utf-8"))
        entries = document["bar"]["layout"][section]
        return [
            entry.get("id") if isinstance(entry, dict) else entry
            for entry in entries
        ]

    def move_widget_as_user(self, section: str, index: int) -> None:
        document = json.loads(self.shell_json.read_text(encoding="utf-8"))
        layout = document["bar"]["layout"]
        widget = None
        for entries in layout.values():
            for candidate_index, entry in enumerate(entries):
                entry_id = entry.get("id") if isinstance(entry, dict) else entry
                if entry_id == PLUGIN_ID:
                    widget = entries.pop(candidate_index)
                    break
            if widget is not None:
                break
        if widget is None:
            raise AssertionError("Keyguide widget is not present")
        layout[section].insert(index, widget)
        self.shell_json.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

    def prepare_retained_clock_edit(
        self,
        *,
        legacy_new_only: tuple[str, ...] = (
            BOUNDED_PROCESS_RELATIVE_PATH,
            ICON_RELATIVE_PATH,
            VISIBILITY_MODEL_RELATIVE_PATH,
            SHORTCUTS_RELATIVE_PATH,
            SHORTCUT_EDIT_ROW_RELATIVE_PATH,
            EXECUTABLE_PICKER_RELATIVE_PATH,
        ),
        extra_env: dict[str, str] | None = None,
    ) -> tuple[bytes, bytes]:
        """Build the authenticated legacy install shape retained on the host."""
        self.write_shell_layout(
            left=["omarchy.menu"],
            right=["omarchy.agents", "omarchy.bluetooth"],
        )
        baseline = json.loads(self.shell_json.read_text(encoding="utf-8"))
        baseline["version"] = 1
        baseline["idle"] = {"screensaver": 600, "lock": 1800}
        baseline["bar"]["transparent"] = False
        baseline["bar"]["layout"]["center"] = [
            {
                "id": "omarchy.clock",
                "format": "dddd HH:mm",
                "formatAlt": "d MMMM 'W'ww yyyy",
                "verticalFormat": "HH\n—\nmm",
            }
        ]
        self.shell_json.write_text(
            json.dumps(baseline, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        self.run_make_succeeded("install", extra_env=extra_env)

        manifest = json.loads(self.manifest.read_text(encoding="utf-8"))
        historical_new_only = tuple(dict.fromkeys(
            (*legacy_new_only, *LOCALIZED_SEARCH_RELATIVE_PATHS)
        ))
        for relative in historical_new_only:
            installed_new_file = self.home / relative
            installed_new_file.unlink()
            manifest["owned_files"].remove(str(installed_new_file))
        shell_state = manifest["shell_config"]
        del shell_state["pre_sha256"]
        del shell_state["restore_state"]
        del shell_state["bar_placement_state"]
        self.manifest.write_text(
            json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
        )

        installed = json.loads(self.shell_json.read_text(encoding="utf-8"))
        for entry in installed["bar"]["layout"]["center"]:
            if entry.get("id") == "omarchy.clock":
                entry["format"] = "ddd d MMM h:mm AP"
        installed["unrelated"] = {
            "preserveBoolean": True,
            "preserveInteger": 1,
            "preserveNull": None,
        }
        self.shell_json.write_text(
            json.dumps(installed, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        return (
            self.manifest.read_bytes(),
            (self.manifest.parent / "shell.json.pre-keyguide").read_bytes(),
        )

    def run_make_succeeded(self, target: str, **kwargs: object) -> None:
        result = self.run_make(target, **kwargs)
        if result.returncode != 0:
            raise AssertionError(result.stdout)

    def inject_preserve_rebase_concurrent_shell_edit(self) -> None:
        """Change the shell after observation but before the first journal write."""
        marker = self.fake_bin / "preserve-rebase-concurrent-edit"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-preserve-rebase-observations-captured'\n"
            "if needle in program and not marker.exists():\n"
            "    marker.touch()\n"
            "    injection = '''\n"
            "        concurrent_document = json.loads(\n"
            "            shell_path.read_text(encoding=\"utf-8\"),\n"
            "            object_pairs_hook=unique_object,\n"
            "        )\n"
            "        concurrent_document[\"concurrentUserEdit\"] = \"retained\"\n"
            "        shell_path.write_text(\n"
            "            json.dumps(concurrent_document, indent=2, ensure_ascii=False) + \"\\\\n\",\n"
            "            encoding=\"utf-8\",\n"
            "        )\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)

    def inject_new_icon_creation_at_uninstall_boundary(self) -> Path:
        """Try an O_EXCL user icon create when the old uninstall is invoked."""
        marker = self.fake_bin / "upgrade-icon-boundary-result"
        icon = self.home / ICON_RELATIVE_PATH
        real_bash = shutil.which("bash")
        if real_bash is None:
            raise AssertionError("bash executable is unavailable")
        bash_wrapper = self.fake_bin / "bash"
        bash_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import errno\n"
            "import os\n"
            "from pathlib import Path\n"
            "import sys\n"
            f"marker = Path({str(marker)!r})\n"
            f"icon = Path({str(icon)!r})\n"
            "if any(argument.endswith('scripts/uninstall.sh') for argument in sys.argv[1:]) and not marker.exists():\n"
            "    icon.parent.mkdir(parents=True, exist_ok=True)\n"
            "    try:\n"
            "        descriptor = os.open(icon, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o640)\n"
            "    except OSError as error:\n"
            "        if error.errno != errno.EEXIST:\n"
            "            raise\n"
            "        marker.write_text('reserved\\n', encoding='utf-8')\n"
            "    else:\n"
            "        os.write(descriptor, b'user-owned boundary icon\\n')\n"
            "        os.fsync(descriptor)\n"
            "        os.close(descriptor)\n"
            "        marker.write_text('created\\n', encoding='utf-8')\n"
            f"os.execv({real_bash!r}, [{real_bash!r}, *sys.argv[1:]])\n",
            encoding="utf-8",
        )
        bash_wrapper.chmod(0o755)
        return marker

    def fail_next_upgrade_icon_copy(self) -> Path:
        """Fail one source copy after the handoff reservation is adopted."""
        marker = self.fake_bin / "upgrade-icon-copy-failed"
        icon = self.home / ICON_RELATIVE_PATH
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-atomic-payload-publication-observation-checked'\n"
            "if needle in program and not marker.exists():\n"
            "    injection = '''\n"
            f"    if destination == Path({str(icon)!r}) and not Path({str(marker)!r}).exists():\n"
            f"        Path({str(marker)!r}).touch()\n"
            "        raise OSError('simulated payload publication failure')\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return marker

    def crash_during_payload_publication(self, boundary: str) -> Path:
        """Hard-stop once at a durable payload-publication boundary."""
        needles = {
            "exchange": "# keyguide-atomic-payload-publication-exchange-durable",
            "cleanup": "# keyguide-atomic-payload-reservation-cleanup-durable",
        }
        if boundary not in needles:
            raise AssertionError(f"unsupported payload crash boundary: {boundary}")
        marker = self.fake_bin / f"payload-publication-{boundary}-crashed"
        icon = self.home / ICON_RELATIVE_PATH
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            f"needle = {needles[boundary]!r}\n"
            "if needle in program and not marker.exists():\n"
            "    injection = '''\n"
            f"    if destination == Path({str(icon)!r}) and not Path({str(marker)!r}).exists():\n"
            f"        Path({str(marker)!r}).touch()\n"
            "        os._exit(87)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return marker

    def crash_after_payload_exchange_with_replacement(
        self, kind: str
    ) -> tuple[Path, Path, Path, bytes]:
        """Replace a reservation, then stop before the publisher can roll back."""
        if kind not in {"regular", "symlink", "fifo"}:
            raise AssertionError(f"unsupported publication injection: {kind}")
        marker = self.fake_bin / f"payload-displaced-{kind}"
        crash_marker = self.fake_bin / f"payload-displaced-{kind}-crashed"
        victim = self.fake_bin / f"payload-displaced-{kind}-victim"
        victim.write_bytes(b"user-owned displaced symlink victim\n")
        replacement = b"displaced concurrent user icon\n"
        icon = self.home / ICON_RELATIVE_PATH
        observation_injection = (
            f"\n    injection_path = Path({str(icon)!r})\n"
            f"    injection_marker = Path({str(marker)!r})\n"
            "    if destination == injection_path and not injection_marker.exists():\n"
            "        injection_temporary = injection_path.with_name(\n"
            "            injection_path.name + '.concurrent'\n"
            "        )\n"
            f"        injection_kind = {kind!r}\n"
            "        if injection_kind == 'regular':\n"
            f"            injection_temporary.write_bytes({replacement!r})\n"
            "        elif injection_kind == 'symlink':\n"
            f"            os.symlink({str(victim)!r}, injection_temporary)\n"
            "        else:\n"
            "            os.mkfifo(injection_temporary, 0o600)\n"
            "        os.replace(injection_temporary, injection_path)\n"
            "        injection_marker.touch()\n"
        )
        crash_injection = (
            f"\n    crash_marker = Path({str(crash_marker)!r})\n"
            f"    if destination == Path({str(icon)!r}) and not crash_marker.exists():\n"
            "        crash_marker.touch()\n"
            "        os._exit(89)\n"
        )
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            "observation = '# keyguide-atomic-payload-publication-observation-checked'\n"
            "durable = '# keyguide-atomic-payload-publication-exchange-durable'\n"
            f"marker = Path({str(marker)!r})\n"
            f"observation_injection = {observation_injection!r}\n"
            f"crash_injection = {crash_injection!r}\n"
            "if observation in program and not marker.exists():\n"
            "    program = program.replace(observation, observation + observation_injection, 1)\n"
            "    program = program.replace(durable, durable + crash_injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return marker, crash_marker, victim, replacement

    def inject_payload_publication_replacement(
        self, kind: str
    ) -> tuple[Path, Path, bytes]:
        """Replace the icon reservation at the payload-publication boundary."""
        if kind not in {"regular", "symlink", "fifo"}:
            raise AssertionError(f"unsupported publication injection: {kind}")
        marker = self.fake_bin / f"payload-publication-{kind}"
        victim = self.fake_bin / f"payload-publication-{kind}-victim"
        victim.write_bytes(b"user-owned symlink victim\n")
        replacement = b"concurrent user-owned icon\n"
        icon = self.home / ICON_RELATIVE_PATH

        injection = (
            f"\n    injection_path = Path({str(icon)!r})\n"
            f"    injection_marker = Path({str(marker)!r})\n"
            "    if destination == injection_path and not injection_marker.exists():\n"
            "        injection_temporary = injection_path.with_name(\n"
            "            injection_path.name + '.concurrent'\n"
            "        )\n"
            f"        injection_kind = {kind!r}\n"
            "        if injection_kind == 'regular':\n"
            f"            injection_temporary.write_bytes({replacement!r})\n"
            "        elif injection_kind == 'symlink':\n"
            f"            os.symlink({str(victim)!r}, injection_temporary)\n"
            "        else:\n"
            "            os.mkfifo(injection_temporary, 0o600)\n"
            "        os.replace(injection_temporary, injection_path)\n"
            "        injection_marker.touch()\n"
        )
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-atomic-payload-publication-observation-checked'\n"
            f"injection = {injection!r}\n"
            "if needle in program and not marker.exists():\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)

        real_install = shutil.which("install")
        if real_install is None:
            raise AssertionError("install executable is unavailable")
        install_wrapper = self.fake_bin / "install"
        install_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import os\n"
            "from pathlib import Path\n"
            "import sys\n"
            f"icon = Path({str(icon)!r})\n"
            f"marker = Path({str(marker)!r})\n"
            "if Path(sys.argv[-1]) == icon and not marker.exists():\n"
            "    temporary = icon.with_name(icon.name + '.concurrent')\n"
            f"    kind = {kind!r}\n"
            "    if kind == 'regular':\n"
            f"        temporary.write_bytes({replacement!r})\n"
            "    elif kind == 'symlink':\n"
            f"        os.symlink({str(victim)!r}, temporary)\n"
            "    else:\n"
            "        os.mkfifo(temporary, 0o600)\n"
            "    os.replace(temporary, icon)\n"
            "    marker.touch()\n"
            f"os.execv({real_install!r}, [{real_install!r}, *sys.argv[1:]])\n",
            encoding="utf-8",
        )
        install_wrapper.chmod(0o755)
        return marker, victim, replacement

    def inject_payload_replacement_before_manifest_journal(
        self,
    ) -> tuple[Path, bytes]:
        """Replace the new icon after payload verification, before ownership journal."""
        marker = self.fake_bin / "payload-replaced-before-journal"
        replacement = b"user replacement after payload verification\n"
        icon = self.home / ICON_RELATIVE_PATH
        return marker, replacement

    def inject_same_payload_replacement_before_manifest_journal(
        self,
    ) -> tuple[Path, bytes]:
        """Replace the icon with identical bytes/mode but a new inode."""
        marker = self.fake_bin / "same-payload-replaced-before-journal"
        replacement = (REPOSITORY / "assets/omarchy-keyguide.svg").read_bytes()
        return marker, replacement

    def inject_shell_edit_before_bar_placement(self) -> Path:
        """Edit shell after placing is journaled but before bar placement mutates it."""
        marker = self.fake_bin / "shell-edit-before-bar-placement"
        return marker

    def inject_odd_shell_edit_before_bar_placement(self) -> tuple[Path, bytes]:
        """Write an odd-formatted concurrent shell edit before bar placement."""
        marker = self.fake_bin / "odd-shell-edit-before-bar-placement"
        odd_bytes = (
            b'{\n'
            b'  "plugins" : [ "mrai.keyguide" ],\n'
            b'  "bar" : { "layout" : { "left" : [ ], "center" : [ ], '
            b'"right" : [ {"id":"omarchy.agents"} , {"id":"omarchy.bluetooth"} ] } },\n'
            b'  "concurrentUserEdit" : "retained"\n'
            b'}\n'
        )
        return marker, odd_bytes

    def inject_shell_restore_owner_loss(self) -> Path:
        """Force restore staging to fail final owner/group verification."""
        return self.fake_bin / "shell-restore-owner-loss"

    def inject_shell_capture_owner_loss_before_bar_placement(self) -> Path:
        """Force pre-bar shell capture to prove owner/group cannot be preserved."""
        return self.fake_bin / "shell-capture-owner-loss"

    def inject_shell_rollback_final_change(self) -> Path:
        """Force post-rollback final verification to observe a changed endpoint."""
        return self.fake_bin / "shell-rollback-final-change"

    def inject_upgrade_ready_manifest_change_before_install_adoption(self) -> Path:
        """Change upgrade-ready handoff after inspection but before adoption."""
        marker = self.fake_bin / "upgrade-ready-manifest-changed-before-adoption"
        return marker

    def inject_upgrade_reservation_parent_symlink(self) -> tuple[Path, Path]:
        """Replace the new icon parent with a symlink during handoff reservation."""
        marker = self.fake_bin / "upgrade-reservation-parent-symlink"
        escaped = self.fake_bin / "escaped-upgrade-reservation-parent"
        escaped.mkdir()
        icon_parent = (self.home / ICON_RELATIVE_PATH).parent
        return marker, escaped

    def tamper_shell_preimage_owner_in_manifest(self) -> None:
        """Make recorded shell uid/gid impossible for the real backup to satisfy."""
        document = json.loads(self.manifest.read_text(encoding="utf-8"))
        shell_state = document["shell_config"]
        shell_state["pre_uid"] = os.getuid() + 1
        shell_state["pre_gid"] = os.getgid()
        self.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

    def inject_atomic_payload_publication_replacement(
        self, mode: str
    ) -> tuple[Path, Path]:
        """Replace the icon after its reservation check, before publication."""
        if mode not in {"regular", "symlink", "fifo"}:
            raise ValueError(f"unsupported replacement mode: {mode}")
        marker = self.fake_bin / f"payload-publication-{mode}-injected"
        victim = self.fake_bin / f"payload-publication-{mode}-victim"
        victim.write_bytes(b"payload publication victim\n")
        icon = self.home / ICON_RELATIVE_PATH
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-atomic-payload-publication-observation-checked'\n"
            "if needle in program and not marker.exists():\n"
            "    marker.touch()\n"
            "    position = program.index(needle)\n"
            "    line_start = program.rfind('\\n', 0, position) + 1\n"
            "    indentation = program[line_start:position]\n"
            f"    icon = {str(icon)!r}\n"
            f"    victim = {str(victim)!r}\n"
            f"    mode = {mode!r}\n"
            "    statements = [\n"
            "        f'injected_icon = __import__(\"pathlib\").Path({icon!r})',\n"
            "        'try:',\n"
            "        '    injected_icon.unlink()',\n"
            "        'except FileNotFoundError:',\n"
            "        '    pass',\n"
            "    ]\n"
            "    if mode == 'regular':\n"
            "        statements.extend([\n"
            "            \"injected_icon.write_bytes(b'user-owned payload race\\\\n')\",\n"
            "            'injected_icon.chmod(0o640)',\n"
            "        ])\n"
            "    elif mode == 'symlink':\n"
            "        statements.append(f'injected_icon.symlink_to({victim!r})')\n"
            "    else:\n"
            "        statements.append(\n"
            "            '__import__(\"os\").mkfifo(injected_icon, 0o640)'\n"
            "        )\n"
            "    injection = '\\n'.join(indentation + line for line in statements)\n"
            "    program = program.replace(needle, needle + '\\n' + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return marker, victim

    def crash_after_atomic_payload_exchange(self) -> Path:
        """Exit once after the payload exchange has become durable."""
        marker = self.fake_bin / "payload-publication-exchange-crashed"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-atomic-payload-publication-exchange-durable'\n"
            "if needle in program and not marker.exists():\n"
            "    marker.touch()\n"
            "    position = program.index(needle)\n"
            "    line_start = program.rfind('\\n', 0, position) + 1\n"
            "    indentation = program[line_start:position]\n"
            "    injection = indentation + '__import__(\"os\")._exit(91)'\n"
            "    program = program.replace(needle, needle + '\\n' + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return marker

    def inject_preserve_rebase_backup_publication_fault(self) -> None:
        """Fail once after the rebase journal and before backup replacement."""
        marker = self.fake_bin / "preserve-rebase-backup-publication-failed"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-atomic-shell-rebase'\n"
            "if needle in program and not marker.exists():\n"
            "    marker.touch()\n"
            "    program = program.replace(\n"
            "        needle,\n"
            "        needle + '\\n        raise OSError(\"simulated rebase backup publication failure\")',\n"
            "        1,\n"
            "    )\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)

    def inject_manifest_change_after_preserve_validation(self) -> Path:
        """Replace the manifest after validation but before its digest is emitted."""
        captured = self.fake_bin / "concurrent-manifest-after-validation"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-preserve-manifest-validation-complete'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            "concurrent_document = json.loads(\n"
            "    manifest_bytes.decode(\"utf-8\"),\n"
            "    object_pairs_hook=unique_object,\n"
            ")\n"
            "concurrent_document[\"owned_files\"] = concurrent_document[\"owned_files\"][:-1]\n"
            "concurrent_bytes = (json.dumps(concurrent_document, indent=2) + \"\\\\n\").encode(\"utf-8\")\n"
            "manifest.write_bytes(concurrent_bytes)\n"
            f"Path({str(captured)!r}).write_bytes(concurrent_bytes)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured

    def inject_manifest_change_during_shell_restoring_transition(self) -> Path:
        """Replace the manifest after a transition stages stale bytes."""
        captured = self.fake_bin / "concurrent-shell-restoring-manifest"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-manifest-transition-observation-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            f"    if transition == \"shell_restoring\" and not Path({str(captured)!r}).exists():\n"
            "        concurrent_document = json.loads(manifest.read_text(encoding=\"utf-8\"))\n"
            "        concurrent_document[\"concurrentUserEdit\"] = \"retained\"\n"
            "        concurrent_bytes = (json.dumps(concurrent_document, indent=2) + \"\\\\n\").encode(\"utf-8\")\n"
            "        manifest.write_bytes(concurrent_bytes)\n"
            f"        Path({str(captured)!r}).write_bytes(concurrent_bytes)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured

    def inject_manifest_change_before_final_removal(self) -> Path:
        """Replace restart-pending manifest bytes just before final removal."""
        captured = self.fake_bin / "concurrent-final-manifest-removal"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-final-manifest-remove-observation-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            "    concurrent_document = __import__(\"json\").loads(manifest_path.read_text(encoding=\"utf-8\"))\n"
            "    concurrent_document[\"concurrentUserEdit\"] = \"retained\"\n"
            "    concurrent_bytes = (__import__(\"json\").dumps(concurrent_document, indent=2) + \"\\\\n\").encode(\"utf-8\")\n"
            "    manifest_path.write_bytes(concurrent_bytes)\n"
            f"    Path({str(captured)!r}).write_bytes(concurrent_bytes)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured

    def inject_backup_change_before_final_removal(self) -> Path:
        """Replace backup bytes in the final removal check/use interval."""
        captured = self.fake_bin / "concurrent-final-backup-removal"
        real_rm = shutil.which("rm")
        if real_rm is None:
            raise AssertionError("rm executable is unavailable")
        fake_rm = self.fake_bin / "rm"
        fake_rm.write_text(
            "#!/usr/bin/bash\n"
            "target=${!#}\n"
            f"if [[ $target == *shell.json.pre-keyguide && ! -e {shlex.quote(str(captured))} ]]; then\n"
            "  printf '%s\\n' 'concurrent-backup-edit' >> \"$target\"\n"
            f"  cp -- \"$target\" {shlex.quote(str(captured))}\n"
            "fi\n"
            f"exec {shlex.quote(real_rm)} \"$@\"\n",
            encoding="utf-8",
        )
        fake_rm.chmod(0o755)

        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-owned-file-remove-observation-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            f"    if label == \"shell backup\" and not Path({str(captured)!r}).exists():\n"
            "        concurrent_bytes = path.read_bytes() + b\"concurrent-backup-edit\\\\n\"\n"
            "        path.write_bytes(concurrent_bytes)\n"
            f"        Path({str(captured)!r}).write_bytes(concurrent_bytes)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured

    def inject_concurrent_manifest_at_atomic_publish(self) -> Path:
        """Replace the manifest after its last check but before publication."""
        captured = self.fake_bin / "concurrent-manifest-at-publication"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-publish-observation-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            f"        if label == \"manifest\" and not Path({str(captured)!r}).exists():\n"
            "            concurrent_document = parse_object(path.read_bytes(), \"concurrent manifest\")\n"
            "            concurrent_document[\"concurrentUserEdit\"] = \"retained\"\n"
            "            concurrent_bytes = json_bytes(concurrent_document)\n"
            "            path.write_bytes(concurrent_bytes)\n"
            f"            Path({str(captured)!r}).write_bytes(concurrent_bytes)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured

    def inject_manifest_symlink_at_atomic_publish(self) -> Path:
        """Swap in a symlink after the last manifest publication check."""
        target = self.fake_bin / "concurrent-manifest-symlink-target"
        marker = self.fake_bin / "concurrent-manifest-symlink-injected"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-atomic-publish-observation-checked'\n"
            "if needle in program and not marker.exists():\n"
            "    injection = '''\n"
            f"        if label == \"manifest\" and not Path({str(marker)!r}).exists():\n"
            f"            Path({str(marker)!r}).touch()\n"
            f"            Path({str(target)!r}).write_bytes(path.read_bytes())\n"
            "            path.unlink()\n"
            f"            path.symlink_to(Path({str(target)!r}))\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return target

    def inject_late_concurrent_shell_restore_edit(self) -> Path:
        """Edit the shell after restore verification but before publication."""
        captured = self.fake_bin / "late-concurrent-shell-restore-edit"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-shell-restore-observation-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            "        current_bytes = destination.read_bytes()\n"
            "        if not current_bytes.endswith(b\"}\\\\n\"):\n"
            "            raise RuntimeError(\"test shell endpoint is not canonical JSON\")\n"
            "        concurrent_bytes = current_bytes[:-2] + b',\\\\n  \"lateConcurrentEdit\": \"retained\"\\\\n}\\\\n'\n"
            "        destination.write_bytes(concurrent_bytes)\n"
            f"        Path({str(captured)!r}).write_bytes(concurrent_bytes)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured

    def inject_late_bar_rollback_publication_edit(self) -> Path:
        """Edit the shell after bar rollback observation but before publication."""
        captured = self.fake_bin / "late-bar-rollback-publication-edit"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-bar-rollback-observation-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            "    current_bytes = shell.read_bytes()\n"
            "    if not current_bytes.endswith(b\"}\\\\n\"):\n"
            "        raise RuntimeError(\"test shell endpoint is not canonical JSON\")\n"
            "    concurrent_bytes = current_bytes[:-2] + b',\\\\n  \"lateBarRollbackEdit\": \"retained\"\\\\n}\\\\n'\n"
            "    shell.write_bytes(concurrent_bytes)\n"
            f"    Path({str(captured)!r}).write_bytes(concurrent_bytes)\n"
            "'''\n"
            "    program = program.replace(needle, needle + '\\n' + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured

    def inject_second_bar_rollback_mismatch_edit(self) -> tuple[Path, Path]:
        """Edit once into the exchange mismatch, then again before rollback-back."""
        first = self.fake_bin / "first-bar-rollback-mismatch-edit"
        second = self.fake_bin / "second-bar-rollback-mismatch-edit"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"first = Path({str(first)!r})\n"
            f"second = Path({str(second)!r})\n"
            "first_needle = '    staged_snapshot = snapshot_from(*read_regular(temporary))\\n    exchange(directory_descriptor, temporary.name, shell.name)'\n"
            "first_injection = '''    staged_snapshot = snapshot_from(*read_regular(temporary))\n"
            f"    first_marker = Path({str(first)!r})\n"
            "    if not first_marker.exists():\n"
            "        current_bytes = shell.read_bytes()\n"
            "        if not current_bytes.endswith(b\"}\\\\n\"):\n"
            "            raise RuntimeError(\"test shell endpoint is not canonical JSON\")\n"
            "        concurrent_bytes = current_bytes[:-2] + b',\\\\n  \"firstBarRollbackMismatchEdit\": \"retained\"\\\\n}\\\\n'\n"
            "        shell.write_bytes(concurrent_bytes)\n"
            "        first_marker.write_bytes(concurrent_bytes)\n"
            "    exchange(directory_descriptor, temporary.name, shell.name)'''\n"
            "if first_needle in program:\n"
            "    program = program.replace(first_needle, first_injection, 1)\n"
            "second_marker = '# keyguide-atomic-bar-rollback-mismatch-before-abort'\n"
            "second_fallback = '            try:\\n                exchange(directory_descriptor, temporary.name, shell.name)'\n"
            "second_marker_injection = '''"
            f"        second_marker = Path({str(second)!r})\n"
            "        if second_marker.exists():\n"
            "            raise RuntimeError(\"second bar rollback edit already injected\")\n"
            "        current_bytes = shell.read_bytes()\n"
            "        if not current_bytes.endswith(b\"}\\\\n\"):\n"
            "            raise RuntimeError(\"test shell endpoint is not canonical JSON\")\n"
            "        concurrent_bytes = current_bytes[:-2] + b',\\\\n  \"secondBarRollbackMismatchEdit\": \"retained\"\\\\n}\\\\n'\n"
            "        shell.write_bytes(concurrent_bytes)\n"
            "        second_marker.write_bytes(concurrent_bytes)\n"
            "'''\n"
            "second_fallback_injection = '''"
            f"            second_marker = Path({str(second)!r})\n"
            "            if second_marker.exists():\n"
            "                raise RuntimeError(\"second bar rollback edit already injected\")\n"
            "            current_bytes = shell.read_bytes()\n"
            "            if not current_bytes.endswith(b\"}\\\\n\"):\n"
            "                raise RuntimeError(\"test shell endpoint is not canonical JSON\")\n"
            "            concurrent_bytes = current_bytes[:-2] + b',\\\\n  \"secondBarRollbackMismatchEdit\": \"retained\"\\\\n}\\\\n'\n"
            "            shell.write_bytes(concurrent_bytes)\n"
            "            second_marker.write_bytes(concurrent_bytes)\n"
            "'''\n"
            "if second_marker in program:\n"
            "    program = program.replace(second_marker, second_marker + '\\n' + second_marker_injection, 1)\n"
            "elif second_fallback in program:\n"
            "    program = program.replace(second_fallback, second_fallback_injection + second_fallback, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return first, second

    def inject_late_bar_rollback_absent_remove_replacement(
        self,
    ) -> tuple[Path, bytes]:
        """Replace an untrusted command-created shell at the remove boundary."""
        captured = self.fake_bin / "late-bar-rollback-absent-remove-replacement"
        replacement = (
            b'{\n'
            b'  "plugins": [],\n'
            b'  "bar": {"layout": {"left": [], "center": [], "right": []}},\n'
            b'  "concurrentReplacement": "retained"\n'
            b'}\n'
        )
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-bar-rollback-remove-observation-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            f"        replacement = bytes.fromhex({replacement.hex()!r})\n"
            "        shell.write_bytes(replacement)\n"
            f"        Path({str(captured)!r}).write_bytes(replacement)\n"
            "'''\n"
            "    program = program.replace(needle, needle + '\\n' + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured, replacement

    def inject_late_bar_rollback_absent_restore_creation(
        self,
    ) -> tuple[Path, bytes]:
        """Create a user shell after absent observation, before preimage restore."""
        captured = self.fake_bin / "late-bar-rollback-absent-restore-creation"
        replacement = (
            b'{\n'
            b'  "plugins": [],\n'
            b'  "bar": {"layout": {"left": [], "center": [], "right": []}},\n'
            b'  "concurrentCreation": "retained"\n'
            b'}\n'
        )
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-bar-rollback-restore-absence-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            f"        replacement = bytes.fromhex({replacement.hex()!r})\n"
            "        shell.write_bytes(replacement)\n"
            f"        Path({str(captured)!r}).write_bytes(replacement)\n"
            "'''\n"
            "    program = program.replace(needle, needle + '\\n' + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured, replacement

    def staged_bar_user_shell_bytes(self, kind: str) -> bytes:
        """Return deterministic live shell bytes for absent-preimage races."""
        if kind == "malformed":
            return b'{"plugins": ['
        include_keyguide = kind == "same"
        if kind not in {"same", "keyguide_less"}:
            raise AssertionError(f"unsupported staged bar race kind: {kind}")
        right = [{"id": "omarchy.agents"}]
        if include_keyguide:
            right.append({"id": PLUGIN_ID})
        right.append({"id": "omarchy.bluetooth"})
        document = {
            "plugins": [],
            "bar": {
                "layout": {
                    "left": [],
                    "center": [],
                    "right": right,
                }
            },
        }
        return (json.dumps(document, indent=2, ensure_ascii=False) + "\n").encode()

    def live_shell_before_staged_bar_env(
        self, replacement: bytes
    ) -> tuple[Path, dict[str, str]]:
        """Create a live shell after absent preflight but before staged command."""
        marker = self.fake_bin / "live-shell-before-staged-bar"
        return marker, {
            "KEYGUIDE_TEST_HOOK_LIVE_SHELL_BEFORE_STAGED_BAR": str(marker),
            "KEYGUIDE_TEST_HOOK_LIVE_SHELL_BEFORE_STAGED_BAR_HEX": (
                replacement.hex()
            ),
        }

    def inject_live_shell_at_staged_bar_publication(
        self, replacement: bytes
    ) -> Path:
        """Create a live shell after the last absent check before publication."""
        marker = self.fake_bin / "live-shell-at-staged-bar-publication"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            "needle = '# keyguide-atomic-staged-bar-publication-observation-checked'\n"
            "if needle in program and not marker.exists():\n"
            "    injection = '''\n"
            f"    replacement = bytes.fromhex({replacement.hex()!r})\n"
            "    live_shell.parent.mkdir(parents=True, exist_ok=True)\n"
            "    live_shell.write_bytes(replacement)\n"
            f"    Path({str(marker)!r}).write_bytes(replacement)\n"
            "'''\n"
            "    program = program.replace(needle, needle + '\\n' + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return marker

    def crash_staged_bar_publication(self, boundary: str) -> Path:
        """Hard-stop once at a staged absent-preimage bar boundary."""
        needles = {
            "staged": "# keyguide-staged-bar-output-journal-durable",
            "published": "# keyguide-staged-bar-publication-durable",
        }
        if boundary not in needles:
            raise AssertionError(f"unsupported staged bar boundary: {boundary}")
        marker = self.fake_bin / f"staged-bar-{boundary}-crashed"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(marker)!r})\n"
            f"needle = {needles[boundary]!r}\n"
            "if needle in program and not marker.exists():\n"
            "    position = program.index(needle)\n"
            "    line_start = program.rfind('\\n', 0, position) + 1\n"
            "    indentation = program[line_start:position]\n"
            "    injection = '\\n'.join(\n"
            "        indentation + line\n"
            "        for line in (\n"
            f"            \"__import__('pathlib').Path({str(marker)!r}).touch()\",\n"
            "            \"__import__('os')._exit(88)\",\n"
            "        )\n"
            "    )\n"
            "    program = program.replace(needle, needle + '\\n' + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return marker

    def inject_late_concurrent_shell_remove_edit(self) -> Path:
        """Edit an installer-created shell after its last removal check."""
        captured = self.fake_bin / "late-concurrent-shell-remove-edit"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"captured = Path({str(captured)!r})\n"
            "needle = '# keyguide-atomic-shell-remove-observation-checked'\n"
            "if needle in program and not captured.exists():\n"
            "    injection = '''\n"
            "            current_bytes = destination.read_bytes()\n"
            "            if not current_bytes.endswith(b\"}\\\\n\"):\n"
            "                raise RuntimeError(\"test shell endpoint is not canonical JSON\")\n"
            "            concurrent_bytes = current_bytes[:-2] + b',\\\\n  \"lateConcurrentEdit\": \"retained\"\\\\n}\\\\n'\n"
            "            destination.write_bytes(concurrent_bytes)\n"
            f"            Path({str(captured)!r}).write_bytes(concurrent_bytes)\n"
            "'''\n"
            "    program = program.replace(needle, needle + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)
        return captured

    def fail_manifest_write_after_shell_restore(self) -> None:
        """Make the next exact backup restore revoke manifest-directory writes."""
        failure_marker = self.fake_bin / "manifest-write-failed-after-restore"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import os\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(failure_marker)!r})\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "if (result.returncode == 0 "
            "and '# keyguide-atomic-shell-restore' in program "
            "and not marker.exists()):\n"
            "    marker.touch()\n"
            "    os.chmod(os.path.join(os.environ['HOME'], "
            "'.local/state/omarchy-keyguide'), 0o500)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)

    def fail_next_shell_restore_before_copy(self) -> None:
        """Fail one exact backup restore while leaving later retry available."""
        self.inject_atomic_shell_restore_fault("partial_stage")

    def fail_next_shell_backup_before_copy(self) -> None:
        """Fail one backup publication while leaving cleanup and retry available."""
        real_install = shutil.which("install")
        if real_install is None:
            raise AssertionError("install executable is unavailable")
        failure_marker = self.fake_bin / "backup-failed-once"
        fake_install = self.fake_bin / "install"
        fake_install.write_text(
            "#!/bin/sh\n"
            "case \"$*\" in\n"
            "  *shell.json*shell.json.pre-keyguide)\n"
            f"    if [ ! -f {shlex.quote(str(failure_marker))} ]; then\n"
            f"      touch {shlex.quote(str(failure_marker))}\n"
            "      exit 87\n"
            "    fi\n"
            "    ;;\n"
            "esac\n"
            f"exec {shlex.quote(real_install)} \"$@\"\n",
            encoding="utf-8",
        )
        fake_install.chmod(0o755)

    def inject_atomic_shell_restore_fault(
        self,
        fault: str,
        *,
        direct_install_fault: str | None = None,
    ) -> Path:
        """Fail one staged restore while recording every durability attempt."""
        failure_marker = self.fake_bin / f"atomic-restore-{fault}-failed"
        call_log = self.fake_bin / f"atomic-restore-{fault}-calls"
        python_wrapper = self.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "from pathlib import Path\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            f"marker = Path({str(failure_marker)!r})\n"
            f"call_log = Path({str(call_log)!r})\n"
            "if '# keyguide-atomic-shell-restore' in program:\n"
            "    with call_log.open('a', encoding='utf-8') as stream:\n"
            "        stream.write('restore\\n')\n"
            "    if not marker.exists():\n"
            "        marker.touch()\n"
            f"        fault = {fault!r}\n"
            "        if fault == 'partial_stage':\n"
            "            injection = '''\n"
            "_real_write = os.write\n"
            "def fail_partial_stage(descriptor, data):\n"
            "    _real_write(descriptor, data[:max(1, len(data) // 2)])\n"
            "    raise OSError('simulated partial staging write')\n"
            "os.write = fail_partial_stage\n"
            "'''\n"
            "        elif fault == 'parent_fsync':\n"
            "            injection = '''\n"
            "_real_fsync = os.fsync\n"
            "def fail_parent_fsync(descriptor):\n"
            "    if stat.S_ISDIR(os.fstat(descriptor).st_mode):\n"
            "        raise OSError('simulated shell parent fsync failure')\n"
            "    return _real_fsync(descriptor)\n"
            "os.fsync = fail_parent_fsync\n"
            "'''\n"
            "        else:\n"
            "            raise RuntimeError(f'unknown restore fault: {fault}')\n"
            "        program = program.replace('import tempfile\\n', "
            "'import tempfile\\n' + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, *sys.argv[1:]], "
            "input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)

        if direct_install_fault is not None:
            real_install = shutil.which("install")
            if real_install is None:
                raise AssertionError("install executable is unavailable")
            fake_install = self.fake_bin / "install"
            if direct_install_fault == "partial_live":
                restore_body = (
                    "    head -c 16 \"$2\" > \"$3\"\n"
                    "    chmod 0600 \"$3\"\n"
                    "    exit 88\n"
                )
            elif direct_install_fault == "wrong_mode":
                restore_body = (
                    f"    {shlex.quote(real_install)} \"$@\" || exit $?\n"
                    "    exit 88\n"
                )
            else:
                raise AssertionError(
                    f"unknown direct restore fault: {direct_install_fault}"
                )
            fake_install.write_text(
                "#!/bin/sh\n"
                "case \"$*\" in\n"
                "  *shell.json.pre-keyguide*shell.json)\n"
                + restore_body
                + "    ;;\n"
                "esac\n"
                f"exec {shlex.quote(real_install)} \"$@\"\n",
                encoding="utf-8",
            )
            fake_install.chmod(0o755)
        return call_log


class InstallManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.sandboxes: list[InstallSandbox | SimulatedUserInstall] = []

    def tearDown(self) -> None:
        for sandbox in reversed(self.sandboxes):
            sandbox.cleanup()

    def sandbox(self) -> InstallSandbox:
        sandbox = InstallSandbox()
        self.sandboxes.append(sandbox)
        return sandbox

    def simulated_user(
        self,
        *,
        plugin_enabled: bool | None,
        discovery_delay: int = 0,
        enable_exit: int = 0,
        break_manifest_after_enable: bool = False,
        break_manifest_after_bar_put: bool = False,
        bar_put_mode: str = "anchored",
        enable_auto_insert: str | None = None,
        disable_rewrites_shell_then_fails: bool = False,
        restart_fail_on_call: int | None = None,
    ) -> SimulatedUserInstall:
        sandbox = SimulatedUserInstall(
            plugin_enabled=plugin_enabled,
            discovery_delay=discovery_delay,
            enable_exit=enable_exit,
            break_manifest_after_enable=break_manifest_after_enable,
            break_manifest_after_bar_put=break_manifest_after_bar_put,
            bar_put_mode=bar_put_mode,
            enable_auto_insert=enable_auto_insert,
            disable_rewrites_shell_then_fails=disable_rewrites_shell_then_fails,
            restart_fail_on_call=restart_fail_on_call,
        )
        self.sandboxes.append(sandbox)
        return sandbox

    def assert_command_succeeded(
        self, result: subprocess.CompletedProcess[str]
    ) -> None:
        self.assertEqual(0, result.returncode, result.stdout)

    def prepare_pre_executable_picker_install(
        self,
        sandbox: SimulatedUserInstall,
    ) -> tuple[bytes, bytes]:
        """Recreate the exact live fileset immediately before the picker shipped."""
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        baseline_shell = sandbox.shell_json.read_bytes()
        self.assert_command_succeeded(sandbox.run_make("install"))
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        historical_new_only = (
            BOUNDED_PROCESS_RELATIVE_PATH,
            EXECUTABLE_PICKER_RELATIVE_PATH,
            *LOCALIZED_SEARCH_RELATIVE_PATHS,
        )
        for relative in historical_new_only:
            path = sandbox.home / relative
            path.unlink()
            document["owned_files"].remove(str(path))
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n",
            encoding="utf-8",
        )
        return baseline_shell, sandbox.shell_json.read_bytes()

    def prepare_live_retained_visibility_restart_pending(
        self,
        sandbox: SimulatedUserInstall,
    ) -> tuple[dict[str, object], bytes]:
        """Recreate the sanitized live retry state for a retained JS handoff."""
        sandbox.prepare_retained_clock_edit(
            legacy_new_only=(
                BOUNDED_PROCESS_RELATIVE_PATH,
                VISIBILITY_MODEL_RELATIVE_PATH,
                SHORTCUTS_RELATIVE_PATH,
                SHORTCUT_EDIT_ROW_RELATIVE_PATH,
                EXECUTABLE_PICKER_RELATIVE_PATH,
            )
        )
        self.assert_command_succeeded(
            sandbox.run_preserve_uninstall_to_upgrade_ready()
        )
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("upgrade_ready", document["install_state"])
        handoff = document["upgrade_handoff"]
        self.assertIsInstance(handoff, dict)
        reservations = handoff["reservations"]
        visibility_reservations = [
            reservation
            for reservation in reservations
            if reservation["path"] == str(sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH)
        ]
        self.assertEqual(1, len(visibility_reservations))
        reservation = visibility_reservations[0]
        for other in reservations:
            if other is reservation:
                continue
            Path(other["path"]).unlink(missing_ok=True)
            Path(other["temporary_path"]).unlink(missing_ok=True)
        handoff["reservations"] = [reservation]
        temporary = Path(reservation["temporary_path"])
        visibility_model = sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH
        old_visibility_model = visibility_model.read_bytes()
        visibility_model.chmod(0o600)
        temporary.unlink(missing_ok=True)
        document["install_state"] = "restart_pending"
        document["owned_files"] = []
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n",
            encoding="utf-8",
        )
        return document, old_visibility_model

    def test_live_install_lock_states_defer_before_first_mutation(self) -> None:
        """A locked or indeterminate live session must not start installation."""
        lock_cases = (
            ("compositor locked", {"FAKE_LOCK_PROBE_EXIT": "0"}),
            ("compositor undetermined", {"FAKE_LOCK_PROBE_EXIT": "2"}),
            (
                "lock requested",
                {
                    "FAKE_LOCK_STATUS_JSON": (
                        '{"requested":true,"pending":false,'
                        '"sessionLocked":false,"secure":false}'
                    )
                },
            ),
            (
                "lock pending",
                {
                    "FAKE_LOCK_STATUS_JSON": (
                        '{"requested":false,"pending":true,'
                        '"sessionLocked":false,"secure":false}'
                    )
                },
            ),
            (
                "session locked",
                {
                    "FAKE_LOCK_STATUS_JSON": (
                        '{"requested":false,"pending":false,'
                        '"sessionLocked":true,"secure":false}'
                    )
                },
            ),
            (
                "secure lock",
                {
                    "FAKE_LOCK_STATUS_JSON": (
                        '{"requested":false,"pending":false,'
                        '"sessionLocked":false,"secure":true}'
                    )
                },
            ),
            ("malformed lock status", {"FAKE_LOCK_STATUS_JSON": "not json"}),
            ("lock status failure", {"FAKE_LOCK_STATUS_EXIT": "97"}),
        )
        retry_message = (
            "install: Omarchy session lock is active or undetermined; "
            "no live changes were made; retry after unlock"
        )
        watched_commands = {
            f"plugin enable {PLUGIN_ID}",
            f"plugin disable {PLUGIN_ID}",
            f"bar put {PLUGIN_ID} --after omarchy.agents",
            "shell shell rescanPlugins",
            "restart shell",
        }

        for label, environment in lock_cases:
            with self.subTest(label=label):
                sandbox = self.simulated_user(plugin_enabled=False)
                before = sandbox.lock_sensitive_snapshot()
                commands_before = sandbox.commands()

                result = sandbox.run_install_script(extra_env=environment)

                self.assertEqual(75, result.returncode, result.stdout)
                self.assertIn(retry_message, result.stdout)
                self.assertEqual(before, sandbox.lock_sensitive_snapshot())
                commands_after = sandbox.commands()
                self.assertFalse(
                    watched_commands & set(commands_after[len(commands_before) :])
                )

    def test_live_install_rejects_nonboolean_lock_status_when_python_optimized(
        self,
    ) -> None:
        """Optimized Python must not remove the lock-status type gate."""
        sandbox = self.simulated_user(plugin_enabled=False)
        before = sandbox.lock_sensitive_snapshot()

        result = sandbox.run_install_script(
            extra_env={
                "PYTHONOPTIMIZE": "1",
                "FAKE_LOCK_STATUS_JSON": (
                    '{"requested":0,"pending":0,'
                    '"sessionLocked":0,"secure":0}'
                ),
            }
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn(
            "install: Omarchy session lock is active or undetermined; "
            "no live changes were made; retry after unlock",
            result.stdout,
        )
        self.assertEqual(before, sandbox.lock_sensitive_snapshot())

    def test_locked_live_install_defers_uninstall_restart_pending_unchanged(
        self,
    ) -> None:
        """An interrupted uninstall must hit the live gate before collision errors."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.assert_command_succeeded(sandbox.run_make("install"))
        sandbox.lock_probe_count.unlink()
        interrupted = sandbox.run_uninstall_script(
            extra_env={"FAKE_LOCK_PROBE_LOCK_ON_CALL": "4"}
        )
        self.assertEqual(75, interrupted.returncode, interrupted.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("restart_pending", document["install_state"])
        self.assertFalse(document["plugin_enabled_by_installer"])
        self.assertEqual([], document["owned_files"])
        before = sandbox.lock_sensitive_snapshot()
        commands_before = sandbox.commands()

        result = sandbox.run_install_script(
            extra_env={"FAKE_LOCK_PROBE_EXIT": "0"}
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn(
            "install: Omarchy session lock is active or undetermined; "
            "no live changes were made; retry after unlock",
            result.stdout,
        )
        self.assertEqual(before, sandbox.lock_sensitive_snapshot())
        self.assertEqual(commands_before, sandbox.commands())

    def test_locked_preserve_upgrade_defers_installed_recovery_unchanged(
        self,
    ) -> None:
        """An installed manifest must not enter recursive recovery while locked."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.assert_command_succeeded(sandbox.run_make("install"))
        before = sandbox.lock_sensitive_snapshot()
        commands_before = sandbox.commands()

        result = sandbox.run_install_script(
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "FAKE_LOCK_PROBE_EXIT": "0",
            }
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn(
            "install: Omarchy session lock is active or undetermined; "
            "no live changes were made; retry after unlock",
            result.stdout,
        )
        self.assertEqual(before, sandbox.lock_sensitive_snapshot())
        self.assertEqual(commands_before, sandbox.commands())

    def test_locked_preserve_upgrade_defers_restart_pending_recovery_unchanged(
        self,
    ) -> None:
        """A restart-pending handoff must remain exactly recoverable while locked."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.prepare_live_retained_visibility_restart_pending(sandbox)
        before = sandbox.lock_sensitive_snapshot()
        commands_before = sandbox.commands()

        result = sandbox.run_install_script(
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "FAKE_LOCK_PROBE_EXIT": "0",
            }
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn(
            "install: Omarchy session lock is active or undetermined; "
            "no live changes were made; retry after unlock",
            result.stdout,
        )
        self.assertEqual(before, sandbox.lock_sensitive_snapshot())
        self.assertEqual(commands_before, sandbox.commands())

    def test_preserve_upgrade_preserves_nested_lock_deferral_status(self) -> None:
        """A lock race at recursive uninstall must propagate retry status 75."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        sandbox.lock_probe_count.unlink()
        before = sandbox.lock_sensitive_snapshot()
        commands_before = sandbox.commands()

        result = sandbox.run_install_script(
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "FAKE_LOCK_PROBE_LOCK_ON_CALL": "2",
            }
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn("no live changes were made; retry after unlock", result.stdout)
        self.assertEqual(before, sandbox.lock_sensitive_snapshot())
        self.assertEqual(commands_before, sandbox.commands())

    def test_live_uninstall_lock_states_defer_before_first_mutation(self) -> None:
        """A locked or indeterminate live session must not start removal."""
        lock_cases = (
            ("compositor locked", {"FAKE_LOCK_PROBE_EXIT": "0"}),
            ("compositor undetermined", {"FAKE_LOCK_PROBE_EXIT": "2"}),
            (
                "lock requested",
                {
                    "FAKE_LOCK_STATUS_JSON": (
                        '{"requested":true,"pending":false,'
                        '"sessionLocked":false,"secure":false}'
                    )
                },
            ),
            (
                "lock pending",
                {
                    "FAKE_LOCK_STATUS_JSON": (
                        '{"requested":false,"pending":true,'
                        '"sessionLocked":false,"secure":false}'
                    )
                },
            ),
            (
                "session locked",
                {
                    "FAKE_LOCK_STATUS_JSON": (
                        '{"requested":false,"pending":false,'
                        '"sessionLocked":true,"secure":false}'
                    )
                },
            ),
            (
                "secure lock",
                {
                    "FAKE_LOCK_STATUS_JSON": (
                        '{"requested":false,"pending":false,'
                        '"sessionLocked":false,"secure":true}'
                    )
                },
            ),
            ("malformed lock status", {"FAKE_LOCK_STATUS_JSON": "not json"}),
            ("lock status failure", {"FAKE_LOCK_STATUS_EXIT": "97"}),
        )
        retry_message = (
            "uninstall: Omarchy session lock is active or undetermined; "
            "no live changes were made; retry after unlock"
        )
        watched_commands = {
            f"plugin enable {PLUGIN_ID}",
            f"plugin disable {PLUGIN_ID}",
            f"bar put {PLUGIN_ID} --after omarchy.agents",
            "shell shell rescanPlugins",
            "restart shell",
        }
        sandbox = self.simulated_user(plugin_enabled=False)
        self.assert_command_succeeded(sandbox.run_make("install"))

        for label, environment in lock_cases:
            with self.subTest(label=label):
                before = sandbox.lock_sensitive_snapshot()
                commands_before = sandbox.commands()

                result = sandbox.run_uninstall_script(extra_env=environment)

                self.assertEqual(75, result.returncode, result.stdout)
                self.assertIn(retry_message, result.stdout)
                self.assertEqual(before, sandbox.lock_sensitive_snapshot())
                commands_after = sandbox.commands()
                self.assertFalse(
                    watched_commands & set(commands_after[len(commands_before) :])
                )

    def test_live_install_rechecks_lock_before_payload_publication(self) -> None:
        """A lock acquired after preflight must stop before payload publication."""
        sandbox = self.simulated_user(plugin_enabled=False)
        before = sandbox.lock_sensitive_snapshot()
        commands_before = sandbox.commands()

        result = sandbox.run_install_script(
            extra_env={"FAKE_LOCK_PROBE_LOCK_ON_CALL": "2"}
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn(
            "install: Omarchy session lock is active or undetermined; "
            "no live changes were made; retry after unlock",
            result.stdout,
        )
        self.assertTrue(sandbox.manifest.exists())
        self.assert_command_succeeded(
            sandbox.run_uninstall_script(
                extra_env={"KEYGUIDE_VALIDATE_ONLY": "1"}
            )
        )
        after = sandbox.lock_sensitive_snapshot()
        for endpoint in ("shell", "plugin", "installed"):
            self.assertEqual(before[endpoint], after[endpoint], endpoint)
        self.assertFalse(
            {
                f"plugin enable {PLUGIN_ID}",
                f"bar put {PLUGIN_ID} --after omarchy.agents",
                "shell shell rescanPlugins",
                "restart shell",
            }
            & set(sandbox.commands()[len(commands_before) :])
        )

    def test_live_install_rechecks_lock_immediately_before_plugin_rescan(
        self,
    ) -> None:
        """A lock acquired after payload publication must prevent the rescan."""
        sandbox = self.simulated_user(plugin_enabled=False)

        result = sandbox.run_install_script(
            extra_env={"FAKE_LOCK_PROBE_LOCK_ON_CALL": "3"}
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn("no live changes were made; retry after unlock", result.stdout)
        self.assertEqual("3", sandbox.lock_probe_count.read_text().strip())
        self.assertNotIn("shell shell rescanPlugins", sandbox.commands())
        self.assertFalse(sandbox.shell_json.exists())
        self.assert_command_succeeded(
            sandbox.run_uninstall_script(
                extra_env={"KEYGUIDE_VALIDATE_ONLY": "1"}
            )
        )

    def test_live_install_rechecks_lock_before_absent_bar_publication(
        self,
    ) -> None:
        """A staged default shell must not publish after a lock race."""
        sandbox = self.simulated_user(plugin_enabled=False)

        result = sandbox.run_install_script(
            extra_env={"FAKE_LOCK_PROBE_LOCK_ON_CALL": "4"}
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn("no live changes were made; retry after unlock", result.stdout)
        self.assertEqual("4", sandbox.lock_probe_count.read_text().strip())
        self.assertIn("shell shell rescanPlugins", sandbox.commands())
        self.assertFalse(sandbox.shell_json.exists())
        self.assertNotIn(f"plugin enable {PLUGIN_ID}", sandbox.commands())
        self.assert_command_succeeded(
            sandbox.run_uninstall_script(
                extra_env={"KEYGUIDE_VALIDATE_ONLY": "1"}
            )
        )

    def test_live_install_rechecks_lock_before_existing_bar_publication(
        self,
    ) -> None:
        """A pre-existing shell must remain unchanged when placement is deferred."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original_shell = sandbox.shell_json.read_bytes()

        result = sandbox.run_install_script(
            extra_env={"FAKE_LOCK_PROBE_LOCK_ON_CALL": "4"}
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn("no live changes were made; retry after unlock", result.stdout)
        self.assertEqual("4", sandbox.lock_probe_count.read_text().strip())
        self.assertEqual(original_shell, sandbox.shell_json.read_bytes())
        self.assertNotIn(
            f"bar put {PLUGIN_ID} --after omarchy.agents",
            sandbox.commands(),
        )
        self.assert_command_succeeded(
            sandbox.run_uninstall_script(
                extra_env={"KEYGUIDE_VALIDATE_ONLY": "1"}
            )
        )

    def test_live_install_rechecks_lock_before_enable_inserted_bar_rewrite(
        self,
    ) -> None:
        """A lock must preserve an enable-inserted placement before canonicalization."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.prepare_live_retained_visibility_restart_pending(sandbox)
        sandbox._write_fake_omarchy(
            False,
            discovery_delay=0,
            enable_exit=0,
            enable_auto_insert="before_agents",
            break_manifest_after_enable=False,
            break_manifest_after_bar_put=False,
            bar_put_mode="anchored",
            disable_rewrites_shell_then_fails=False,
            restart_fail_on_call=None,
        )
        sandbox.lock_probe_count.unlink()
        commands_before = sandbox.commands()

        result = sandbox.run_install_script(
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "FAKE_LOCK_PROBE_LOCK_ON_CALL": "9",
            }
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn("no live changes were made; retry after unlock", result.stdout)
        self.assertEqual("9", sandbox.lock_probe_count.read_text().strip())
        self.assertEqual(
            [PLUGIN_ID, "omarchy.agents", "omarchy.bluetooth"],
            sandbox.widget_order(),
        )
        self.assertEqual(
            f"plugin enable {PLUGIN_ID}",
            sandbox.commands()[len(commands_before) :][-1],
        )
        interrupted = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        handoff = interrupted["upgrade_handoff"]
        self.assert_command_succeeded(
            sandbox.run_uninstall_script(
                args=[item["path"] for item in handoff["reservations"]],
                extra_env={
                    "KEYGUIDE_VALIDATE_ONLY": "1",
                    "KEYGUIDE_PRESERVE_UPGRADE": "1",
                    "KEYGUIDE_EXPECTED_PLUGIN_WAS_ENABLED": "false",
                    "KEYGUIDE_UPGRADE_HANDOFF_TOKEN": handoff["token"],
                    "REMOVE_PREFERENCES": "0",
                },
            )
        )

    def test_live_install_rechecks_lock_immediately_before_plugin_enable(
        self,
    ) -> None:
        """A lock after bar publication must prevent plugin enablement."""
        sandbox = self.simulated_user(plugin_enabled=False)

        result = sandbox.run_install_script(
            extra_env={"FAKE_LOCK_PROBE_LOCK_ON_CALL": "5"}
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn("no live changes were made; retry after unlock", result.stdout)
        self.assertEqual("5", sandbox.lock_probe_count.read_text().strip())
        self.assertTrue(sandbox.shell_json.exists())
        self.assertFalse(sandbox.enabled_state.exists())
        self.assertNotIn(f"plugin enable {PLUGIN_ID}", sandbox.commands())
        self.assertNotIn("restart shell", sandbox.commands())
        self.assert_command_succeeded(
            sandbox.run_uninstall_script(
                extra_env={"KEYGUIDE_VALIDATE_ONLY": "1"}
            )
        )

    def test_live_install_rechecks_lock_immediately_before_restart(self) -> None:
        """A lock acquired after enablement must prevent the shell restart."""
        sandbox = self.simulated_user(plugin_enabled=False)

        result = sandbox.run_install_script(
            extra_env={"FAKE_LOCK_PROBE_LOCK_ON_CALL": "6"}
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn("no live changes were made; retry after unlock", result.stdout)
        self.assertEqual("6", sandbox.lock_probe_count.read_text().strip())
        self.assertTrue(sandbox.enabled_state.exists())
        self.assertIn(f"plugin enable {PLUGIN_ID}", sandbox.commands())
        self.assertNotIn("restart shell", sandbox.commands())
        self.assertEqual(
            "installed",
            json.loads(sandbox.manifest.read_text(encoding="utf-8"))[
                "install_state"
            ],
        )
        self.assert_command_succeeded(
            sandbox.run_uninstall_script(
                extra_env={"KEYGUIDE_VALIDATE_ONLY": "1"}
            )
        )

    def test_live_uninstall_rechecks_lock_before_shell_restoration(self) -> None:
        """A lock acquired after validation must stop before shell restoration."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.assert_command_succeeded(sandbox.run_make("install"))
        sandbox.lock_probe_count.unlink()
        before = sandbox.lock_sensitive_snapshot()
        commands_before = sandbox.commands()

        result = sandbox.run_uninstall_script(
            extra_env={"FAKE_LOCK_PROBE_LOCK_ON_CALL": "2"}
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn(
            "uninstall: Omarchy session lock is active or undetermined; "
            "no live changes were made; retry after unlock",
            result.stdout,
        )
        self.assertTrue(sandbox.manifest.exists())
        self.assert_command_succeeded(
            sandbox.run_uninstall_script(
                extra_env={"KEYGUIDE_VALIDATE_ONLY": "1"}
            )
        )
        after = sandbox.lock_sensitive_snapshot()
        for endpoint in ("shell", "plugin", "installed"):
            self.assertEqual(before[endpoint], after[endpoint], endpoint)
        self.assertFalse(
            {
                f"plugin disable {PLUGIN_ID}",
                "restart shell",
            }
            & set(sandbox.commands()[len(commands_before) :])
        )

    def test_live_uninstall_rechecks_lock_before_final_restart(self) -> None:
        """A lock after removal must defer the final shell restart for retry."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.assert_command_succeeded(sandbox.run_make("install"))
        sandbox.lock_probe_count.unlink()
        commands_before = sandbox.commands()

        result = sandbox.run_uninstall_script(
            extra_env={"FAKE_LOCK_PROBE_LOCK_ON_CALL": "4"}
        )

        self.assertEqual(75, result.returncode, result.stdout)
        self.assertIn(
            "uninstall: Omarchy session lock is active or undetermined; "
            "no live changes were made; retry after unlock",
            result.stdout,
        )
        self.assertNotIn(
            "restart shell", sandbox.commands()[len(commands_before) :]
        )
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("restart_pending", document["install_state"])
        self.assertFalse(document["plugin_enabled_by_installer"])
        self.assertEqual([], document["owned_files"])

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.manifest.exists())
        self.assertEqual(2, sandbox.commands().count("restart shell"))

    def test_uninstall_removes_only_manifest_owned_paths(self) -> None:
        """A broad removal would destroy unrelated Omarchy user data."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        unrelated = sandbox.home / ".config/omarchy/keep-me"
        unrelated.parent.mkdir(parents=True, exist_ok=True)
        unrelated.write_text("owned by user", encoding="utf-8")

        self.assert_command_succeeded(sandbox.uninstall())

        self.assertEqual("owned by user", unrelated.read_text(encoding="utf-8"))
        self.assertFalse(sandbox.manifest.exists())
        self.assertEqual(
            sandbox.preexisting_snapshot(),
            sandbox.final_snapshot(exclude={unrelated}),
        )

    def test_uninstall_preserves_concurrent_owned_program_replacement(self) -> None:
        """A path replacement after observation must never be unlinked."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        target = sandbox.home / OWNED_RELATIVE_PATHS[0]
        captured, replacement = sandbox.inject_concurrent_owned_program_replacement()

        result = sandbox.uninstall()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("owned path changed during atomic removal", result.stdout)
        self.assertTrue(captured.is_file())
        self.assertEqual(replacement, captured.read_bytes())
        self.assertEqual(replacement, target.read_bytes())
        self.assertTrue(sandbox.manifest.exists())

    def test_uninstall_preserves_concurrent_owned_program_symlink(self) -> None:
        """A symlink replacement must be rolled back without following it."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        target = sandbox.home / OWNED_RELATIVE_PATHS[0]
        marker, link_target = sandbox.inject_concurrent_owned_program_nonregular(
            "symlink"
        )

        result = sandbox.uninstall()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("owned path changed during atomic removal", result.stdout)
        self.assertTrue(marker.is_file())
        self.assertTrue(target.is_symlink())
        self.assertEqual(str(link_target), os.readlink(target))
        self.assertEqual(b"user-owned symlink target\n", link_target.read_bytes())
        self.assertTrue(sandbox.manifest.exists())

    def test_uninstall_preserves_concurrent_owned_program_fifo_without_blocking(
        self,
    ) -> None:
        """A FIFO replacement must be rejected without opening it in blocking mode."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        target = sandbox.home / OWNED_RELATIVE_PATHS[0]
        marker, _ = sandbox.inject_concurrent_owned_program_nonregular("fifo")

        result = sandbox.run_make("uninstall", timeout=5)

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("owned path changed during atomic removal", result.stdout)
        self.assertTrue(marker.is_file())
        self.assertTrue(stat.S_ISFIFO(target.lstat().st_mode))
        self.assertTrue(sandbox.manifest.exists())

    def test_uninstall_recovers_a_journaled_owned_program_capture(self) -> None:
        """A hard stop after rename must be recoverable without pathname guessing."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        target = sandbox.home / OWNED_RELATIVE_PATHS[0]
        original = target.read_bytes()
        marker = sandbox.fail_after_first_owned_program_capture()

        first = sandbox.uninstall()

        self.assertNotEqual(0, first.returncode, first.stdout)
        self.assertTrue(marker.is_file())
        self.assertFalse(target.exists())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        journal = document.get("file_removal")
        self.assertIsInstance(journal, dict)
        token = journal["token"]
        quarantine = target.with_name(
            f".{target.name}.keyguide-remove-{token}.pending"
        )
        self.assertEqual(original, quarantine.read_bytes())

        self.assert_command_succeeded(sandbox.uninstall())
        self.assertFalse(sandbox.manifest.exists())
        self.assertFalse(target.exists())
        self.assertFalse(quarantine.exists())

    def test_install_records_every_created_file_and_skips_live_commands(self) -> None:
        """Omitting a copied file from the manifest would leave it behind."""
        sandbox = self.sandbox()
        bindings = sandbox.home / ".config/hypr/bindings.lua"
        bindings.parent.mkdir(parents=True)
        bindings.write_text("-- user bindings\n", encoding="utf-8")

        self.assert_command_succeeded(sandbox.install())

        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual(1, document["schema_version"])
        self.assertEqual(
            {str(path) for path in sandbox.owned_paths()},
            set(document["owned_files"]),
        )
        self.assertFalse(document["plugin_was_enabled"])
        self.assertFalse(document["plugin_enabled_by_installer"])
        for path in sandbox.owned_paths():
            self.assertTrue(path.is_file(), str(path))
        self.assertEqual(
            0o755,
            stat.S_IMODE(
                (sandbox.home / OWNED_RELATIVE_PATHS[0]).stat().st_mode
            ),
        )
        self.assertEqual("-- user bindings\n", bindings.read_text(encoding="utf-8"))
        self.assertFalse(sandbox.command_log.exists())

    def test_icon_is_an_exact_owned_copy_and_desktop_entry_uses_its_name(self) -> None:
        """A missing or substituted icon would split the app's visual identity."""
        source = REPOSITORY / "assets/omarchy-keyguide.svg"
        self.assertTrue(source.is_file(), str(source))
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())

        installed = sandbox.home / ICON_RELATIVE_PATH
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertIn(str(installed), document["owned_files"])
        self.assertEqual(source.read_bytes(), installed.read_bytes())
        self.assertEqual(0o644, stat.S_IMODE(installed.stat().st_mode))

        desktop = sandbox.home / OWNED_RELATIVE_PATHS[-1]
        self.assertIn(
            "Icon=omarchy-keyguide",
            desktop.read_text(encoding="utf-8").splitlines(),
        )

        self.assert_command_succeeded(sandbox.uninstall())
        self.assertFalse(installed.exists())

    def test_installed_backend_cli_loads_its_runtime_dependencies(self) -> None:
        """Omitted backend modules would make the installed service commands fail."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        omarchy_fixture = (
            REPOSITORY / "tests/fixtures/omarchy-keybindings.txt"
        ).read_text(encoding="utf-8")
        hyprctl_fixture = (
            REPOSITORY / "tests/fixtures/hyprctl-binds.txt"
        ).read_text(encoding="utf-8")
        (sandbox.fake_bin / "omarchy").write_text(
            "#!/bin/sh\n" + f"printf '%s' {shlex.quote(omarchy_fixture)}\n",
            encoding="utf-8",
        )
        (sandbox.fake_bin / "hyprctl").write_text(
            "#!/bin/sh\n"
            "case \"$*\" in\n"
            + f"  binds) printf '%s' {shlex.quote(hyprctl_fixture)} ;;\n"
            + "  'getoption input:kb_layout -j') "
            "printf '%s' '{\"str\":\"us\"}' ;;\n"
            + "  'getoption input:kb_rules -j'|"
            "'getoption input:kb_model -j'|"
            "'getoption input:kb_variant -j'|"
            "'getoption input:kb_options -j') "
            "printf '%s' '{\"str\":\"\"}' ;;\n"
            + "  *) exit 64 ;;\n"
            "esac\n",
            encoding="utf-8",
        )
        xkb_fixture = """\
xkb_keymap {
xkb_keycodes "test" {
    <AE01> = 10;
    <AD10> = 33;
};
xkb_symbols "test" {
    key <AE01> { [ 1, exclam ] };
    key <AD10> { [ p, P ] };
};
};
"""
        (sandbox.fake_bin / "xkbcli").write_text(
            "#!/bin/sh\n"
            "[ \"$*\" = 'compile-keymap --layout us' ] || exit 64\n"
            + f"printf '%s' {shlex.quote(xkb_fixture)}\n",
            encoding="utf-8",
        )
        for command in ("omarchy", "hyprctl", "xkbcli"):
            (sandbox.fake_bin / command).chmod(0o755)
        environment = {
            **sandbox.command_environment(),
            "HOME": str(sandbox.home),
            "XDG_STATE_HOME": str(sandbox.home / ".local/state"),
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONNOUSERSITE": "1",
            "PYTHONPATH": str(
                sandbox.home / ".local/lib/omarchy-keyguide"
            ),
        }

        outputs = []
        for arguments in (
            ("settings", "get"),
            ("bindings", "--json"),
            ("shortcuts", "status"),
        ):
            result = subprocess.run(
                [sys.executable, "-m", "keyguide_backend", *arguments],
                cwd=sandbox.root,
                env=environment,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            self.assert_command_succeeded(result)
            outputs.append(json.loads(result.stdout))

        self.assertEqual(2, outputs[0]["version"])
        self.assertGreater(len(outputs[1]), 0)
        self.assertEqual(0, outputs[2]["managedCount"])
        self.assertFalse(
            (
                sandbox.home
                / ".local/lib/omarchy-keyguide/keyguide_backend/__pycache__"
            ).exists()
        )

    def test_install_refuses_to_overwrite_an_unowned_target(self) -> None:
        """Overwriting a pre-existing destination would falsely claim ownership."""
        sandbox = self.sandbox()
        desktop = sandbox.home / OWNED_RELATIVE_PATHS[-1]
        desktop.parent.mkdir(parents=True)
        desktop.write_text("user desktop entry\n", encoding="utf-8")

        result = sandbox.install()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("refusing to overwrite unowned path", result.stdout)
        self.assertEqual("user desktop entry\n", desktop.read_text(encoding="utf-8"))
        self.assertFalse(sandbox.manifest.exists())
        self.assertFalse((sandbox.home / OWNED_RELATIVE_PATHS[0]).exists())

    def test_install_rejects_a_manifest_parent_symlink_outside_target_home(self) -> None:
        """Following a state-directory symlink could write outside PREFIX_ROOT."""
        sandbox = self.sandbox()
        escaped_state = sandbox.root.parent / "escaped-state"
        escaped_state.mkdir()
        state_parent = sandbox.home / ".local"
        state_parent.mkdir(parents=True)
        (state_parent / "state").symlink_to(escaped_state, target_is_directory=True)

        result = sandbox.install()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("manifest path escapes target home", result.stdout)
        self.assertFalse((escaped_state / "omarchy-keyguide").exists())
        self.assertFalse((sandbox.home / OWNED_RELATIVE_PATHS[0]).exists())

    def test_install_rejects_an_in_home_symlinked_destination_parent(self) -> None:
        """Accepting a parent symlink that uninstall rejects would strand files."""
        sandbox = self.sandbox()
        local_directory = sandbox.home / ".local"
        local_directory.mkdir(parents=True)
        actual_lib = local_directory / "actual-lib"
        actual_lib.mkdir()
        (local_directory / "lib").symlink_to(actual_lib, target_is_directory=True)

        result = sandbox.install()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("symlinked destination component", result.stdout)
        self.assertFalse(sandbox.manifest.exists())
        self.assertFalse((actual_lib / "omarchy-keyguide").exists())

    def test_manifest_temp_symlink_cannot_overwrite_an_unrelated_file(self) -> None:
        """Following a fixed manifest temp symlink would truncate its victim."""
        sandbox = self.sandbox()
        state_directory = sandbox.manifest.parent
        state_directory.mkdir(parents=True)
        victim = sandbox.root / "manifest-temp-victim.txt"
        victim.write_text("unrelated bytes\n", encoding="utf-8")
        fixed_temporary = state_directory / ".install-manifest.json.tmp"
        fixed_temporary.symlink_to(victim)

        self.assert_command_succeeded(sandbox.install())

        self.assertEqual("unrelated bytes\n", victim.read_text(encoding="utf-8"))
        self.assertTrue(fixed_temporary.is_symlink())

    def test_partial_copy_keeps_a_manifest_for_exact_recovery(self) -> None:
        """A copy failure without a journal would strand unowned runtime files."""
        sandbox = self.sandbox()
        plugin_directory = sandbox.home / ".config/omarchy/plugins/mrai.keyguide"
        plugin_directory.mkdir(parents=True)
        plugin_directory.chmod(0o500)

        result = sandbox.install()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(sandbox.manifest.exists())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installing", document.get("install_state"))
        self.assertTrue((sandbox.home / OWNED_RELATIVE_PATHS[0]).exists())
        self.assert_command_succeeded(sandbox.uninstall())
        self.assertFalse(sandbox.manifest.exists())
        self.assertFalse((sandbox.home / OWNED_RELATIVE_PATHS[0]).exists())

    def test_recovery_does_not_claim_a_destination_never_reserved(self) -> None:
        """A planned but uncreated path must remain user-owned after failure."""
        sandbox = self.sandbox()
        plugin_directory = sandbox.home / ".config/omarchy/plugins/mrai.keyguide"
        plugin_directory.mkdir(parents=True)
        plugin_directory.chmod(0o500)
        self.assertNotEqual(0, sandbox.install().returncode)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            str(plugin_directory / "manifest.json"),
            document.get("pending_reservation", {}).get("path"),
        )
        plugin_directory.chmod(0o700)
        user_file = plugin_directory / "manifest.json"
        user_file.write_text("created after failed install\n", encoding="utf-8")

        self.assert_command_succeeded(sandbox.uninstall())

        self.assertTrue(user_file.exists())
        self.assertEqual(
            "created after failed install\n",
            user_file.read_text(encoding="utf-8"),
        )

    def test_recovery_removes_a_verified_pending_reservation(self) -> None:
        """A token-matching placeholder remains installer-owned after a crash."""
        sandbox = self.sandbox()
        plugin_directory = sandbox.home / ".config/omarchy/plugins/mrai.keyguide"
        plugin_directory.mkdir(parents=True)
        plugin_directory.chmod(0o500)
        self.assertNotEqual(0, sandbox.install().returncode)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        pending = document.get("pending_reservation")
        self.assertIsInstance(pending, dict)
        plugin_directory.chmod(0o700)
        reservation = Path(pending["path"])
        reservation.write_text(pending["token"], encoding="utf-8")
        reservation.chmod(0o600)

        self.assert_command_succeeded(sandbox.uninstall())

        self.assertFalse(reservation.exists())
        self.assertFalse(sandbox.manifest.exists())

    def test_recovery_preserves_unverified_staging_file_and_blocks_cleanup(
        self,
    ) -> None:
        """A recorded name cannot authenticate a later user-created file."""
        sandbox = self.sandbox()
        plugin_directory = sandbox.home / ".config/omarchy/plugins/mrai.keyguide"
        plugin_directory.mkdir(parents=True)
        plugin_directory.chmod(0o500)
        self.assertNotEqual(0, sandbox.install().returncode)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        pending = document.get("pending_reservation")
        self.assertIsInstance(pending, dict)
        plugin_directory.chmod(0o700)
        reservation = Path(pending["path"])
        staging = Path(pending["temporary_path"])
        self.assertFalse(staging.exists())
        staging.write_text("created later by user\n", encoding="utf-8")
        first_owned = sandbox.home / OWNED_RELATIVE_PATHS[0]

        self.assertFalse(reservation.exists())
        result = sandbox.uninstall()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("staging file does not match reservation token", result.stdout)
        self.assertEqual(
            "created later by user\n",
            staging.read_text(encoding="utf-8"),
        )
        self.assertTrue(first_owned.exists())
        self.assertTrue(sandbox.manifest.exists())
        staging.unlink()
        self.assert_command_succeeded(sandbox.uninstall())
        self.assertFalse(sandbox.manifest.exists())

    def test_recovery_rejects_fifo_staging_without_blocking(self) -> None:
        """Non-regular staging state must report instead of hanging on open."""
        sandbox = self.sandbox()
        plugin_directory = sandbox.home / ".config/omarchy/plugins/mrai.keyguide"
        plugin_directory.mkdir(parents=True)
        plugin_directory.chmod(0o500)
        self.assertNotEqual(0, sandbox.install().returncode)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        pending = document.get("pending_reservation")
        self.assertIsInstance(pending, dict)
        plugin_directory.chmod(0o700)
        staging = Path(pending["temporary_path"])
        os.mkfifo(staging)

        try:
            result = sandbox.run_make("uninstall", timeout=2)
        except subprocess.TimeoutExpired:
            self.fail("uninstall blocked while authenticating a staging FIFO")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("staging file does not match reservation token", result.stdout)
        self.assertTrue(stat.S_ISFIFO(staging.lstat().st_mode))
        self.assertTrue(sandbox.manifest.exists())

    def test_recovery_preserves_fifo_reservation_without_blocking(self) -> None:
        """A non-regular final reservation is unowned and must not hang cleanup."""
        sandbox = self.sandbox()
        plugin_directory = sandbox.home / ".config/omarchy/plugins/mrai.keyguide"
        plugin_directory.mkdir(parents=True)
        plugin_directory.chmod(0o500)
        self.assertNotEqual(0, sandbox.install().returncode)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        pending = document.get("pending_reservation")
        self.assertIsInstance(pending, dict)
        plugin_directory.chmod(0o700)
        reservation = Path(pending["path"])
        os.mkfifo(reservation)

        try:
            result = sandbox.run_make("uninstall", timeout=2)
        except subprocess.TimeoutExpired:
            self.fail("uninstall blocked while authenticating a reservation FIFO")

        self.assert_command_succeeded(result)
        self.assertTrue(stat.S_ISFIFO(reservation.lstat().st_mode))
        self.assertFalse(sandbox.manifest.exists())

    def test_recovery_removes_published_reservation_and_staging_link(
        self,
    ) -> None:
        """A crash after no-clobber publication must clean both owned names."""
        sandbox = self.sandbox()
        plugin_directory = sandbox.home / ".config/omarchy/plugins/mrai.keyguide"
        plugin_directory.mkdir(parents=True)
        plugin_directory.chmod(0o500)
        self.assertNotEqual(0, sandbox.install().returncode)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        pending = document.get("pending_reservation")
        self.assertIsInstance(pending, dict)
        plugin_directory.chmod(0o700)
        reservation = Path(pending["path"])
        staging = Path(pending["temporary_path"])
        staging.write_text(pending["token"], encoding="ascii")
        staging.chmod(0o600)
        os.link(staging, reservation)

        self.assert_command_succeeded(sandbox.uninstall())
        self.assertFalse(reservation.exists())
        self.assertFalse(staging.exists())
        self.assert_command_succeeded(sandbox.install())
        self.assert_command_succeeded(sandbox.uninstall())

    def test_existing_state_directory_mode_is_preserved(self) -> None:
        """Resetting an existing directory mode would mutate unowned metadata."""
        sandbox = self.sandbox()
        state_directory = sandbox.manifest.parent
        state_directory.mkdir(parents=True)
        state_directory.chmod(0o750)

        self.assert_command_succeeded(sandbox.install())

        self.assertEqual(0o750, stat.S_IMODE(state_directory.stat().st_mode))

    def test_tampered_manifest_is_rejected_before_any_deletion(self) -> None:
        """Trusting an injected manifest path would permit arbitrary deletion."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        victim = sandbox.root / "victim.txt"
        victim.write_text("not Keyguide data", encoding="utf-8")
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        document["owned_files"].append(str(victim))
        sandbox.manifest.write_text(json.dumps(document), encoding="utf-8")

        result = sandbox.uninstall()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual("not Keyguide data", victim.read_text(encoding="utf-8"))
        self.assertTrue(sandbox.manifest.exists())
        self.assertTrue((sandbox.home / OWNED_RELATIVE_PATHS[-1]).exists())

    def test_contradictory_enablement_flags_are_rejected_before_deletion(self) -> None:
        """Contradictory ownership state could disable a user-enabled plugin."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        document["plugin_was_enabled"] = True
        document["plugin_enabled_by_installer"] = True
        sandbox.manifest.write_text(json.dumps(document), encoding="utf-8")

        result = sandbox.uninstall()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(sandbox.manifest.exists())
        self.assertTrue((sandbox.home / OWNED_RELATIVE_PATHS[-1]).exists())

    def test_retargeted_plugin_parent_is_rejected_before_deletion(self) -> None:
        """Following a replacement parent symlink could delete decoy files."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        plugin_directory = sandbox.home / ".config/omarchy/plugins/mrai.keyguide"
        original_directory = plugin_directory.with_name("mrai.keyguide.original")
        plugin_directory.rename(original_directory)
        decoy_directory = sandbox.home / ".config/omarchy/decoy-plugin"
        decoy_directory.mkdir()
        decoy_manifest = decoy_directory / "manifest.json"
        decoy_manifest.write_text("decoy data\n", encoding="utf-8")
        plugin_directory.symlink_to(decoy_directory, target_is_directory=True)

        result = sandbox.uninstall()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual("decoy data\n", decoy_manifest.read_text(encoding="utf-8"))
        self.assertTrue(sandbox.manifest.exists())

    def test_uninstall_prunes_only_empty_keyguide_directories(self) -> None:
        """Recursive directory removal would delete an unrecorded user file."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        plugin_directory = (
            sandbox.home / ".config/omarchy/plugins/mrai.keyguide"
        )
        user_file = plugin_directory / "user-note.txt"
        user_file.write_text("keep this", encoding="utf-8")

        self.assert_command_succeeded(sandbox.uninstall())

        self.assertEqual("keep this", user_file.read_text(encoding="utf-8"))
        self.assertTrue(plugin_directory.is_dir())
        self.assertFalse(sandbox.manifest.exists())
        for path in sandbox.owned_paths():
            self.assertFalse(path.exists(), str(path))

    def test_uninstall_can_explicitly_remove_preferences(self) -> None:
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        settings = sandbox.home / ".local/share/omarchy-keyguide/settings.json"
        settings.parent.mkdir(parents=True, exist_ok=True)
        settings.write_text('{"enabled":false}\n', encoding="utf-8")

        self.assert_command_succeeded(sandbox.uninstall_removing_preferences())

        self.assertFalse(settings.exists())
        self.assertFalse(settings.parent.exists())

    def test_desktop_entry_summons_the_settings_overlay(self) -> None:
        """A desktop entry Gio cannot resolve would leave settings inaccessible."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        # Force gtk-launch to return before its child publishes the command.
        fake_omarchy = sandbox.fake_bin / "omarchy"
        fake_omarchy.write_text(
            fake_omarchy.read_text(encoding="utf-8").replace(
                "#!/bin/sh\n",
                "#!/bin/sh\nexec >/dev/null 2>&1\nsleep 0.2\n",
                1,
            ),
            encoding="utf-8",
        )
        isolated_data_dirs = sandbox.root.parent / "xdg-data-dirs"
        isolated_data_dirs.mkdir()
        environment = sandbox.command_environment()
        environment["XDG_DATA_HOME"] = str(sandbox.home / ".local/share")
        environment["XDG_DATA_DIRS"] = str(isolated_data_dirs)

        desktop_entry = (
            sandbox.home
            / ".local/share/applications/omarchy-keyguide-settings.desktop"
        )
        if os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"):
            launch_command = [
                "gtk-launch", "omarchy-keyguide-settings.desktop"
            ]
        else:
            # gtk-launch initializes GTK before resolving the desktop ID and
            # therefore cannot run in a headless CI terminal. Gio can still
            # parse and launch the exact installed desktop entry there.
            launch_command = ["gio", "launch", str(desktop_entry)]

        result = subprocess.run(
            launch_command,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )

        self.assertEqual(0, result.returncode, result.stdout)
        deadline = time.monotonic() + 2
        command_log = ""
        while time.monotonic() < deadline:
            try:
                command_log = sandbox.command_log.read_text(encoding="utf-8")
            except FileNotFoundError:
                pass
            else:
                if command_log.endswith("\n") and command_log.splitlines():
                    break
            time.sleep(0.01)
        else:
            self.fail(
                "fake omarchy did not publish one complete command line "
                f"before timeout: {command_log!r}"
            )
        self.assertEqual(
            [f"omarchy shell shell summon {PLUGIN_ID}"],
            command_log.splitlines(),
        )

    def test_install_places_widget_after_agents_and_uninstall_restores_bar(
        self,
    ) -> None:
        """Losing the bar preimage would leave first-install layout state behind."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            left=["omarchy.menu"],
            right=["omarchy.agents", "omarchy.bluetooth"],
        )
        original = sandbox.shell_json.read_bytes()
        original_mode = stat.S_IMODE(sandbox.shell_json.stat().st_mode)

        self.assert_command_succeeded(sandbox.run_make("install"))

        self.assertEqual(
            ["omarchy.agents", PLUGIN_ID, "omarchy.bluetooth"],
            sandbox.widget_order(),
        )
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertTrue(
            document["shell_config"]["bar_placement_owned_by_installer"]
        )
        self.assertEqual(
            1,
            sandbox.commands().count(
                f"bar put {PLUGIN_ID} --after omarchy.agents"
            ),
        )

        self.assert_command_succeeded(sandbox.run_make("uninstall"))

        self.assertEqual(original, sandbox.shell_json.read_bytes())
        self.assertEqual(
            original_mode, stat.S_IMODE(sandbox.shell_json.stat().st_mode)
        )

    def test_install_rejects_fallback_placement_when_agents_is_absent(
        self,
    ) -> None:
        """A missing relative anchor must not turn fallback placement into ownership."""
        sandbox = self.simulated_user(plugin_enabled=True)
        sandbox.write_shell_layout(right=["omarchy.bluetooth"])
        original = sandbox.shell_json.read_bytes()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("immediately after omarchy.agents", result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertFalse(
            document["shell_config"]["bar_placement_owned_by_installer"]
        )
        self.assertEqual(original, sandbox.shell_json.read_bytes())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, sandbox.shell_json.read_bytes())

    def test_install_rejects_duplicate_shell_keys_before_bar_put(self) -> None:
        """Ambiguous preimage JSON must fail before the placement command."""
        sandbox = self.simulated_user(plugin_enabled=True)
        sandbox.shell_json.parent.mkdir(parents=True, exist_ok=True)
        ambiguous = (
            b'{"plugins":[],"bar":{"layout":{"left":[],"center":[],'
            b'"right":[{"id":"omarchy.agents"}]}},"bar":{"layout":{'
            b'"left":[],"center":[],"right":[]}}}\n'
        )
        sandbox.shell_json.write_bytes(ambiguous)

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("duplicate shell key: bar", result.stdout)
        self.assertNotIn(
            f"bar put {PLUGIN_ID} --after omarchy.agents",
            sandbox.commands(),
        )
        self.assertEqual(ambiguous, sandbox.shell_json.read_bytes())
        self.assertFalse(sandbox.manifest.exists())

    def test_install_rejects_a_misplaced_bar_put_result(self) -> None:
        """A successful command exit cannot authenticate the wrong position."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            bar_put_mode="misplaced",
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("immediately after omarchy.agents", result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertFalse(
            document["shell_config"]["bar_placement_owned_by_installer"]
        )
        self.assertEqual(original, sandbox.shell_json.read_bytes())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, sandbox.shell_json.read_bytes())

    def test_install_rejects_duplicate_bar_put_results(self) -> None:
        """Multiple Keyguide entries cannot authenticate unique placement ownership."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            bar_put_mode="duplicate",
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("unique mrai.keyguide", result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertFalse(
            document["shell_config"]["bar_placement_owned_by_installer"]
        )
        self.assertEqual(original, sandbox.shell_json.read_bytes())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, sandbox.shell_json.read_bytes())

    def test_install_rolls_back_mutated_bar_put_when_command_fails(self) -> None:
        """A nonzero bar command cannot leave its partial shell mutation behind."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            bar_put_mode="mutate_then_fail",
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("bar rollback", result.stdout.lower())
        self.assertEqual(original, sandbox.shell_json.read_bytes())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, sandbox.shell_json.read_bytes())

    def test_install_rolls_back_settings_bearing_bar_entry(self) -> None:
        """A noncanonical Keyguide entry is removable when nothing else changed."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            bar_put_mode="entry_settings",
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("invalid bar placement postimage", result.stdout)
        self.assertIn("bar rollback", result.stdout.lower())
        self.assertEqual(original, sandbox.shell_json.read_bytes())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, sandbox.shell_json.read_bytes())

    def test_bar_rollback_preserves_late_concurrent_shell_edit(self) -> None:
        """A user edit between rollback observation and publication must survive."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            bar_put_mode="duplicate",
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        captured = sandbox.inject_late_bar_rollback_publication_edit()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("changed during bar rollback", result.stdout)
        self.assertTrue(captured.exists(), result.stdout)
        self.assertEqual(captured.read_bytes(), sandbox.shell_json.read_bytes())
        self.assertTrue(sandbox.manifest.exists())

    def test_bar_rollback_preserves_second_mismatch_window_edit(self) -> None:
        """Rollback must not exchange an older displaced endpoint over a second edit."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            bar_put_mode="duplicate",
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        first, second = sandbox.inject_second_bar_rollback_mismatch_edit()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("changed during bar rollback", result.stdout)
        self.assertTrue(first.exists(), result.stdout)
        self.assertTrue(second.exists(), result.stdout)
        self.assertEqual(second.read_bytes(), sandbox.shell_json.read_bytes())
        self.assertTrue(sandbox.manifest.exists())

    def test_absent_preimage_local_transform_ignores_bar_put_failure_modes(
        self,
    ) -> None:
        """An absent preimage must not invoke or depend on bar-put IPC."""
        for mode in (
            "fail_before",
            "mutate_then_fail",
            "misplaced",
            "duplicate",
            "entry_settings",
            "malformed_then_fail",
            "keyguide_less_then_fail",
        ):
            with self.subTest(mode=mode):
                sandbox = self.simulated_user(
                    plugin_enabled=True,
                    bar_put_mode=mode,
                )
                self.assertFalse(sandbox.shell_json.exists())

                result = sandbox.run_make("install")

                self.assert_command_succeeded(result)
                self.assertNotIn(
                    f"bar put {PLUGIN_ID} --after omarchy.agents",
                    sandbox.commands(),
                )
                self.assertEqual(
                    sandbox.expected_default_bar_shell_with_keyguide(),
                    sandbox.shell_json.read_bytes(),
                )

                self.assert_command_succeeded(sandbox.run_make("uninstall"))
                self.assertFalse(sandbox.shell_json.exists())

    def test_absent_preimage_rejects_untrusted_default_shell(
        self,
    ) -> None:
        """Malformed defaults must not seed an owned first shell."""
        cases = {
            "malformed": b'{"plugins": [',
            "duplicate_key": (
                b'{"plugins":[],"plugins":[],"bar":{"layout":{"left":[],'
                b'"center":[],"right":[{"id":"omarchy.agents"}]}}}\n'
            ),
            "nonstandard_constant": (
                b'{"plugins":[],"bar":{"layout":{"left":[],"center":[],'
                b'"right":[{"id":"omarchy.agents","weight":NaN}]}}}\n'
            ),
            "missing_agents": json.dumps(
                self.simulated_user(plugin_enabled=True).default_shell_document(
                    right=["omarchy.bluetooth"]
                ),
                indent=2,
            ).encode()
            + b"\n",
            "duplicate_agents": json.dumps(
                self.simulated_user(plugin_enabled=True).default_shell_document(
                    left=["omarchy.agents"],
                    right=["omarchy.agents", "omarchy.bluetooth"],
                ),
                indent=2,
            ).encode()
            + b"\n",
            "existing_keyguide": json.dumps(
                self.simulated_user(plugin_enabled=True).default_shell_document(
                    right=["omarchy.agents", PLUGIN_ID, "omarchy.bluetooth"],
                ),
                indent=2,
            ).encode()
            + b"\n",
            "wrong_section_type": json.dumps(
                {
                    "plugins": [],
                    "bar": {
                        "layout": {
                            "left": [],
                            "center": [],
                            "right": {"id": "omarchy.agents"},
                        }
                    },
                },
                indent=2,
            ).encode()
            + b"\n",
        }
        version_cases = {
            "missing_version": self.simulated_user(
                plugin_enabled=True
            ).default_shell_document(),
            "string_version": self.simulated_user(
                plugin_enabled=True
            ).default_shell_document(),
            "boolean_version": self.simulated_user(
                plugin_enabled=True
            ).default_shell_document(),
            "float_version": self.simulated_user(
                plugin_enabled=True
            ).default_shell_document(),
            "future_version": self.simulated_user(
                plugin_enabled=True
            ).default_shell_document(),
        }
        version_cases["missing_version"].pop("version")
        version_cases["string_version"]["version"] = "1"
        version_cases["boolean_version"]["version"] = True
        version_cases["float_version"]["version"] = 1.0
        version_cases["future_version"]["version"] = 2
        for name, document in version_cases.items():
            cases[name] = (
                json.dumps(document, indent=2).encode()
                + b"\n"
            )

        semantic_keyguide_cases = {}
        plugin_entry = self.simulated_user(
            plugin_enabled=True
        ).default_shell_document()
        plugin_entry["plugins"] = [PLUGIN_ID]
        semantic_keyguide_cases["plugin_id_string"] = plugin_entry

        disabled_plugin_entry = self.simulated_user(
            plugin_enabled=True
        ).default_shell_document()
        disabled_plugin_entry["disabledPlugins"] = [PLUGIN_ID]
        semantic_keyguide_cases["disabled_plugin_id_string"] = (
            disabled_plugin_entry
        )

        custom_bar_section = self.simulated_user(
            plugin_enabled=True
        ).default_shell_document()
        custom_layout = custom_bar_section["bar"]["layout"]  # type: ignore[index]
        custom_layout["aux"] = [{"id": PLUGIN_ID}]  # type: ignore[index]
        semantic_keyguide_cases["custom_bar_section_widget_id"] = (
            custom_bar_section
        )

        nested_bar_section = self.simulated_user(
            plugin_enabled=True
        ).default_shell_document()
        nested_layout = nested_bar_section["bar"]["layout"]  # type: ignore[index]
        nested_layout["right"].append(  # type: ignore[index]
            {
                "id": "omarchy.section",
                "entries": [{"id": PLUGIN_ID}],
            }
        )
        semantic_keyguide_cases["nested_bar_section_widget_id"] = (
            nested_bar_section
        )
        for name, document in semantic_keyguide_cases.items():
            cases[name] = (
                json.dumps(document, indent=2).encode()
                + b"\n"
            )
        for name, default_bytes in cases.items():
            with self.subTest(name=name):
                sandbox = self.simulated_user(plugin_enabled=True)
                sandbox.default_shell.write_bytes(default_bytes)

                result = sandbox.run_make("install")

                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertIn("default shell", result.stdout.lower())
                self.assertFalse(sandbox.shell_json.exists(), result.stdout)
                self.assertNotIn(
                    f"bar put {PLUGIN_ID} --after omarchy.agents",
                    sandbox.commands(),
                )

                self.assert_command_succeeded(sandbox.run_make("uninstall"))
                self.assertFalse(sandbox.shell_json.exists())

    def test_absent_preimage_staging_preserves_concurrent_replacement(
        self,
    ) -> None:
        """A staged absent-preimage publish must not overwrite a replacement."""
        sandbox = self.simulated_user(plugin_enabled=True)
        replacement = sandbox.staged_bar_user_shell_bytes("keyguide_less")
        captured = sandbox.inject_live_shell_at_staged_bar_publication(replacement)

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("live shell appeared", result.stdout.lower())
        self.assertTrue(captured.is_file(), result.stdout)
        self.assertEqual(replacement, sandbox.shell_json.read_bytes())
        self.assertTrue(sandbox.manifest.exists())

    def test_failed_bar_put_restores_removed_preexisting_shell(self) -> None:
        """If a failed bar command removes shell.json, rollback restores the capture."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            bar_put_mode="remove_then_fail",
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        sandbox.shell_json.chmod(0o640)
        original = sandbox.shell_json.read_bytes()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("rollback", result.stdout.lower())
        self.assertEqual(original, sandbox.shell_json.read_bytes())
        self.assertEqual(0o640, stat.S_IMODE(sandbox.shell_json.stat().st_mode))

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, sandbox.shell_json.read_bytes())

    def test_removed_preimage_rollback_preserves_concurrent_creation(
        self,
    ) -> None:
        """Restoring a captured shell must use no-clobber publication."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            bar_put_mode="remove_then_fail",
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        captured, replacement = (
            sandbox.inject_late_bar_rollback_absent_restore_creation()
        )

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("rollback", result.stdout.lower())
        self.assertTrue(captured.is_file(), result.stdout)
        self.assertEqual(replacement, sandbox.shell_json.read_bytes())
        self.assertTrue(sandbox.manifest.exists())

    def test_absent_preimage_default_transform_publishes_without_ipc(
        self,
    ) -> None:
        """A first-created bar shell is derived locally from Omarchy defaults."""
        sandbox = self.simulated_user(plugin_enabled=True)
        self.assertFalse(sandbox.shell_json.exists())

        result = sandbox.run_make("install")

        self.assert_command_succeeded(result)
        self.assertTrue(sandbox.shell_json.is_file(), result.stdout)
        self.assertEqual(
            ["omarchy.agents", PLUGIN_ID, "omarchy.bluetooth"],
            sandbox.widget_order(),
        )
        self.assertEqual(
            sandbox.expected_default_bar_shell_with_keyguide(),
            sandbox.shell_json.read_bytes(),
        )
        self.assertFalse(sandbox.bar_home_log.exists())
        self.assertNotIn(
            f"bar put {PLUGIN_ID} --after omarchy.agents",
            sandbox.commands(),
        )
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        shell_state = document["shell_config"]
        self.assertTrue(shell_state["bar_placement_owned_by_installer"])
        self.assertEqual("placed", shell_state["bar_placement_state"])
        self.assertFalse(shell_state.get("bar_staging_path"))

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.shell_json.exists())

    def test_absent_preimage_staging_rejects_symlinked_stage_parent(
        self,
    ) -> None:
        """A stale staging parent symlink must not redirect isolated output."""
        sandbox = self.simulated_user(plugin_enabled=True)
        staging_config = (
            sandbox.home
            / ".local/state/omarchy-keyguide/bar-placement-home/.config"
        )
        escaped_stage = sandbox.home.parent / "escaped-bar-stage"
        escaped_stage.mkdir()
        staging_config.parent.mkdir(parents=True)
        staging_config.symlink_to(escaped_stage, target_is_directory=True)

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("staging", result.stdout.lower())
        self.assertFalse((escaped_stage / "omarchy").exists())
        self.assertFalse((escaped_stage / "omarchy/shell.json").exists())
        self.assertFalse(sandbox.shell_json.exists(), result.stdout)

    def test_absent_preimage_staged_bar_preserves_live_file_created_before_transform(
        self,
    ) -> None:
        """A live file created after absent preflight must block local publication."""
        for kind in ("same", "malformed", "keyguide_less"):
            with self.subTest(kind=kind):
                sandbox = self.simulated_user(plugin_enabled=True)
                replacement = sandbox.staged_bar_user_shell_bytes(kind)
                marker, hook_env = sandbox.live_shell_before_staged_bar_env(
                    replacement
                )

                result = sandbox.run_make("install", extra_env=hook_env)

                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertIn("live shell appeared", result.stdout.lower())
                self.assertTrue(marker.is_file(), result.stdout)
                self.assertEqual(replacement, sandbox.shell_json.read_bytes())
                self.assertNotIn(
                    f"bar put {PLUGIN_ID} --after omarchy.agents",
                    sandbox.commands(),
                )
                self.assert_command_succeeded(sandbox.run_make("uninstall"))
                self.assertEqual(replacement, sandbox.shell_json.read_bytes())

    def test_absent_preimage_staged_bar_ignores_concurrent_bar_put_modes(
        self,
    ) -> None:
        """Command-created live files are impossible because no bar command runs."""
        modes = {
            "same": "concurrent_live_same_during",
            "malformed": "concurrent_live_malformed_during",
            "keyguide_less": "concurrent_live_keyguide_less_during",
        }
        for kind, mode in modes.items():
            with self.subTest(kind=kind):
                sandbox = self.simulated_user(
                    plugin_enabled=True,
                    bar_put_mode=mode,
                )

                result = sandbox.run_make("install")

                self.assert_command_succeeded(result)
                self.assertEqual(
                    sandbox.expected_default_bar_shell_with_keyguide(),
                    sandbox.shell_json.read_bytes(),
                )
                self.assertFalse(sandbox.bar_home_log.exists())
                self.assertNotIn(
                    f"bar put {PLUGIN_ID} --after omarchy.agents",
                    sandbox.commands(),
                )
                self.assert_command_succeeded(sandbox.run_make("uninstall"))
                self.assertFalse(sandbox.shell_json.exists())

    def test_absent_preimage_staged_bar_preserves_live_file_created_at_publication(
        self,
    ) -> None:
        """No-clobber publication must not overwrite a last-moment live file."""
        for kind in ("same", "malformed", "keyguide_less"):
            with self.subTest(kind=kind):
                sandbox = self.simulated_user(plugin_enabled=True)
                replacement = sandbox.staged_bar_user_shell_bytes(kind)
                marker = sandbox.inject_live_shell_at_staged_bar_publication(
                    replacement
                )

                result = sandbox.run_make("install")

                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertIn("live shell appeared", result.stdout.lower())
                self.assertTrue(marker.is_file(), result.stdout)
                self.assertEqual(replacement, sandbox.shell_json.read_bytes())
                self.assert_command_succeeded(sandbox.run_make("uninstall"))
                self.assertEqual(replacement, sandbox.shell_json.read_bytes())

    def test_absent_preimage_default_transform_failure_never_touches_live(
        self,
    ) -> None:
        """A failed local default transform leaves the absent live shell absent."""
        sandbox = self.simulated_user(plugin_enabled=True)
        sandbox.default_shell.write_bytes(b'{"plugins": [], "bar": null}\n')
        self.assertFalse(sandbox.shell_json.exists())

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("default shell", result.stdout.lower())
        self.assertFalse(sandbox.shell_json.exists(), result.stdout)
        self.assertFalse(sandbox.bar_home_log.exists())
        self.assertNotIn(
            f"bar put {PLUGIN_ID} --after omarchy.agents",
            sandbox.commands(),
        )

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.shell_json.exists())

    def test_absent_preimage_staged_bar_stage_crash_is_recovered(
        self,
    ) -> None:
        """A crash after staging is journaled must leave uninstall resumable."""
        sandbox = self.simulated_user(plugin_enabled=True)
        marker = sandbox.crash_staged_bar_publication("staged")

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        self.assertFalse(sandbox.shell_json.exists(), result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        shell_state = document["shell_config"]
        self.assertEqual("placing", shell_state["bar_placement_state"])
        staged = Path(shell_state["bar_staging_path"])
        self.assertTrue(staged.is_file())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.shell_json.exists())
        self.assertFalse(staged.exists())
        self.assertFalse(sandbox.manifest.exists())

    def test_absent_preimage_staged_bar_publication_crash_is_recovered(
        self,
    ) -> None:
        """A crash after no-clobber publication is authenticated by the stage link."""
        sandbox = self.simulated_user(plugin_enabled=True)
        marker = sandbox.crash_staged_bar_publication("published")

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        self.assertTrue(sandbox.shell_json.is_file(), result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        shell_state = document["shell_config"]
        self.assertEqual("placing", shell_state["bar_placement_state"])
        staged = Path(shell_state["bar_staging_path"])
        self.assertTrue(staged.is_file())
        self.assertEqual(
            (sandbox.shell_json.stat().st_dev, sandbox.shell_json.stat().st_ino),
            (staged.stat().st_dev, staged.stat().st_ino),
        )

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.shell_json.exists())
        self.assertFalse(staged.exists())
        self.assertFalse(sandbox.manifest.exists())

    def test_install_rejects_noncanonical_successful_bar_put_transform(
        self,
    ) -> None:
        """Command success cannot claim unrelated or settings-bearing changes."""
        for mode in (
            "unrelated",
            "mode_change",
            "boolean_to_integer",
        ):
            with self.subTest(mode=mode):
                sandbox = self.simulated_user(
                    plugin_enabled=True,
                    bar_put_mode=mode,
                )
                sandbox.write_shell_layout(
                    right=["omarchy.agents", "omarchy.bluetooth"]
                )
                if mode == "boolean_to_integer":
                    preimage = json.loads(
                        sandbox.shell_json.read_text(encoding="utf-8")
                    )
                    preimage["userFlag"] = True
                    sandbox.shell_json.write_text(
                        json.dumps(preimage, indent=2) + "\n",
                        encoding="utf-8",
                    )

                result = sandbox.run_make("install")

                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertIn("invalid bar placement postimage", result.stdout)
                self.assertIn("rollback", result.stdout.lower())
                self.assertIn(
                    f"bar put {PLUGIN_ID} --after omarchy.agents",
                    sandbox.commands(),
                )
                document = json.loads(
                    sandbox.manifest.read_text(encoding="utf-8")
                )
                self.assertEqual(
                    "placing",
                    document["shell_config"].get("bar_placement_state"),
                )
                self.assertFalse(
                    document["shell_config"][
                        "bar_placement_owned_by_installer"
                    ]
                )
                transformed = sandbox.shell_json.read_bytes()
                self.assertTrue(
                    (sandbox.home / OWNED_RELATIVE_PATHS[0]).exists()
                )

                uninstall_result = sandbox.run_make("uninstall")

                self.assertNotEqual(
                    0, uninstall_result.returncode, uninstall_result.stdout
                )
                self.assertEqual(transformed, sandbox.shell_json.read_bytes())
                self.assertTrue(sandbox.manifest.exists())

    def test_uninstall_preserves_user_moved_widget(self) -> None:
        """A post-install move must never be overwritten by exact restoration."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            left=["omarchy.menu"],
            right=["omarchy.agents", "omarchy.bluetooth"],
        )
        self.assert_command_succeeded(sandbox.run_make("install"))
        self.assertIn(PLUGIN_ID, sandbox.widget_order())
        sandbox.move_widget_as_user("right", 0)
        user_bytes = sandbox.shell_json.read_bytes()

        result = sandbox.run_make("uninstall")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn(
            "bar configuration changed after installation", result.stdout
        )
        self.assertEqual(user_bytes, sandbox.shell_json.read_bytes())
        self.assertEqual(PLUGIN_ID, sandbox.widget_order()[0])
        self.assertTrue(sandbox.manifest.exists())
        self.assertTrue((sandbox.home / OWNED_RELATIVE_PATHS[0]).exists())

    def test_upgrade_preserves_an_existing_keyguide_placement(self) -> None:
        """An existing placement must remain user-owned and stay where it is."""
        sandbox = self.simulated_user(plugin_enabled=True)
        sandbox.write_shell_layout(
            left=["omarchy.menu", PLUGIN_ID],
            right=["omarchy.agents", "omarchy.bluetooth"],
        )
        original = sandbox.shell_json.read_bytes()

        self.assert_command_succeeded(sandbox.run_make("install"))

        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertFalse(
            document["shell_config"].get(
                "bar_placement_owned_by_installer", True
            )
        )
        self.assertNotIn(
            f"bar put {PLUGIN_ID} --after omarchy.agents",
            sandbox.commands(),
        )
        self.assertEqual(original, sandbox.shell_json.read_bytes())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, sandbox.shell_json.read_bytes())

    def test_preserve_user_shell_upgrade_rebases_retained_clock_edit(self) -> None:
        """The live clock edit must become the authenticated upgrade baseline."""
        sandbox = self.simulated_user(plugin_enabled=False)
        bindings = sandbox.home / ".config/hypr/bindings.lua"
        bindings.parent.mkdir(parents=True)
        bindings.write_bytes(b"-- user bindings remain byte exact\n")
        settings = sandbox.home / ".local/share/omarchy-keyguide/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_bytes(b'{"enabled":false,"opacity":0.73}\n')
        old_manifest, old_backup = sandbox.prepare_retained_clock_edit()
        user_document = json.loads(
            sandbox.shell_json.read_text(encoding="utf-8")
        )
        derived_document = json.loads(json.dumps(user_document))
        right = derived_document["bar"]["layout"]["right"]
        right.remove({"id": PLUGIN_ID})
        expected_backup = (
            json.dumps(derived_document, indent=2, ensure_ascii=False) + "\n"
        ).encode()
        bindings_before = bindings.read_bytes()
        settings_before = settings.read_bytes()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(result)
        final_bytes = sandbox.shell_json.read_bytes()
        final_document = json.loads(final_bytes)
        self.assertEqual(
            json.dumps(user_document, sort_keys=True, ensure_ascii=False),
            json.dumps(final_document, sort_keys=True, ensure_ascii=False),
        )
        locations = []
        for section, entries in final_document["bar"]["layout"].items():
            for index, entry in enumerate(entries):
                if entry.get("id") == PLUGIN_ID:
                    locations.append((section, index, entry))
        self.assertEqual([("right", 1, {"id": PLUGIN_ID})], locations)
        self.assertEqual(
            "omarchy.agents",
            final_document["bar"]["layout"]["right"][0]["id"],
        )
        backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
        self.assertEqual(expected_backup, backup.read_bytes())
        manifest = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        shell_state = manifest["shell_config"]
        self.assertEqual("installed", manifest["install_state"])
        self.assertNotIn("shell_rebase", manifest)
        self.assertFalse(manifest["plugin_was_enabled"])
        self.assertTrue(manifest["plugin_enabled_by_installer"])
        self.assertEqual(
            hashlib.sha256(expected_backup).hexdigest(),
            shell_state["pre_sha256"],
        )
        self.assertEqual(
            hashlib.sha256(final_bytes).hexdigest(),
            shell_state["post_enable_sha256"],
        )
        self.assertTrue(shell_state["bar_placement_owned_by_installer"])
        self.assertEqual("placed", shell_state["bar_placement_state"])
        self.assertEqual(bindings_before, bindings.read_bytes())
        self.assertEqual(settings_before, settings.read_bytes())
        self.assertNotEqual(old_manifest, sandbox.manifest.read_bytes())
        self.assertNotEqual(old_backup, backup.read_bytes())
        self.assertTrue((sandbox.home / ICON_RELATIVE_PATH).is_file())
        self.assertEqual(
            (REPOSITORY / "src/plugin/VisibilityModel.js").read_bytes(),
            (sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH).read_bytes(),
        )

    def test_preserve_upgrade_retains_a_preenabled_user_plugin_entry(self) -> None:
        """A plugin entry not enabled by Keyguide remains outside its transform."""
        sandbox = self.simulated_user(plugin_enabled=True)
        sandbox.write_shell_layout(
            left=["omarchy.menu"],
            right=["omarchy.agents", "omarchy.bluetooth"],
        )
        baseline = json.loads(
            sandbox.shell_json.read_text(encoding="utf-8")
        )
        baseline["plugins"] = [{"id": PLUGIN_ID, "opacity": 0.61}]
        baseline["clockFormat"] = "dddd HH:mm"
        sandbox.shell_json.write_text(
            json.dumps(baseline, indent=2) + "\n", encoding="utf-8"
        )
        self.assert_command_succeeded(sandbox.run_make("install"))
        manifest = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertTrue(manifest["plugin_was_enabled"])
        self.assertFalse(manifest["plugin_enabled_by_installer"])

        edited = json.loads(
            sandbox.shell_json.read_text(encoding="utf-8")
        )
        edited["clockFormat"] = "ddd d MMM h:mm AP"
        sandbox.shell_json.write_text(
            json.dumps(edited, indent=2) + "\n", encoding="utf-8"
        )

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(result)
        final_document = json.loads(
            sandbox.shell_json.read_text(encoding="utf-8")
        )
        self.assertEqual("ddd d MMM h:mm AP", final_document["clockFormat"])
        self.assertEqual(
            [{"id": PLUGIN_ID, "opacity": 0.61}],
            final_document["plugins"],
        )
        locations = [
            (section, index)
            for section, entries in final_document["bar"]["layout"].items()
            if isinstance(entries, list)
            for index, entry in enumerate(entries)
            if (entry.get("id") if isinstance(entry, dict) else entry)
            == PLUGIN_ID
        ]
        self.assertEqual([("right", 1)], locations)

    def test_existing_install_requires_preserve_user_shell_opt_in(self) -> None:
        """A divergent postimage alone must never authorize an upgrade."""
        sandbox = self.simulated_user(plugin_enabled=False)
        old_manifest, old_backup = sandbox.prepare_retained_clock_edit()
        live = sandbox.shell_json.read_bytes()
        commands = sandbox.commands()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("installation manifest already exists", result.stdout)
        self.assertEqual(live, sandbox.shell_json.read_bytes())
        self.assertEqual(old_manifest, sandbox.manifest.read_bytes())
        self.assertEqual(
            old_backup,
            (sandbox.manifest.parent / "shell.json.pre-keyguide").read_bytes(),
        )
        self.assertEqual(commands, sandbox.commands())

    def test_preserve_user_shell_rejects_ambiguous_owned_transforms(self) -> None:
        """Only one settings-free Keyguide entry anchored after Agents is owned."""
        for mutation in (
            "duplicate bar entry",
            "duplicate custom layout entry",
            "misplaced bar entry",
            "bar entry settings",
            "plugin entry settings",
        ):
            with self.subTest(mutation=mutation):
                sandbox = self.simulated_user(plugin_enabled=False)
                old_manifest, old_backup = sandbox.prepare_retained_clock_edit()
                document = json.loads(
                    sandbox.shell_json.read_text(encoding="utf-8")
                )
                layout = document["bar"]["layout"]
                keyguide_index = next(
                    index
                    for index, entry in enumerate(layout["right"])
                    if entry.get("id") == PLUGIN_ID
                )
                if mutation == "duplicate bar entry":
                    layout["left"].append({"id": PLUGIN_ID})
                elif mutation == "duplicate custom layout entry":
                    layout["aux"] = [{"id": PLUGIN_ID}]
                elif mutation == "misplaced bar entry":
                    widget = layout["right"].pop(keyguide_index)
                    layout["right"].insert(0, widget)
                elif mutation == "bar entry settings":
                    layout["right"][keyguide_index]["opacity"] = 0.5
                else:
                    document["plugins"].append(
                        {"id": PLUGIN_ID, "opacity": 0.5}
                    )
                sandbox.shell_json.write_text(
                    json.dumps(document, indent=2, ensure_ascii=False) + "\n",
                    encoding="utf-8",
                )
                mutated = sandbox.shell_json.read_bytes()
                commands = sandbox.commands()

                result = sandbox.run_make(
                    "install", extra_env={"PRESERVE_USER_SHELL": "1"}
                )

                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertIn("preserve-user-shell upgrade rejected", result.stdout)
                self.assertEqual(mutated, sandbox.shell_json.read_bytes())
                self.assertEqual(old_manifest, sandbox.manifest.read_bytes())
                self.assertEqual(
                    old_backup,
                    (
                        sandbox.manifest.parent / "shell.json.pre-keyguide"
                    ).read_bytes(),
                )
                self.assertEqual(commands, sandbox.commands())

    def test_preserve_user_shell_authenticates_retained_deployed_format(
        self,
    ) -> None:
        """Legacy authentication must use the deployed endpoint's exact bytes."""
        sandbox = self.simulated_user(plugin_enabled=False)
        before = (
            FIXTURES / "task5-retained-before-shell.json"
        ).read_bytes()
        authenticated_after = (
            FIXTURES / "task5-retained-final-shell.json"
        ).read_bytes()
        sandbox.shell_json.parent.mkdir(parents=True, exist_ok=True)
        sandbox.shell_json.write_bytes(before)
        self.assert_command_succeeded(sandbox.run_make("install"))

        backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
        backup.write_bytes(before)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        shell_state = document["shell_config"]
        shell_state["post_enable_sha256"] = hashlib.sha256(
            authenticated_after
        ).hexdigest()
        del shell_state["pre_sha256"]
        del shell_state["restore_state"]
        del shell_state["bar_placement_state"]
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

        user_after = authenticated_after.replace(
            b'"format": "dddd HH:mm"',
            b'"format": "ddd d MMM h:mm AP"',
        )
        self.assertNotEqual(authenticated_after, user_after)
        sandbox.shell_json.write_bytes(user_after)

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(result)
        final_document = json.loads(
            sandbox.shell_json.read_text(encoding="utf-8")
        )
        clock = next(
            entry
            for entry in final_document["bar"]["layout"]["center"]
            if entry.get("id") == "omarchy.clock"
        )
        self.assertEqual("ddd d MMM h:mm AP", clock["format"])
        expected_unowned = json.loads(user_after.decode("utf-8"))
        observed_unowned = json.loads(json.dumps(final_document))
        for shell_document in (expected_unowned, observed_unowned):
            shell_document["plugins"] = [
                entry
                for entry in shell_document["plugins"]
                if (entry.get("id") if isinstance(entry, dict) else entry)
                != PLUGIN_ID
            ]
            for entries in shell_document["bar"]["layout"].values():
                if isinstance(entries, list):
                    entries[:] = [
                        entry
                        for entry in entries
                        if (
                            entry.get("id")
                            if isinstance(entry, dict)
                            else entry
                        )
                        != PLUGIN_ID
                    ]
        self.assertEqual(expected_unowned, observed_unowned)

    def test_preserve_user_shell_rejects_invalid_or_duplicate_key_json(self) -> None:
        """A type-strict rebase must not normalize ambiguous shell bytes."""
        for invalid in (
            b'{"plugins":[],"bar":',
            (
                b'{"plugins":[],"bar":{"layout":{"left":[],"center":[],'
                b'"right":[]}},"bar":{"layout":{"left":[],"center":[],'
                b'"right":[]}}}\n'
            ),
            b"nonstandard-infinity",
        ):
            with self.subTest(invalid=invalid):
                sandbox = self.simulated_user(plugin_enabled=False)
                old_manifest, old_backup = sandbox.prepare_retained_clock_edit()
                if invalid == b"nonstandard-infinity":
                    invalid = sandbox.shell_json.read_bytes().replace(
                        b'"preserveNull": null', b'"preserveNull": Infinity'
                    )
                sandbox.shell_json.write_bytes(invalid)

                result = sandbox.run_make(
                    "install", extra_env={"PRESERVE_USER_SHELL": "1"}
                )

                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertIn("preserve-user-shell upgrade rejected", result.stdout)
                self.assertEqual(invalid, sandbox.shell_json.read_bytes())
                self.assertEqual(old_manifest, sandbox.manifest.read_bytes())
                self.assertEqual(
                    old_backup,
                    (
                        sandbox.manifest.parent / "shell.json.pre-keyguide"
                    ).read_bytes(),
                )

    def test_preserve_user_shell_rejects_noninteger_manifest_schema(self) -> None:
        """JSON booleans and floats must not alias the integer schema version."""
        for schema_version in (True, 1.0):
            with self.subTest(schema_version=schema_version):
                sandbox = self.simulated_user(plugin_enabled=False)
                _, old_backup = sandbox.prepare_retained_clock_edit()
                live = sandbox.shell_json.read_bytes()
                manifest = json.loads(
                    sandbox.manifest.read_text(encoding="utf-8")
                )
                manifest["schema_version"] = schema_version
                sandbox.manifest.write_text(
                    json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
                )
                invalid_manifest = sandbox.manifest.read_bytes()

                result = sandbox.run_make(
                    "install", extra_env={"PRESERVE_USER_SHELL": "1"}
                )

                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertIn("unsupported schema", result.stdout)
                self.assertEqual(invalid_manifest, sandbox.manifest.read_bytes())
                self.assertEqual(live, sandbox.shell_json.read_bytes())
                self.assertEqual(
                    old_backup,
                    (
                        sandbox.manifest.parent / "shell.json.pre-keyguide"
                    ).read_bytes(),
                )

    def test_preserve_user_shell_authenticates_legacy_backup_before_rebase(
        self,
    ) -> None:
        """A changed legacy backup cannot inherit trust from the manifest."""
        sandbox = self.simulated_user(plugin_enabled=False)
        old_manifest, _ = sandbox.prepare_retained_clock_edit()
        backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
        backup_document = json.loads(backup.read_text(encoding="utf-8"))
        backup_document["idle"]["lock"] = 42
        backup.write_text(
            json.dumps(backup_document, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        tampered_backup = backup.read_bytes()
        live = sandbox.shell_json.read_bytes()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("authenticated legacy shell postimage", result.stdout)
        self.assertEqual(live, sandbox.shell_json.read_bytes())
        self.assertEqual(old_manifest, sandbox.manifest.read_bytes())
        self.assertEqual(tampered_backup, backup.read_bytes())

    def test_preserve_user_shell_rejects_concurrent_shell_change_before_journal(
        self,
    ) -> None:
        """A changed observation must abort before backup or manifest mutation."""
        sandbox = self.simulated_user(plugin_enabled=False)
        old_manifest, old_backup = sandbox.prepare_retained_clock_edit()
        sandbox.inject_preserve_rebase_concurrent_shell_edit()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn(
            "shell changed during preserve-user-shell rebase", result.stdout
        )
        concurrent = json.loads(sandbox.shell_json.read_text(encoding="utf-8"))
        self.assertEqual("retained", concurrent["concurrentUserEdit"])
        self.assertEqual(old_manifest, sandbox.manifest.read_bytes())
        self.assertEqual(
            old_backup,
            (sandbox.manifest.parent / "shell.json.pre-keyguide").read_bytes(),
        )

    def test_preserve_user_shell_rejects_manifest_change_after_validation(
        self,
    ) -> None:
        """The rebase may trust only the bytes parsed by the full validator."""
        sandbox = self.simulated_user(plugin_enabled=False)
        _, old_backup = sandbox.prepare_retained_clock_edit()
        live = sandbox.shell_json.read_bytes()
        captured = sandbox.inject_manifest_change_after_preserve_validation()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("manifest changed after validation", result.stdout)
        self.assertTrue(captured.is_file())
        self.assertEqual(captured.read_bytes(), sandbox.manifest.read_bytes())
        self.assertEqual(live, sandbox.shell_json.read_bytes())
        self.assertEqual(
            old_backup,
            (sandbox.manifest.parent / "shell.json.pre-keyguide").read_bytes(),
        )

    def test_preserve_upgrade_rejects_concurrent_manifest_transition(
        self,
    ) -> None:
        """A journal transition must not overwrite a competing valid update."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        live = sandbox.shell_json.read_bytes()
        captured = (
            sandbox.inject_manifest_change_during_shell_restoring_transition()
        )

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn(
            "install manifest changed during atomic transition", result.stdout
        )
        self.assertTrue(captured.is_file())
        self.assertEqual(captured.read_bytes(), sandbox.manifest.read_bytes())
        self.assertEqual(live, sandbox.shell_json.read_bytes())

    def test_preserve_upgrade_keeps_manifest_handoff_out_of_final_removal(
        self,
    ) -> None:
        """The upgrade handoff manifest is adopted, not finally removed."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        captured = sandbox.inject_manifest_change_before_final_removal()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(result)
        self.assertFalse(captured.exists())
        final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installed", final["install_state"])
        self.assertNotIn("upgrade_handoff", final)
        self.assertNotIn("concurrentUserEdit", final)

    def test_preserve_upgrade_keeps_rebased_backup_out_of_final_removal(
        self,
    ) -> None:
        """The rebased backup remains the authenticated next preimage."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        captured = sandbox.inject_backup_change_before_final_removal()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(result)
        self.assertFalse(captured.exists())
        backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
        final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installed", final["install_state"])
        self.assertEqual(
            final["shell_config"]["pre_sha256"],
            hashlib.sha256(backup.read_bytes()).hexdigest(),
        )

    def test_atomic_rebase_publication_restores_concurrent_manifest(
        self,
    ) -> None:
        """A last-moment path replacement must survive a rejected exchange."""
        sandbox = self.simulated_user(plugin_enabled=False)
        _, old_backup = sandbox.prepare_retained_clock_edit()
        live = sandbox.shell_json.read_bytes()
        captured = sandbox.inject_concurrent_manifest_at_atomic_publish()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("manifest changed during atomic publication", result.stdout)
        self.assertTrue(captured.is_file())
        self.assertEqual(captured.read_bytes(), sandbox.manifest.read_bytes())
        self.assertEqual(live, sandbox.shell_json.read_bytes())
        self.assertEqual(
            old_backup,
            (sandbox.manifest.parent / "shell.json.pre-keyguide").read_bytes(),
        )

    def test_atomic_rebase_publication_restores_concurrent_manifest_symlink(
        self,
    ) -> None:
        """A displaced non-regular endpoint must be restored, never unlinked."""
        sandbox = self.simulated_user(plugin_enabled=False)
        _, old_backup = sandbox.prepare_retained_clock_edit()
        live = sandbox.shell_json.read_bytes()
        target = sandbox.inject_manifest_symlink_at_atomic_publish()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("manifest changed during atomic publication", result.stdout)
        self.assertTrue(sandbox.manifest.is_symlink())
        self.assertEqual(target.resolve(), sandbox.manifest.resolve())
        self.assertEqual(live, sandbox.shell_json.read_bytes())
        self.assertEqual(
            old_backup,
            (sandbox.manifest.parent / "shell.json.pre-keyguide").read_bytes(),
        )

    def test_preserve_upgrade_rejects_late_concurrent_shell_restore_edit(
        self,
    ) -> None:
        """The recursive restore must not overwrite an edit after its last check."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        captured = sandbox.inject_late_concurrent_shell_restore_edit()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn(
            "live shell endpoint bytes changed during atomic restoration",
            result.stdout,
        )
        self.assertTrue(captured.is_file())
        self.assertEqual(captured.read_bytes(), sandbox.shell_json.read_bytes())
        concurrent_document = json.loads(
            sandbox.shell_json.read_text(encoding="utf-8")
        )
        self.assertEqual("retained", concurrent_document["lateConcurrentEdit"])

    def test_interrupted_preserve_rebase_recovers_from_durable_journal(
        self,
    ) -> None:
        """A failed backup publication must leave an authenticated retry path."""
        sandbox = self.simulated_user(plugin_enabled=False)
        _, old_backup = sandbox.prepare_retained_clock_edit()
        live = sandbox.shell_json.read_bytes()
        sandbox.inject_preserve_rebase_backup_publication_fault()

        first = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, first.returncode, first.stdout)
        self.assertIn(
            "simulated rebase backup publication failure", first.stdout
        )
        interrupted = json.loads(
            sandbox.manifest.read_text(encoding="utf-8")
        )
        self.assertEqual("rebasing", interrupted["install_state"])
        self.assertEqual(live, sandbox.shell_json.read_bytes())
        self.assertEqual(
            old_backup,
            (sandbox.manifest.parent / "shell.json.pre-keyguide").read_bytes(),
        )

        retry = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(retry)
        final_manifest = json.loads(
            sandbox.manifest.read_text(encoding="utf-8")
        )
        self.assertEqual("installed", final_manifest["install_state"])
        self.assertNotIn("shell_rebase", final_manifest)

    def test_preserve_upgrade_retries_recursive_uninstall_restart(self) -> None:
        """The same command must resume a durable restart-pending uninstall."""
        sandbox = self.simulated_user(
            plugin_enabled=False, restart_fail_on_call=2
        )
        sandbox.prepare_retained_clock_edit()

        first = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, first.returncode, first.stdout)
        interrupted = json.loads(
            sandbox.manifest.read_text(encoding="utf-8")
        )
        self.assertEqual("restart_pending", interrupted["install_state"])
        self.assertEqual(
            "restored", interrupted["shell_config"]["restore_state"]
        )

        retry = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(retry)
        final_document = json.loads(
            sandbox.shell_json.read_text(encoding="utf-8")
        )
        clock = next(
            entry
            for entry in final_document["bar"]["layout"]["center"]
            if entry.get("id") == "omarchy.clock"
        )
        self.assertEqual("ddd d MMM h:mm AP", clock["format"])

    def test_preserve_upgrade_waits_for_lock_status_after_shell_restart(
        self,
    ) -> None:
        """A controlled shell restart may briefly hide its lock-status service."""
        sandbox = self.simulated_user(plugin_enabled=False)
        _, installed_shell = self.prepare_pre_executable_picker_install(sandbox)

        result = sandbox.run_install_script(
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "FAKE_LOCK_TRANSITION_ON_RESTART_CALL": "2",
                "FAKE_LOCK_STATUS_FAIL_AFTER_RESTART_COUNT": "2",
            }
        )

        self.assert_command_succeeded(result)
        final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installed", final["install_state"])
        self.assertNotIn("upgrade_handoff", final)
        self.assertEqual(installed_shell, sandbox.shell_json.read_bytes())
        self.assertEqual(
            (REPOSITORY / "src/plugin/components/ExecutablePicker.qml").read_bytes(),
            (sandbox.home / EXECUTABLE_PICKER_RELATIVE_PATH).read_bytes(),
        )

    def test_preserve_upgrade_defers_real_lock_after_shell_restart(
        self,
    ) -> None:
        """Readiness waiting must never turn a real post-restart lock into mutation."""
        sandbox = self.simulated_user(plugin_enabled=False)
        baseline_shell, _ = self.prepare_pre_executable_picker_install(sandbox)

        result = sandbox.run_install_script(
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "FAKE_LOCK_TRANSITION_ON_RESTART_CALL": "2",
                "FAKE_COMPOSITOR_LOCK_AFTER_RESTART": "1",
            }
        )

        self.assertEqual(75, result.returncode, result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("upgrade_ready", document["install_state"])
        self.assertEqual([], document["owned_files"])
        self.assertEqual(baseline_shell, sandbox.shell_json.read_bytes())
        self.assertFalse(
            (
                sandbox.home
                / ".config/omarchy/plugins/mrai.keyguide/Settings.qml"
            ).exists()
        )

    def test_preserve_user_shell_is_rejected_for_prefixed_install(self) -> None:
        """Prefix mode has no authenticated live shell state to preserve."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        before = sandbox.snapshot()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn(
            "PRESERVE_USER_SHELL=1 requires a live installation", result.stdout
        )
        self.assertEqual(before, sandbox.snapshot())

    def test_uninstall_recovers_placing_intent_from_exact_preimage(self) -> None:
        """A durable intent with no command mutation is safe to clean up."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            bar_put_mode="fail_before",
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            "placing", document["shell_config"].get("bar_placement_state")
        )
        self.assertEqual(original, sandbox.shell_json.read_bytes())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))

        self.assertEqual(original, sandbox.shell_json.read_bytes())
        self.assertFalse(sandbox.manifest.exists())
        self.assertFalse((sandbox.home / OWNED_RELATIVE_PATHS[0]).exists())

    def test_interrupted_bar_put_is_recovered_from_unique_anchored_insertion(
        self,
    ) -> None:
        """A placing journal may claim only one exact insertion after Agents."""
        sandbox = self.simulated_user(
            plugin_enabled=True,
            break_manifest_after_bar_put=True,
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(
            ["omarchy.agents", PLUGIN_ID, "omarchy.bluetooth"],
            sandbox.widget_order(),
        )
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            "placing", document["shell_config"].get("bar_placement_state")
        )
        self.assertFalse(
            document["shell_config"]["bar_placement_owned_by_installer"]
        )
        sandbox.manifest.parent.chmod(0o700)

        self.assert_command_succeeded(sandbox.run_make("uninstall"))

        self.assertEqual(original, sandbox.shell_json.read_bytes())
        self.assertNotIn(PLUGIN_ID, sandbox.widget_order())
        self.assertFalse(sandbox.manifest.exists())

    def test_preserve_upgrade_preflights_new_destination_before_teardown(
        self,
    ) -> None:
        """A user-owned new icon collision must leave the old install untouched."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        icon = sandbox.home / ICON_RELATIVE_PATH
        icon.parent.mkdir(parents=True, exist_ok=True)
        icon.write_bytes(b"user-owned icon\n")
        icon.chmod(0o640)
        manifest_document = json.loads(
            sandbox.manifest.read_text(encoding="utf-8")
        )
        protected_paths = [
            sandbox.manifest,
            sandbox.shell_json,
            sandbox.manifest.parent / "shell.json.pre-keyguide",
            *[Path(path) for path in manifest_document["owned_files"]],
            icon,
        ]
        before = {
            path: (
                path.read_bytes(),
                stat.S_IMODE(path.stat().st_mode),
                path.stat().st_dev,
                path.stat().st_ino,
            )
            for path in protected_paths
        }
        commands_before = sandbox.commands()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("refusing to overwrite unowned path", result.stdout)
        self.assertEqual(commands_before, sandbox.commands())
        for path, expected in before.items():
            with self.subTest(path=path):
                observed = path.stat()
                self.assertEqual(expected[0], path.read_bytes())
                self.assertEqual(expected[1], stat.S_IMODE(observed.st_mode))
                self.assertEqual(expected[2:], (observed.st_dev, observed.st_ino))

    def test_preserve_upgrade_reserves_new_destination_before_teardown(
        self,
    ) -> None:
        """A boundary collision must leave teardown journaled and resumable."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        old_document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        protected = {
            Path(path): Path(path).read_bytes()
            for path in old_document["owned_files"]
        }
        shell_before = sandbox.shell_json.read_bytes()
        backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
        backup_before = backup.read_bytes()
        marker = sandbox.inject_new_icon_creation_at_uninstall_boundary()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual("created\n", marker.read_text(encoding="utf-8"))
        icon = sandbox.home / ICON_RELATIVE_PATH
        self.assertEqual(b"user-owned boundary icon\n", icon.read_bytes())
        self.assertEqual(shell_before, sandbox.shell_json.read_bytes())
        self.assertEqual(backup_before, backup.read_bytes())
        for path, expected in protected.items():
            self.assertEqual(expected, path.read_bytes(), str(path))
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("rebasing", document["install_state"])
        self.assertIsInstance(document.get("upgrade_handoff"), dict)

        icon.unlink()
        self.assert_command_succeeded(
            sandbox.run_make(
                "install", extra_env={"PRESERVE_USER_SHELL": "1"}
            )
        )
        self.assertEqual(
            (REPOSITORY / "assets/omarchy-keyguide.svg").read_bytes(),
            icon.read_bytes(),
        )

    def test_preserve_upgrade_retries_after_fresh_copy_failure(self) -> None:
        """A fresh-install failure must return through upgrade-ready on retry."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        marker = sandbox.fail_next_upgrade_icon_copy()

        first = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, first.returncode, first.stdout)
        self.assertTrue(marker.is_file())
        interrupted = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installing", interrupted["install_state"])
        self.assertIsInstance(interrupted.get("upgrade_handoff"), dict)

        second = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(second)
        final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installed", final["install_state"])
        self.assertNotIn("upgrade_handoff", final)
        self.assertEqual(
            (REPOSITORY / "assets/omarchy-keyguide.svg").read_bytes(),
            (sandbox.home / ICON_RELATIVE_PATH).read_bytes(),
        )

    def test_preserve_upgrade_reserves_visibility_model_as_new_only(self) -> None:
        """The JS dependency must be reserved when upgrading older installs."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()

        self.assert_command_succeeded(
            sandbox.run_preserve_uninstall_to_upgrade_ready()
        )

        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("upgrade_ready", document["install_state"])
        reservations = document["upgrade_handoff"]["reservations"]
        reserved_paths = [reservation["path"] for reservation in reservations]
        self.assertIn(str(sandbox.home / ICON_RELATIVE_PATH), reserved_paths)
        self.assertIn(
            str(sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH),
            reserved_paths,
        )
        self.assertIn(str(sandbox.home / SHORTCUTS_RELATIVE_PATH), reserved_paths)
        self.assertIn(
            str(sandbox.home / SHORTCUT_EDIT_ROW_RELATIVE_PATH), reserved_paths
        )
        self.assertIn(
            str(sandbox.home / EXECUTABLE_PICKER_RELATIVE_PATH), reserved_paths
        )
        for reservation in reservations:
            path = Path(reservation["path"])
            self.assertEqual(
                path.with_name(
                    f".{path.name}.keyguide-upgrade-{reservation['token']}.tmp"
                ),
                Path(reservation["temporary_path"]),
            )

    def test_preserve_upgrade_accepts_pre_bounded_process_inventory(self) -> None:
        """The current public fileset must reserve the new limiter on upgrade."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit(legacy_new_only=(
            BOUNDED_PROCESS_RELATIVE_PATH,
        ))
        shell_before = sandbox.shell_json.read_bytes()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(result)
        final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installed", final["install_state"])
        self.assertEqual(shell_before, sandbox.shell_json.read_bytes())
        self.assertEqual(
            (REPOSITORY / "src/backend/keyguide_backend/bounded_process.py").read_bytes(),
            (sandbox.home / BOUNDED_PROCESS_RELATIVE_PATH).read_bytes(),
        )

    def test_preserve_upgrade_accepts_pre_visibility_inventory(self) -> None:
        """The icon-era manifest must reserve every later runtime dependency."""
        sandbox = self.simulated_user(plugin_enabled=False)
        bindings = sandbox.home / ".config/hypr/bindings.lua"
        bindings.parent.mkdir(parents=True)
        bindings.write_bytes(b"-- user bindings remain byte exact\n")
        settings = sandbox.home / ".local/share/omarchy-keyguide/settings.json"
        settings.parent.mkdir(parents=True)
        settings.write_bytes(b'{"enabled":true,"opacity":0.61}\n')
        sandbox.prepare_retained_clock_edit(
            legacy_new_only=(
                BOUNDED_PROCESS_RELATIVE_PATH,
                VISIBILITY_MODEL_RELATIVE_PATH,
                SHORTCUTS_RELATIVE_PATH,
                SHORTCUT_EDIT_ROW_RELATIVE_PATH,
                EXECUTABLE_PICKER_RELATIVE_PATH,
            )
        )
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            [
                str(sandbox.home / relative)
                for relative in PRE_VISIBILITY_MODEL_OWNED_RELATIVE_PATHS
            ],
            document["owned_files"],
        )
        shell_before = sandbox.shell_json.read_bytes()
        bindings_before = bindings.read_bytes()
        settings_before = settings.read_bytes()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(result)
        final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installed", final["install_state"])
        self.assertNotIn("upgrade_handoff", final)
        self.assertEqual(shell_before, sandbox.shell_json.read_bytes())
        self.assertEqual(bindings_before, bindings.read_bytes())
        self.assertEqual(settings_before, settings.read_bytes())
        self.assertEqual(
            (REPOSITORY / "src/plugin/VisibilityModel.js").read_bytes(),
            (sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH).read_bytes(),
        )

    def test_preserve_upgrade_recovers_live_retained_visibility_restart_pending(
        self,
    ) -> None:
        """A completed historical JS handoff must resume from restart-pending."""
        sandbox = self.simulated_user(plugin_enabled=False)
        _, old_visibility_model = (
            self.prepare_live_retained_visibility_restart_pending(sandbox)
        )
        shell_before = sandbox.shell_json.read_bytes()
        visibility_model = sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH
        self.assertEqual(old_visibility_model, visibility_model.read_bytes())
        self.assertEqual(0o600, stat.S_IMODE(visibility_model.stat().st_mode))
        self.assertFalse(
            visibility_model.with_name(
                ".VisibilityModel.js.keyguide-upgrade-"
                + json.loads(sandbox.manifest.read_text(encoding="utf-8"))[
                    "upgrade_handoff"
                ]["reservations"][0]["token"]
                + ".tmp"
            ).exists()
        )

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(result)
        final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installed", final["install_state"])
        self.assertNotIn("upgrade_handoff", final)
        self.assertEqual(shell_before, sandbox.shell_json.read_bytes())
        self.assertEqual(
            (REPOSITORY / "src/plugin/VisibilityModel.js").read_bytes(),
            visibility_model.read_bytes(),
        )

    def test_preserve_upgrade_corrects_plugin_enable_auto_inserted_placement(
        self,
    ) -> None:
        """Enable-time auto insertion must become the owned canonical placement."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.prepare_live_retained_visibility_restart_pending(sandbox)
        sandbox._write_fake_omarchy(
            False,
            discovery_delay=0,
            enable_exit=0,
            enable_auto_insert="before_agents",
            break_manifest_after_enable=False,
            break_manifest_after_bar_put=False,
            bar_put_mode="anchored",
            disable_rewrites_shell_then_fails=False,
            restart_fail_on_call=None,
        )
        shell_before = sandbox.shell_json.read_bytes()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assert_command_succeeded(result)
        self.assertEqual(
            ["omarchy.agents", PLUGIN_ID, "omarchy.bluetooth"],
            sandbox.widget_order(),
        )
        final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        shell_state = final["shell_config"]
        self.assertTrue(shell_state["bar_placement_owned_by_installer"])
        self.assertEqual("placed", shell_state["bar_placement_state"])
        self.assertEqual(
            hashlib.sha256(sandbox.shell_json.read_bytes()).hexdigest(),
            shell_state["post_enable_sha256"],
        )

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(shell_before, sandbox.shell_json.read_bytes())

    def test_preserve_upgrade_rejects_reordered_live_retained_visibility_plan(
        self,
    ) -> None:
        """A retained historical JS handoff must not absorb extra reservations."""
        sandbox = self.simulated_user(plugin_enabled=False)
        document, _ = self.prepare_live_retained_visibility_restart_pending(sandbox)
        handoff = document["upgrade_handoff"]
        assert isinstance(handoff, dict)
        reservations = handoff["reservations"]
        assert isinstance(reservations, list)
        extra = dict(reservations[0])
        token = "0123456789abcdef" * 4
        extra["token"] = token
        extra_path = sandbox.home / SHORTCUTS_RELATIVE_PATH
        extra["path"] = str(extra_path)
        extra["temporary_path"] = str(
            extra_path.with_name(f".{extra_path.name}.keyguide-upgrade-{token}.tmp")
        )
        reservations.insert(0, extra)
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n",
            encoding="utf-8",
        )
        shell_before = sandbox.shell_json.read_bytes()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("reservation plan is not trusted", result.stdout)
        self.assertEqual(shell_before, sandbox.shell_json.read_bytes())

    def test_preserve_upgrade_rejects_unowned_later_destination_in_live_retry(
        self,
    ) -> None:
        """Later current files remain ordinary absent new files on retry."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.prepare_live_retained_visibility_restart_pending(sandbox)
        shortcut_backend = sandbox.home / SHORTCUTS_RELATIVE_PATH
        shortcut_backend.parent.mkdir(parents=True, exist_ok=True)
        shortcut_backend.write_bytes(b"user-owned shortcuts\n")
        shortcut_backend.chmod(0o640)
        before = shortcut_backend.read_bytes()

        result = sandbox.run_make(
            "install", extra_env={"PRESERVE_USER_SHELL": "1"}
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("refusing to overwrite unowned path", result.stdout)
        self.assertEqual(before, shortcut_backend.read_bytes())

    def test_preserve_upgrade_accepts_custom_xdg_pre_visibility_inventory(
        self,
    ) -> None:
        """A custom-XDG icon-era manifest reserves every later dependency."""
        sandbox = self.simulated_user(plugin_enabled=False)
        custom_data_home = sandbox.home / "custom-data"
        custom_env = {"XDG_DATA_HOME": str(custom_data_home)}
        sandbox.prepare_retained_clock_edit(
            legacy_new_only=(
                BOUNDED_PROCESS_RELATIVE_PATH,
                VISIBILITY_MODEL_RELATIVE_PATH,
                SHORTCUTS_RELATIVE_PATH,
                SHORTCUT_EDIT_ROW_RELATIVE_PATH,
                EXECUTABLE_PICKER_RELATIVE_PATH,
            ),
            extra_env=custom_env,
        )
        custom_icon = (
            custom_data_home
            / "icons/hicolor/scalable/apps/omarchy-keyguide.svg"
        )
        expected_owned = [
            str(sandbox.home / relative)
            if relative != ICON_RELATIVE_PATH
            else str(custom_icon)
            for relative in PRE_VISIBILITY_MODEL_OWNED_RELATIVE_PATHS
        ]
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual(expected_owned, document["owned_files"])
        shell_before = sandbox.shell_json.read_bytes()

        result = sandbox.run_make(
            "install",
            extra_env={"PRESERVE_USER_SHELL": "1", **custom_env},
        )

        self.assert_command_succeeded(result)
        final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installed", final["install_state"])
        self.assertNotIn("upgrade_handoff", final)
        self.assertEqual(shell_before, sandbox.shell_json.read_bytes())
        self.assertEqual(
            (REPOSITORY / "assets/omarchy-keyguide.svg").read_bytes(),
            custom_icon.read_bytes(),
        )
        self.assertEqual(
            (REPOSITORY / "src/plugin/VisibilityModel.js").read_bytes(),
            (sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH).read_bytes(),
        )

    def test_uninstall_accepts_custom_xdg_pre_visibility_inventory(self) -> None:
        """A custom-XDG icon-era manifest must remove the custom icon safely."""
        sandbox = self.simulated_user(plugin_enabled=True)
        custom_data_home = sandbox.home / "custom-data"
        custom_env = {"XDG_DATA_HOME": str(custom_data_home)}
        self.assert_command_succeeded(sandbox.run_make("install", extra_env=custom_env))
        custom_icon = (
            custom_data_home
            / "icons/hicolor/scalable/apps/omarchy-keyguide.svg"
        )
        legacy_new_paths = (
            sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH,
            sandbox.home / SHORTCUTS_RELATIVE_PATH,
            sandbox.home / SHORTCUT_EDIT_ROW_RELATIVE_PATH,
            sandbox.home / EXECUTABLE_PICKER_RELATIVE_PATH,
            *(sandbox.home / relative for relative in LOCALIZED_SEARCH_RELATIVE_PATHS),
        )
        for path in legacy_new_paths:
            path.unlink()
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        for path in legacy_new_paths:
            document["owned_files"].remove(str(path))
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n",
            encoding="utf-8",
        )
        self.assertTrue(custom_icon.exists())

        result = sandbox.run_make("uninstall", extra_env=custom_env)

        self.assert_command_succeeded(result)
        self.assertFalse(custom_icon.exists())
        for path in legacy_new_paths:
            self.assertFalse(path.exists())
        self.assertFalse(sandbox.shell_json.exists())

    def test_custom_xdg_pre_visibility_inventory_rejects_path_injection(
        self,
    ) -> None:
        """Historical dynamic icon paths must remain exact and reject unsafe paths."""
        sandbox = self.simulated_user(plugin_enabled=True)
        custom_data_home = sandbox.home / "custom-data"
        custom_env = {"XDG_DATA_HOME": str(custom_data_home)}
        self.assert_command_succeeded(sandbox.run_make("install", extra_env=custom_env))
        legacy_new_paths = (
            sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH,
            sandbox.home / SHORTCUTS_RELATIVE_PATH,
            sandbox.home / SHORTCUT_EDIT_ROW_RELATIVE_PATH,
            sandbox.home / EXECUTABLE_PICKER_RELATIVE_PATH,
            *(sandbox.home / relative for relative in LOCALIZED_SEARCH_RELATIVE_PATHS),
        )
        for path in legacy_new_paths:
            path.unlink()
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        for path in legacy_new_paths:
            document["owned_files"].remove(str(path))
        custom_icon = (
            custom_data_home
            / "icons/hicolor/scalable/apps/omarchy-keyguide.svg"
        )
        injected_icon = (
            custom_data_home
            / ".."
            / "custom-data"
            / "icons/hicolor/scalable/apps/omarchy-keyguide.svg"
        )
        document["owned_files"] = [
            str(injected_icon) if path == str(custom_icon) else path
            for path in document["owned_files"]
        ]
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n",
            encoding="utf-8",
        )

        result = sandbox.run_make("uninstall", extra_env=custom_env)

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("install manifest", result.stdout)
        self.assertTrue(custom_icon.exists())

    def test_upgrade_ready_preinvocation_tamper_matrix_is_rejected(self) -> None:
        """Malformed persisted upgrade-ready state must fail before adoption."""
        def bad_schema(document: dict[str, object], sandbox: SimulatedUserInstall) -> None:
            document["schema_version"] = 2

        def bad_plugin_state(
            document: dict[str, object], sandbox: SimulatedUserInstall
        ) -> None:
            document["plugin_was_enabled"] = True

        def bad_plugin_id(
            document: dict[str, object], sandbox: SimulatedUserInstall
        ) -> None:
            document["plugin_id"] = "attacker.keyguide"

        def bad_target_home(
            document: dict[str, object], sandbox: SimulatedUserInstall
        ) -> None:
            document["target_home"] = str(sandbox.home.parent)

        def bad_owned_files(
            document: dict[str, object], sandbox: SimulatedUserInstall
        ) -> None:
            document["owned_files"] = [
                str(sandbox.home / OWNED_RELATIVE_PATHS[0])
            ]

        def bad_upgrade_reservation(
            document: dict[str, object], sandbox: SimulatedUserInstall
        ) -> None:
            handoff = document["upgrade_handoff"]
            assert isinstance(handoff, dict)
            reservations = handoff["reservations"]
            assert isinstance(reservations, list) and reservations
            reservation = reservations[0]
            assert isinstance(reservation, dict)
            token = reservation["token"]
            bad_path = sandbox.home / ".config/omarchy/plugins/mrai.keyguide/evil.qml"
            reservation["path"] = str(bad_path)
            reservation["temporary_path"] = str(
                bad_path.with_name(
                    f".{bad_path.name}.keyguide-upgrade-{token}.tmp"
                )
            )

        def reservation_path(relative_path: str, sandbox: SimulatedUserInstall) -> Path:
            return sandbox.home / relative_path

        def update_reservation_path(
            reservation: dict[str, object], path: Path
        ) -> None:
            token = reservation["token"]
            assert isinstance(token, str)
            reservation["path"] = str(path)
            reservation["temporary_path"] = str(
                path.with_name(f".{path.name}.keyguide-upgrade-{token}.tmp")
            )

        def write_reservation_token(reservation: dict[str, object]) -> None:
            path = Path(reservation["path"])
            token = reservation["token"]
            assert isinstance(token, str)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(token, encoding="ascii")
            path.chmod(0o600)

        def remove_reservation_token(reservation: dict[str, object]) -> None:
            Path(reservation["path"]).unlink(missing_ok=True)

        def handoff_reservations(
            document: dict[str, object],
        ) -> list[dict[str, object]]:
            handoff = document["upgrade_handoff"]
            assert isinstance(handoff, dict)
            reservations = handoff["reservations"]
            assert isinstance(reservations, list)
            assert all(isinstance(reservation, dict) for reservation in reservations)
            return reservations  # type: ignore[return-value]

        def bad_upgrade_reservation_reorder(
            document: dict[str, object], sandbox: SimulatedUserInstall
        ) -> None:
            reservations = handoff_reservations(document)
            assert len(reservations) >= 2
            reservations.reverse()

        def bad_upgrade_reservation_substitute_in_plan(
            document: dict[str, object], sandbox: SimulatedUserInstall
        ) -> None:
            reservations = handoff_reservations(document)
            assert reservations
            remove_reservation_token(reservations[0])
            replacement = reservation_path(
                ".config/omarchy/plugins/mrai.keyguide/components/BindingRow.qml",
                sandbox,
            )
            update_reservation_path(reservations[0], replacement)
            write_reservation_token(reservations[0])

        def bad_upgrade_reservation_add_in_plan(
            document: dict[str, object], sandbox: SimulatedUserInstall
        ) -> None:
            reservations = handoff_reservations(document)
            extra = {
                "path": "",
                "token": "0123456789abcdef" * 4,
                "temporary_path": "",
            }
            replacement = reservation_path(
                ".config/omarchy/plugins/mrai.keyguide/components/BindingRow.qml",
                sandbox,
            )
            update_reservation_path(extra, replacement)
            reservations.append(extra)
            write_reservation_token(extra)

        def bad_upgrade_reservation_remove_in_plan(
            document: dict[str, object], sandbox: SimulatedUserInstall
        ) -> None:
            reservations = handoff_reservations(document)
            assert reservations
            removed = reservations.pop(0)
            remove_reservation_token(removed)

        cases = {
            "schema": bad_schema,
            "plugin_state": bad_plugin_state,
            "plugin_id": bad_plugin_id,
            "target_home": bad_target_home,
            "owned_files": bad_owned_files,
            "upgrade_reservation": bad_upgrade_reservation,
            "upgrade_reservation_reorder": bad_upgrade_reservation_reorder,
            "upgrade_reservation_substitute_in_plan": (
                bad_upgrade_reservation_substitute_in_plan
            ),
            "upgrade_reservation_add_in_plan": bad_upgrade_reservation_add_in_plan,
            "upgrade_reservation_remove_in_plan": (
                bad_upgrade_reservation_remove_in_plan
            ),
        }
        for name, tamper in cases.items():
            with self.subTest(name=name):
                sandbox = self.simulated_user(plugin_enabled=False)
                sandbox.prepare_retained_clock_edit()
                self.assert_command_succeeded(
                    sandbox.run_preserve_uninstall_to_upgrade_ready()
                )
                shell_before = sandbox.shell_json.read_bytes()
                commands_before = list(sandbox.commands())
                document = json.loads(
                    sandbox.manifest.read_text(encoding="utf-8")
                )
                self.assertEqual("upgrade_ready", document["install_state"])
                tamper(document, sandbox)
                sandbox.manifest.write_text(
                    json.dumps(document, indent=2) + "\n",
                    encoding="utf-8",
                )

                result = sandbox.run_make(
                    "install", extra_env={"PRESERVE_USER_SHELL": "1"}
                )

                self.assertNotEqual(0, result.returncode, result.stdout)
                if name.startswith("upgrade_reservation"):
                    self.assertIn("reservation plan is not trusted", result.stdout)
                else:
                    self.assertIn("manifest validation failed", result.stdout)
                self.assertEqual(shell_before, sandbox.shell_json.read_bytes())
                self.assertNotIn(
                    f"bar put {PLUGIN_ID} --after omarchy.agents",
                    sandbox.commands()[len(commands_before):],
                )

    def test_payload_publication_preserves_concurrent_replacements(self) -> None:
        """Publishing payloads must not overwrite a replacement reservation."""
        for kind in ("regular", "symlink", "fifo"):
            with self.subTest(kind=kind):
                sandbox = self.simulated_user(plugin_enabled=False)
                sandbox.prepare_retained_clock_edit()
                marker, victim, replacement = (
                    sandbox.inject_payload_publication_replacement(kind)
                )

                try:
                    result = sandbox.run_make(
                        "install",
                        extra_env={"PRESERVE_USER_SHELL": "1"},
                        timeout=20,
                    )
                except subprocess.TimeoutExpired:
                    self.fail(f"{kind} replacement blocked payload publication")

                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertTrue(marker.is_file())
                icon = sandbox.home / ICON_RELATIVE_PATH
                if kind == "regular":
                    self.assertEqual(replacement, icon.read_bytes())
                elif kind == "symlink":
                    self.assertTrue(icon.is_symlink())
                    self.assertEqual(victim, icon.resolve())
                    self.assertEqual(
                        b"user-owned symlink victim\n", victim.read_bytes()
                    )
                else:
                    self.assertTrue(stat.S_ISFIFO(icon.lstat().st_mode))
                self.assertTrue(sandbox.manifest.is_file())

    def test_payload_replacement_after_verification_is_not_journaled(self) -> None:
        """A replacement after payload verification must not become owned."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        marker, replacement = sandbox.inject_payload_replacement_before_manifest_journal()

        result = sandbox.run_make(
            "install",
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "KEYGUIDE_TEST_HOOK_PAYLOAD_AFTER_VERIFY_BEFORE_JOURNAL": str(marker),
            },
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        icon = sandbox.home / ICON_RELATIVE_PATH
        self.assertEqual(replacement, icon.read_bytes())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertNotEqual("installed", document["install_state"])
        self.assertNotIn(str(icon), document["owned_files"])

    def test_same_payload_replacement_after_verification_is_not_journaled(
        self,
    ) -> None:
        """A same-bytes/mode new inode after verification must not become owned."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        marker, replacement = (
            sandbox.inject_same_payload_replacement_before_manifest_journal()
        )

        result = sandbox.run_make(
            "install",
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "KEYGUIDE_TEST_HOOK_PAYLOAD_AFTER_VERIFY_BEFORE_JOURNAL_SAME_BYTES": str(marker),
            },
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        icon = sandbox.home / ICON_RELATIVE_PATH
        self.assertEqual(replacement, icon.read_bytes())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertNotEqual("installed", document["install_state"])
        self.assertNotIn(str(icon), document["owned_files"])

    def test_shell_edit_before_bar_placement_is_not_mutated(self) -> None:
        """A concurrent shell edit after journaling must not get Keyguide inserted."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        marker = sandbox.inject_shell_edit_before_bar_placement()

        result = sandbox.run_make(
            "install",
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "KEYGUIDE_TEST_HOOK_SHELL_BEFORE_BAR_PLACE": str(marker),
            },
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        shell_document = json.loads(sandbox.shell_json.read_text(encoding="utf-8"))
        self.assertEqual("retained", shell_document["concurrentUserEdit"])
        layout_entries = [
            entry.get("id")
            for section in shell_document["bar"]["layout"].values()
            for entry in section
        ]
        self.assertNotIn("mrai.keyguide", layout_entries)

    def test_odd_shell_edit_before_bar_placement_is_restored_byte_exact(
        self,
    ) -> None:
        """Rollback must preserve exact concurrent shell bytes and mode."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        marker, odd_bytes = sandbox.inject_odd_shell_edit_before_bar_placement()

        result = sandbox.run_make(
            "install",
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "KEYGUIDE_TEST_HOOK_SHELL_BEFORE_BAR_PLACE_ODD_BYTES": str(marker),
            },
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        self.assertEqual(odd_bytes, sandbox.shell_json.read_bytes())
        self.assertEqual(0o640, stat.S_IMODE(sandbox.shell_json.stat().st_mode))

    def test_shell_capture_owner_loss_aborts_before_bar_placement(self) -> None:
        """Unreproducible capture owner metadata must fail before bar mutation."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        before = sandbox.shell_json.read_bytes()
        commands_before = list(sandbox.commands())
        marker = sandbox.inject_shell_capture_owner_loss_before_bar_placement()

        result = sandbox.run_make(
            "install",
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "KEYGUIDE_TEST_HOOK_SHELL_CAPTURE_OWNER_LOSS": str(marker),
            },
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        self.assertIn("capture", result.stdout.lower())
        self.assertIn("owner", result.stdout.lower())
        self.assertNotEqual(before, sandbox.shell_json.read_bytes())
        shell_document = json.loads(sandbox.shell_json.read_text(encoding="utf-8"))
        layout_entries = [
            entry.get("id")
            for section in shell_document["bar"]["layout"].values()
            for entry in section
        ]
        self.assertNotIn("mrai.keyguide", layout_entries)
        self.assertNotIn(
            f"bar put {PLUGIN_ID} --after omarchy.agents",
            sandbox.commands()[len(commands_before):],
        )

    def test_shell_rollback_final_verification_failure_is_not_masked(self) -> None:
        """Rollback must verify final endpoint and surface verification failure."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        marker = sandbox.inject_shell_rollback_final_change()

        result = sandbox.run_make(
            "install",
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "KEYGUIDE_TEST_HOOK_SHELL_BEFORE_BAR_PLACE_ODD_BYTES": str(marker.with_suffix(".odd")),
                "KEYGUIDE_TEST_HOOK_SHELL_ROLLBACK_FINAL_CHANGE": str(marker),
            },
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        self.assertIn("rollback", result.stdout.lower())
        self.assertIn("final", result.stdout.lower())
        self.assertTrue(sandbox.manifest.exists())

    def test_upgrade_handoff_change_before_adoption_is_rejected(self) -> None:
        """The install side must adopt the exact inspected handoff document."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        marker = sandbox.inject_upgrade_ready_manifest_change_before_install_adoption()

        result = sandbox.run_make(
            "install",
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "KEYGUIDE_TEST_HOOK_UPGRADE_HANDOFF_BEFORE_ADOPT": str(marker),
            },
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        self.assertIn("install manifest changed before publication", result.stdout)

    def test_upgrade_reservation_parent_symlink_is_rejected(self) -> None:
        """Upgrade reservations must reject symlinked intermediate parents."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.prepare_retained_clock_edit()
        marker, escaped = sandbox.inject_upgrade_reservation_parent_symlink()

        result = sandbox.run_make(
            "install",
            extra_env={
                "PRESERVE_USER_SHELL": "1",
                "KEYGUIDE_TEST_HOOK_UPGRADE_RESERVATION_PARENT_SYMLINK": str(marker),
                "KEYGUIDE_TEST_HOOK_UPGRADE_RESERVATION_PARENT_ESCAPE": str(escaped),
            },
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        self.assertIn("symlink", result.stdout.lower())
        self.assertEqual([], list(escaped.iterdir()))

    def test_preserve_upgrade_recovers_payload_publication_crashes(self) -> None:
        """Both durable payload publication states must resume without orphans."""
        for boundary in ("exchange", "cleanup"):
            with self.subTest(boundary=boundary):
                sandbox = self.simulated_user(plugin_enabled=False)
                sandbox.prepare_retained_clock_edit()
                marker = sandbox.crash_during_payload_publication(boundary)

                first = sandbox.run_make(
                    "install", extra_env={"PRESERVE_USER_SHELL": "1"}
                )

                self.assertNotEqual(0, first.returncode, first.stdout)
                self.assertTrue(marker.is_file())
                interrupted = json.loads(
                    sandbox.manifest.read_text(encoding="utf-8")
                )
                pending = interrupted.get("pending_reservation")
                self.assertIsInstance(pending, dict)
                self.assertEqual(
                    str(sandbox.home / ICON_RELATIVE_PATH), pending["path"]
                )
                self.assertRegex(pending.get("payload_sha256", ""), r"^[0-9a-f]{64}$")

                second = sandbox.run_make(
                    "install", extra_env={"PRESERVE_USER_SHELL": "1"}
                )

                self.assert_command_succeeded(second)
                final = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
                self.assertEqual("installed", final["install_state"])
                self.assertIsNone(final["pending_reservation"])
                self.assertNotIn("upgrade_handoff", final)
                self.assertFalse(Path(pending["temporary_path"]).exists())
                self.assertEqual(
                    (REPOSITORY / "assets/omarchy-keyguide.svg").read_bytes(),
                    (sandbox.home / ICON_RELATIVE_PATH).read_bytes(),
                )

    def test_recovery_restores_a_displaced_concurrent_payload_endpoint(
        self,
    ) -> None:
        """A crash after exchange must return a displaced endpoint to its path."""
        for kind in ("regular", "symlink", "fifo"):
            with self.subTest(kind=kind):
                sandbox = self.simulated_user(plugin_enabled=False)
                sandbox.prepare_retained_clock_edit()
                marker, crash_marker, victim, replacement = (
                    sandbox.crash_after_payload_exchange_with_replacement(kind)
                )

                first = sandbox.run_make(
                    "install", extra_env={"PRESERVE_USER_SHELL": "1"}
                )
                self.assertNotEqual(0, first.returncode, first.stdout)
                self.assertTrue(marker.is_file())
                self.assertTrue(crash_marker.is_file())

                try:
                    second = sandbox.run_make(
                        "install",
                        extra_env={"PRESERVE_USER_SHELL": "1"},
                        timeout=8,
                    )
                except subprocess.TimeoutExpired:
                    self.fail(f"{kind} displaced endpoint blocked recovery")

                self.assertNotEqual(0, second.returncode, second.stdout)
                icon = sandbox.home / ICON_RELATIVE_PATH
                if kind == "regular":
                    self.assertEqual(replacement, icon.read_bytes())
                elif kind == "symlink":
                    self.assertTrue(icon.is_symlink())
                    self.assertEqual(victim, icon.resolve())
                    self.assertEqual(
                        b"user-owned displaced symlink victim\n",
                        victim.read_bytes(),
                    )
                else:
                    self.assertTrue(stat.S_ISFIFO(icon.lstat().st_mode))
                self.assertTrue(sandbox.manifest.is_file())

    def test_uninstall_rejects_stale_noncanonical_placing_transforms(self) -> None:
        """A stale placing intent must not authorize invalid shell mutations."""
        def layout_sections(document: dict[str, object]) -> dict[str, list[object]]:
            bar = document.setdefault("bar", {})
            assert isinstance(bar, dict)
            layout = bar.setdefault("layout", {})
            assert isinstance(layout, dict)
            for section in ("left", "center", "right"):
                layout.setdefault(section, [])
                assert isinstance(layout[section], list)
            return layout  # type: ignore[return-value]

        def entry_id(entry: object) -> object:
            return entry.get("id") if isinstance(entry, dict) else entry

        def add_canonical_keyguide(
            document: dict[str, object]
        ) -> dict[str, object]:
            layout = layout_sections(document)
            for section in ("left", "center", "right"):
                ids = [entry_id(entry) for entry in layout[section]]
                if "omarchy.agents" in ids:
                    entry: dict[str, object] = {"id": PLUGIN_ID}
                    layout[section].insert(ids.index("omarchy.agents") + 1, entry)
                    return entry
            entry = {"id": PLUGIN_ID}
            layout["center"].append(entry)
            return entry

        def write_transform(sandbox: SimulatedUserInstall, mode: str) -> None:
            document = json.loads(sandbox.shell_json.read_text(encoding="utf-8"))
            layout = layout_sections(document)
            if mode == "misplaced":
                for section in ("left", "center", "right"):
                    layout[section] = [
                        entry
                        for entry in layout[section]
                        if entry_id(entry) != PLUGIN_ID
                    ]
                layout["center"].append({"id": PLUGIN_ID})
            else:
                entry = add_canonical_keyguide(document)
                if mode == "duplicate":
                    layout["left"].append({"id": PLUGIN_ID})
                elif mode == "entry_settings":
                    entry["opacity"] = 0.5
                elif mode == "unrelated":
                    document["userEdit"] = True
                elif mode == "boolean_to_integer":
                    document["userFlag"] = 1
                elif mode != "mode_change":
                    raise AssertionError(f"unsupported mode: {mode}")
            sandbox.shell_json.write_text(
                json.dumps(document, indent=2) + "\n", encoding="utf-8"
            )
            if mode == "mode_change":
                sandbox.shell_json.chmod(0o600)

        for mode in (
            "misplaced",
            "duplicate",
            "entry_settings",
            "unrelated",
            "mode_change",
            "boolean_to_integer",
        ):
            with self.subTest(mode=mode):
                sandbox = self.simulated_user(
                    plugin_enabled=True,
                    bar_put_mode="fail_before",
                )
                sandbox.write_shell_layout(
                    right=["omarchy.agents", "omarchy.bluetooth"]
                )
                if mode == "boolean_to_integer":
                    preimage = json.loads(
                        sandbox.shell_json.read_text(encoding="utf-8")
                    )
                    preimage["userFlag"] = True
                    sandbox.shell_json.write_text(
                        json.dumps(preimage, indent=2) + "\n",
                        encoding="utf-8",
                    )

                install_result = sandbox.run_make("install")

                self.assertNotEqual(0, install_result.returncode, install_result.stdout)
                document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
                self.assertEqual(
                    "placing", document["shell_config"].get("bar_placement_state")
                )
                write_transform(sandbox, mode)
                transformed = sandbox.shell_json.read_bytes()

                uninstall_result = sandbox.run_make("uninstall")

                self.assertNotEqual(
                    0, uninstall_result.returncode, uninstall_result.stdout
                )
                self.assertIn("placing bar transform", uninstall_result.stdout)
                self.assertEqual(transformed, sandbox.shell_json.read_bytes())
                self.assertTrue(sandbox.manifest.exists())
                self.assertTrue((sandbox.home / OWNED_RELATIVE_PATHS[0]).exists())

    def test_uninstall_restores_shell_json_absence_after_owned_bar_put(
        self,
    ) -> None:
        """A first-created shell document must be removed only while unchanged."""
        sandbox = self.simulated_user(plugin_enabled=True)
        self.assertFalse(sandbox.shell_json.exists())

        self.assert_command_succeeded(sandbox.run_make("install"))

        self.assertTrue(sandbox.shell_json.exists())
        self.assertIn(PLUGIN_ID, sandbox.widget_order())
        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.shell_json.exists())

    def test_atomic_shell_removal_restores_a_late_concurrent_edit(self) -> None:
        """An edit after the absence check must not be unlinked."""
        sandbox = self.simulated_user(plugin_enabled=True)
        self.assert_command_succeeded(sandbox.run_make("install"))
        captured = sandbox.inject_late_concurrent_shell_remove_edit()

        result = sandbox.run_make("uninstall")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("live shell endpoint changed during atomic removal", result.stdout)
        self.assertTrue(captured.is_file())
        self.assertEqual(captured.read_bytes(), sandbox.shell_json.read_bytes())
        self.assertTrue(sandbox.manifest.exists())

    def test_failed_restart_retains_restored_bar_transaction_for_retry(
        self,
    ) -> None:
        """Restart retry state must follow a durable exact bar restoration."""
        sandbox = self.simulated_user(
            plugin_enabled=False,
            restart_fail_on_call=2,
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()
        self.assert_command_succeeded(sandbox.run_make("install"))
        self.assertIn(PLUGIN_ID, sandbox.widget_order())

        first_uninstall = sandbox.run_make("uninstall")

        self.assertNotEqual(
            0, first_uninstall.returncode, first_uninstall.stdout
        )
        self.assertEqual(original, sandbox.shell_json.read_bytes())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("restart_pending", document["install_state"])
        self.assertFalse(
            document["shell_config"]["bar_placement_owned_by_installer"]
        )
        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.manifest.exists())

    def test_uninstall_retries_from_authenticated_installed_postimage(
        self,
    ) -> None:
        """A failed preimage restore must leave a durable restoring journal."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        self.assert_command_succeeded(sandbox.run_make("install"))
        installed = sandbox.shell_json.read_bytes()
        sandbox.fail_next_shell_restore_before_copy()

        first_uninstall = sandbox.run_make("uninstall")

        self.assertNotEqual(0, first_uninstall.returncode, first_uninstall.stdout)
        self.assertEqual(installed, sandbox.shell_json.read_bytes())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            "restoring", document["shell_config"]["restore_state"]
        )

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.manifest.exists())

    def test_uninstall_avoids_shell_mutating_disable_interruption_interval(
        self,
    ) -> None:
        """Exact preimage restore must not cross an unauthenticated disable state."""
        sandbox = self.simulated_user(
            plugin_enabled=False,
            disable_rewrites_shell_then_fails=True,
        )
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()
        self.assert_command_succeeded(sandbox.run_make("install"))

        result = sandbox.run_make("uninstall")

        self.assert_command_succeeded(result)
        self.assertEqual(original, sandbox.shell_json.read_bytes())
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", sandbox.commands())
        self.assertFalse(sandbox.manifest.exists())

    def test_uninstall_retries_from_authenticated_restored_preimage(
        self,
    ) -> None:
        """A failed ownership-clear write must resume from exact restored bytes."""
        for plugin_enabled in (True, False):
            with self.subTest(plugin_enabled=plugin_enabled):
                sandbox = self.simulated_user(plugin_enabled=plugin_enabled)
                sandbox.write_shell_layout(
                    right=["omarchy.agents", "omarchy.bluetooth"]
                )
                original = sandbox.shell_json.read_bytes()
                self.assert_command_succeeded(sandbox.run_make("install"))
                sandbox.fail_manifest_write_after_shell_restore()

                first_uninstall = sandbox.run_make("uninstall")

                self.assertNotEqual(
                    0, first_uninstall.returncode, first_uninstall.stdout
                )
                self.assertEqual(original, sandbox.shell_json.read_bytes())
                document = json.loads(
                    sandbox.manifest.read_text(encoding="utf-8")
                )
                self.assertEqual(
                    "restoring", document["shell_config"]["restore_state"]
                )
                sandbox.manifest.parent.chmod(0o700)

                self.assert_command_succeeded(sandbox.run_make("uninstall"))
                self.assertFalse(sandbox.manifest.exists())

    def test_atomic_restore_staging_failure_keeps_installed_endpoint(self) -> None:
        """A partial staging write must never become the live shell document."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()
        self.assert_command_succeeded(sandbox.run_make("install"))
        installed = sandbox.shell_json.read_bytes()
        call_log = sandbox.inject_atomic_shell_restore_fault(
            "partial_stage",
            direct_install_fault="partial_live",
        )

        first_uninstall = sandbox.run_make("uninstall")

        self.assertNotEqual(0, first_uninstall.returncode, first_uninstall.stdout)
        self.assertEqual(installed, sandbox.shell_json.read_bytes())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("restoring", document["shell_config"]["restore_state"])

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, sandbox.shell_json.read_bytes())
        self.assertEqual(2, call_log.read_text(encoding="utf-8").count("restore\n"))

    def test_atomic_restore_publishes_final_mode_before_parent_fsync(self) -> None:
        """A rename/fsync fault must expose the complete preimage at its final mode."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        sandbox.shell_json.chmod(0o640)
        original = sandbox.shell_json.read_bytes()
        self.assert_command_succeeded(sandbox.run_make("install"))
        call_log = sandbox.inject_atomic_shell_restore_fault(
            "parent_fsync",
            direct_install_fault="wrong_mode",
        )

        first_uninstall = sandbox.run_make("uninstall")

        self.assertNotEqual(0, first_uninstall.returncode, first_uninstall.stdout)
        self.assertEqual(original, sandbox.shell_json.read_bytes())
        self.assertEqual(0o640, stat.S_IMODE(sandbox.shell_json.stat().st_mode))
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("restoring", document["shell_config"]["restore_state"])

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(2, call_log.read_text(encoding="utf-8").count("restore\n"))

    def test_absent_restore_retries_parent_durability_before_clearing(self) -> None:
        """An unlink is not complete until a retry fsyncs the shell parent."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.assertFalse(sandbox.shell_json.exists())
        self.assert_command_succeeded(sandbox.run_make("install"))
        self.assertTrue(sandbox.shell_json.exists())
        call_log = sandbox.inject_atomic_shell_restore_fault("parent_fsync")

        first_uninstall = sandbox.run_make("uninstall")

        self.assertNotEqual(0, first_uninstall.returncode, first_uninstall.stdout)
        self.assertFalse(sandbox.shell_json.exists())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("restoring", document["shell_config"]["restore_state"])

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(2, call_log.read_text(encoding="utf-8").count("restore\n"))

    def test_install_records_authenticated_shell_preimage(self) -> None:
        """A backup without its original content hash cannot be trusted later."""
        sandbox = self.simulated_user(plugin_enabled=True)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()

        self.assert_command_succeeded(sandbox.run_make("install"))

        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            hashlib.sha256(original).hexdigest(),
            document["shell_config"]["pre_sha256"],
        )
        self.assertEqual(os.getuid(), document["shell_config"]["pre_uid"])
        self.assertEqual(os.getgid(), document["shell_config"]["pre_gid"])
        backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
        self.assertEqual(os.getuid(), backup.stat().st_uid)
        self.assertEqual(os.getgid(), backup.stat().st_gid)

    def test_backup_failure_has_a_durable_cleanup_intent(self) -> None:
        """An interrupted first backup must not wedge install and uninstall."""
        sandbox = self.simulated_user(plugin_enabled=True)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()
        sandbox.fail_next_shell_backup_before_copy()

        first_install = sandbox.run_make("install")

        self.assertNotEqual(0, first_install.returncode, first_install.stdout)
        self.assertTrue(sandbox.manifest.exists())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installing", document["install_state"])
        self.assertEqual([], document["owned_files"])
        self.assertEqual(original, sandbox.shell_json.read_bytes())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.manifest.exists())
        self.assertFalse(
            (sandbox.manifest.parent / "shell.json.pre-keyguide").exists()
        )
        self.assert_command_succeeded(sandbox.run_make("install"))

    def test_uninstall_rejects_a_tampered_shell_preimage_before_mutation(
        self,
    ) -> None:
        """Corrupt backup bytes must not disable the plugin or overwrite the shell."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        self.assert_command_succeeded(sandbox.run_make("install"))
        installed = sandbox.shell_json.read_bytes()
        backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
        backup.write_bytes(b'{"tampered":true}\n')

        result = sandbox.run_make("uninstall")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("pre-image hash", result.stdout)
        self.assertEqual(installed, sandbox.shell_json.read_bytes())
        self.assertTrue(sandbox.enabled_state.exists())
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", sandbox.commands())
        self.assertTrue((sandbox.home / OWNED_RELATIVE_PATHS[0]).exists())

    def test_uninstall_rejects_shell_preimage_owner_mismatch(self) -> None:
        """Owner metadata mismatch must fail before disabling or shell restore."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(right=["omarchy.agents"])
        self.assert_command_succeeded(sandbox.run_make("install"))
        installed = sandbox.shell_json.read_bytes()
        sandbox.tamper_shell_preimage_owner_in_manifest()

        result = sandbox.run_make("uninstall")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("owner", result.stdout)
        self.assertEqual(installed, sandbox.shell_json.read_bytes())
        self.assertTrue(sandbox.enabled_state.exists())
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", sandbox.commands())

    def test_shell_restore_rejects_final_owner_loss_before_clearing_state(
        self,
    ) -> None:
        """Restore must verify final uid/gid before clearing shell ownership."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(right=["omarchy.agents"])
        self.assert_command_succeeded(sandbox.run_make("install"))
        installed = sandbox.shell_json.read_bytes()
        marker = sandbox.inject_shell_restore_owner_loss()

        result = sandbox.run_make(
            "uninstall",
            extra_env={
                "KEYGUIDE_TEST_HOOK_SHELL_RESTORE_OWNER_LOSS": str(marker),
            },
        )

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertTrue(marker.is_file(), result.stdout)
        self.assertIn("owner", result.stdout.lower())
        self.assertTrue(sandbox.manifest.exists())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("restoring", document["shell_config"]["restore_state"])
        self.assertEqual(installed, sandbox.shell_json.read_bytes())

    def test_uninstall_rejects_inconsistent_preimage_metadata_before_mutation(
        self,
    ) -> None:
        """Missing mode metadata must fail before disable or shell restoration."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        self.assert_command_succeeded(sandbox.run_make("install"))
        installed = sandbox.shell_json.read_bytes()
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        document["shell_config"]["pre_mode"] = ""
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

        result = sandbox.run_make("uninstall")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("inconsistent shell pre-image metadata", result.stdout)
        self.assertEqual(installed, sandbox.shell_json.read_bytes())
        self.assertTrue(sandbox.enabled_state.exists())
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", sandbox.commands())

    def test_uninstall_accepts_pre_complete_hud_manifest_for_upgrade(self) -> None:
        """The installed MVP fileset must remain safely removable for upgrade."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        legacy_paths = [
            sandbox.home / BOUNDED_PROCESS_RELATIVE_PATH,
            sandbox.home
            / ".local/lib/omarchy-keyguide/keyguide_backend/groups.py",
            sandbox.home
            / ".local/lib/omarchy-keyguide/keyguide_backend/presentation.py",
            sandbox.home
            / ".config/omarchy/plugins/mrai.keyguide/BarWidget.qml",
            sandbox.home / VISIBILITY_MODEL_RELATIVE_PATH,
            sandbox.home / ICON_RELATIVE_PATH,
            sandbox.home / SHORTCUTS_RELATIVE_PATH,
            sandbox.home / SHORTCUT_EDIT_ROW_RELATIVE_PATH,
            sandbox.home / EXECUTABLE_PICKER_RELATIVE_PATH,
            *(sandbox.home / relative for relative in LOCALIZED_SEARCH_RELATIVE_PATHS),
        ]
        for path in legacy_paths:
            path.unlink(missing_ok=True)
            try:
                document["owned_files"].remove(str(path))
            except ValueError:
                pass
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

        self.assert_command_succeeded(sandbox.uninstall())

        self.assertFalse(sandbox.manifest.exists())
        for path in sandbox.owned_paths():
            self.assertFalse(path.exists(), str(path))

    def test_uninstall_accepts_manifest_from_before_bounded_process(self) -> None:
        """The current public fileset remains exactly removable after this fix."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        limiter = sandbox.home / BOUNDED_PROCESS_RELATIVE_PATH
        limiter.unlink()
        document["owned_files"].remove(str(limiter))
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

        self.assert_command_succeeded(sandbox.uninstall())

        self.assertFalse(sandbox.manifest.exists())
        for path in sandbox.owned_paths():
            self.assertFalse(path.exists(), str(path))

    def test_uninstall_accepts_manifest_from_before_executable_picker(self) -> None:
        """The immediately preceding fileset must remain safely removable."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        for relative in (
            BOUNDED_PROCESS_RELATIVE_PATH,
            EXECUTABLE_PICKER_RELATIVE_PATH,
            *LOCALIZED_SEARCH_RELATIVE_PATHS,
        ):
            path = sandbox.home / relative
            path.unlink()
            document["owned_files"].remove(str(path))
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

        self.assert_command_succeeded(sandbox.uninstall())

        self.assertFalse(sandbox.manifest.exists())
        for path in sandbox.owned_paths():
            self.assertFalse(path.exists(), str(path))

    def test_uninstall_accepts_manifest_from_before_localized_search(self) -> None:
        """The previous picker-era fileset remains exactly removable."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        for relative in (
            BOUNDED_PROCESS_RELATIVE_PATH,
            *LOCALIZED_SEARCH_RELATIVE_PATHS,
        ):
            path = sandbox.home / relative
            path.unlink()
            document["owned_files"].remove(str(path))
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

        self.assert_command_succeeded(sandbox.uninstall())

        self.assertFalse(sandbox.manifest.exists())
        for path in sandbox.owned_paths():
            self.assertFalse(path.exists(), str(path))

    def test_uninstall_accepts_exact_pre_icon_manifest_for_upgrade(self) -> None:
        """The exact deployed pre-icon fileset must remain safely removable."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        historical_relative_paths = set(PRE_ICON_OWNED_RELATIVE_PATHS)
        for relative in OWNED_RELATIVE_PATHS:
            if relative not in historical_relative_paths:
                (sandbox.home / relative).unlink()
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        historical_owned_files = [
            str(sandbox.home / relative)
            for relative in PRE_ICON_OWNED_RELATIVE_PATHS
        ]
        document["owned_files"] = historical_owned_files
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

        self.assertEqual(
            historical_owned_files,
            json.loads(sandbox.manifest.read_text(encoding="utf-8"))["owned_files"],
        )
        self.assert_command_succeeded(sandbox.uninstall())

        self.assertFalse(sandbox.manifest.exists())
        for relative in PRE_ICON_OWNED_RELATIVE_PATHS:
            self.assertFalse((sandbox.home / relative).exists(), relative)

    def test_uninstall_migrates_authenticated_placement_era_manifest(
        self,
    ) -> None:
        """The deployed placement-era schema must gain a proven preimage hash."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        original = sandbox.shell_json.read_bytes()
        self.assert_command_succeeded(sandbox.run_make("install"))
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        del document["shell_config"]["pre_sha256"]
        del document["shell_config"]["restore_state"]
        del document["shell_config"]["bar_placement_state"]
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )
        sandbox.fail_next_shell_restore_before_copy()

        first_uninstall = sandbox.run_make("uninstall")

        self.assertNotEqual(0, first_uninstall.returncode, first_uninstall.stdout)
        migrated = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual(
            hashlib.sha256(original).hexdigest(),
            migrated["shell_config"]["pre_sha256"],
        )
        self.assertEqual(
            "restoring", migrated["shell_config"]["restore_state"]
        )
        self.assertEqual(original, (sandbox.manifest.parent / "shell.json.pre-keyguide").read_bytes())

        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, sandbox.shell_json.read_bytes())
        self.assertFalse(sandbox.manifest.exists())

    def test_uninstall_migrates_retained_deployed_shell_transition(self) -> None:
        """The retained placement-era plugin-to-bar move is authenticated."""
        sandbox = self.simulated_user(plugin_enabled=False)
        before = (FIXTURES / "task5-retained-before-shell.json").read_bytes()
        after = (FIXTURES / "task5-retained-final-shell.json").read_bytes()
        sandbox.shell_json.parent.mkdir(parents=True, exist_ok=True)
        sandbox.shell_json.write_bytes(before)
        self.assert_command_succeeded(sandbox.run_make("install"))
        sandbox.shell_json.write_bytes(after)
        backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
        backup.write_bytes(before)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        shell_state = document["shell_config"]
        shell_state["post_enable_sha256"] = hashlib.sha256(
            after
        ).hexdigest()
        del shell_state["pre_sha256"]
        del shell_state["restore_state"]
        del shell_state["bar_placement_state"]
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )

        self.assert_command_succeeded(sandbox.run_make("uninstall"))

        self.assertEqual(before, sandbox.shell_json.read_bytes())
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", sandbox.commands())
        self.assertFalse(sandbox.manifest.exists())

    def test_uninstall_rejects_mutated_retained_deployed_preimage(self) -> None:
        """Only the exact canonical plugin-to-bar move may seed a legacy hash."""
        mutations = {
            "plugin settings": lambda doc: doc["plugins"][0].update(
                {"opacity": 0.5}
            ),
            "duplicate plugin": lambda doc: doc["plugins"].append(
                {"id": PLUGIN_ID}
            ),
            "unrelated field": lambda doc: doc["idle"].update({"lock": 42}),
            "boolean to integer": lambda doc: doc["bar"].update(
                {"transparent": int(doc["bar"]["transparent"])}
            ),
        }
        for label, mutate in mutations.items():
            with self.subTest(label=label):
                sandbox = self.simulated_user(plugin_enabled=False)
                before = json.loads(
                    (FIXTURES / "task5-retained-before-shell.json").read_text()
                )
                after = (FIXTURES / "task5-retained-final-shell.json").read_bytes()
                sandbox.shell_json.parent.mkdir(parents=True, exist_ok=True)
                sandbox.shell_json.write_bytes(after)
                self.assert_command_succeeded(sandbox.run_make("install"))
                sandbox.shell_json.write_bytes(after)
                document = json.loads(sandbox.manifest.read_text())
                shell_state = document["shell_config"]
                shell_state["post_enable_sha256"] = hashlib.sha256(after).hexdigest()
                del shell_state["pre_sha256"]
                del shell_state["restore_state"]
                del shell_state["bar_placement_state"]
                mutate(before)
                backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
                backup.write_text(json.dumps(before, indent=2) + "\n")
                sandbox.manifest.write_text(json.dumps(document, indent=2) + "\n")

                result = sandbox.run_make("uninstall")

                self.assertNotEqual(0, result.returncode, result.stdout)
                self.assertIn("legacy shell pre-image", result.stdout)
                self.assertEqual(after, sandbox.shell_json.read_bytes())
                self.assertTrue(sandbox.manifest.exists())

    def test_uninstall_rejects_unrelated_legacy_backup_difference(
        self,
    ) -> None:
        """Legacy hash derivation must reject backup changes beyond owned state."""
        sandbox = self.simulated_user(plugin_enabled=False)
        sandbox.write_shell_layout(
            right=["omarchy.agents", "omarchy.bluetooth"]
        )
        self.assert_command_succeeded(sandbox.run_make("install"))
        installed = sandbox.shell_json.read_bytes()
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        del document["shell_config"]["pre_sha256"]
        del document["shell_config"]["restore_state"]
        del document["shell_config"]["bar_placement_state"]
        sandbox.manifest.write_text(
            json.dumps(document, indent=2) + "\n", encoding="utf-8"
        )
        backup = sandbox.manifest.parent / "shell.json.pre-keyguide"
        backup_document = json.loads(backup.read_text(encoding="utf-8"))
        backup_document["unrelated"] = "tampered"
        backup.write_text(
            json.dumps(backup_document, indent=2) + "\n", encoding="utf-8"
        )

        result = sandbox.run_make("uninstall")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("legacy shell pre-image", result.stdout)
        self.assertEqual(installed, sandbox.shell_json.read_bytes())
        self.assertTrue(sandbox.enabled_state.exists())
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", sandbox.commands())
        self.assertTrue((sandbox.home / OWNED_RELATIVE_PATHS[0]).exists())

    def test_previously_enabled_plugin_is_never_disabled_by_uninstall(self) -> None:
        """Changing pre-existing enablement would damage the user's shell state."""
        sandbox = self.simulated_user(plugin_enabled=True)
        bindings = sandbox.home / ".config/hypr/bindings.lua"
        bindings.parent.mkdir(parents=True)
        bindings.write_text("-- unchanged\n", encoding="utf-8")

        self.assert_command_succeeded(sandbox.run_make("install"))
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertTrue(document["plugin_was_enabled"])
        self.assertFalse(document["plugin_enabled_by_installer"])
        self.assert_command_succeeded(sandbox.run_make("uninstall"))

        commands = sandbox.commands()
        self.assertIn("plugin list --json", commands)
        self.assertNotIn(f"plugin enable {PLUGIN_ID}", commands)
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", commands)
        self.assertEqual(2, commands.count("restart shell"))
        self.assertEqual("-- unchanged\n", bindings.read_text(encoding="utf-8"))

    def test_installer_enabled_plugin_state_is_restored_without_disable(self) -> None:
        """The exact shell preimage must replace an interruptible disable command."""
        sandbox = self.simulated_user(plugin_enabled=False)

        self.assert_command_succeeded(sandbox.run_make("install"))
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertFalse(document["plugin_was_enabled"])
        self.assertTrue(document["plugin_enabled_by_installer"])
        self.assert_command_succeeded(sandbox.run_make("uninstall"))

        commands = sandbox.commands()
        self.assertIn(f"plugin enable {PLUGIN_ID}", commands)
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", commands)
        self.assertEqual(2, commands.count("restart shell"))
        self.assertFalse(sandbox.shell_json.exists())

    def test_uninstall_restores_preexisting_shell_json_bytes_exactly(self) -> None:
        sandbox = self.simulated_user(plugin_enabled=False)
        shell_config = sandbox.home / ".config/omarchy/shell.json"
        shell_config.parent.mkdir(parents=True)
        original = (
            b'{\n  "plugins" : [ ],\n  "bar": {"layout": {'
            b'"left": [{"id": "mrai.keyguide"}], "center": [], "right": []}},\n'
            b'  "custom": "spacing retained"\n}\n'
        )
        shell_config.write_bytes(original)
        script = (sandbox.fake_bin / "omarchy").read_text(encoding="utf-8")
        enable_marker = f"  touch {shlex.quote(str(sandbox.enabled_state))}\n"
        script = script.replace(enable_marker, enable_marker + f"  printf '%s\\n' '{{\"plugins\":[\"{PLUGIN_ID}\"]}}' > {shlex.quote(str(shell_config))}\n")
        disable_marker = f"  rm -f {shlex.quote(str(sandbox.enabled_state))}\n"
        script = script.replace(disable_marker, disable_marker + f"  printf '%s\\n' '{{\"plugins\":[]}}' > {shlex.quote(str(shell_config))}\n")
        (sandbox.fake_bin / "omarchy").write_text(script, encoding="utf-8")

        self.assert_command_succeeded(sandbox.run_make("install"))
        self.assertNotEqual(original, shell_config.read_bytes())
        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertEqual(original, shell_config.read_bytes())
        self.assertEqual(0o644, stat.S_IMODE(shell_config.stat().st_mode))

    def _make_fake_omarchy_create_shell_config(
        self, sandbox: SimulatedUserInstall, shell_config: Path
    ) -> None:
        shell_config.parent.mkdir(parents=True, exist_ok=True)
        script_path = sandbox.fake_bin / "omarchy"
        script = script_path.read_text(encoding="utf-8")
        enable_marker = f"  touch {shlex.quote(str(sandbox.enabled_state))}\n"
        script = script.replace(
            enable_marker,
            enable_marker
            + f"  printf '%s\\n' '{{\"plugins\":[\"{PLUGIN_ID}\"]}}' > {shlex.quote(str(shell_config))}\n",
        )
        disable_marker = f"  rm -f {shlex.quote(str(sandbox.enabled_state))}\n"
        script = script.replace(
            disable_marker,
            disable_marker
            + f"  printf '%s\\n' '{{\"plugins\":[]}}' > {shlex.quote(str(shell_config))}\n",
        )
        script_path.write_text(script, encoding="utf-8")

    def test_uninstall_restores_absent_shell_json_when_unchanged(self) -> None:
        sandbox = self.simulated_user(plugin_enabled=False)
        shell_config = sandbox.home / ".config/omarchy/shell.json"
        self._make_fake_omarchy_create_shell_config(sandbox, shell_config)
        self.assertFalse(shell_config.exists())

        self.assert_command_succeeded(sandbox.run_make("install"))
        self.assertTrue(shell_config.exists())
        self.assert_command_succeeded(sandbox.run_make("uninstall"))

        self.assertFalse(shell_config.exists())

    def test_uninstall_preserves_user_created_shell_json_change(self) -> None:
        sandbox = self.simulated_user(plugin_enabled=False)
        shell_config = sandbox.home / ".config/omarchy/shell.json"
        self._make_fake_omarchy_create_shell_config(sandbox, shell_config)
        self.assert_command_succeeded(sandbox.run_make("install"))
        user_bytes = b'{"plugins":["mrai.keyguide"],"user":"changed"}\n'
        shell_config.write_bytes(user_bytes)

        result = sandbox.run_make("uninstall")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertEqual(user_bytes, shell_config.read_bytes())
        self.assertTrue(sandbox.enabled_state.exists())
        self.assertTrue(sandbox.manifest.exists())

    def test_cleanup_failure_never_reclaims_a_user_reenabled_plugin(self) -> None:
        """Cleared shell ownership must be durable before file cleanup can fail."""
        sandbox = self.simulated_user(plugin_enabled=False)
        self.assert_command_succeeded(sandbox.run_make("install"))
        cleanup_blocker = sandbox.home / OWNED_RELATIVE_PATHS[-1]
        cleanup_blocker.unlink()
        cleanup_blocker.mkdir()

        first_uninstall = sandbox.run_make("uninstall")

        self.assertNotEqual(0, first_uninstall.returncode, first_uninstall.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertFalse(document["plugin_enabled_by_installer"])
        self.assertEqual("disabled", document["plugin_enable_state"])
        sandbox.enabled_state.touch()
        cleanup_blocker.rmdir()
        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        commands = sandbox.commands()
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", commands)
        self.assertTrue(sandbox.enabled_state.exists())
        self.assertFalse(sandbox.manifest.exists())

    def test_failed_uninstall_restart_keeps_manifest_for_retry(self) -> None:
        """A failed final restart must leave a durable retry marker."""
        sandbox = self.simulated_user(
            plugin_enabled=False,
            restart_fail_on_call=2,
        )
        self.assert_command_succeeded(sandbox.run_make("install"))

        first_uninstall = sandbox.run_make("uninstall")

        self.assertNotEqual(0, first_uninstall.returncode, first_uninstall.stdout)
        self.assertTrue(sandbox.manifest.exists())
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("restart_pending", document.get("install_state"))
        self.assertFalse(document["plugin_enabled_by_installer"])
        self.assertEqual([], document["owned_files"])
        self.assertIsNone(document["pending_reservation"])
        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertFalse(sandbox.manifest.exists())
        commands = sandbox.commands()
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", commands)
        self.assertEqual(3, commands.count("restart shell"))

    def test_uninstall_syncs_deletions_before_restart_pending_journal(self) -> None:
        """A durable restart marker must not outrun directory-entry removal."""
        sandbox = self.sandbox()
        self.assert_command_succeeded(sandbox.install())
        python_wrapper = sandbox.fake_bin / "python3"
        python_wrapper.write_text(
            f"#!{sys.executable}\n"
            "import subprocess\n"
            "import sys\n"
            "program = sys.stdin.read()\n"
            "if '# keyguide-atomic-owned-program-remove-observation-checked' in program:\n"
            "    injection = '''\n"
            "_real_fsync = os.fsync\n"
            "def fail_directory_fsync(descriptor):\n"
            "    if stat.S_ISDIR(os.fstat(descriptor).st_mode):\n"
            "        raise OSError('simulated directory fsync failure')\n"
            "    return _real_fsync(descriptor)\n"
            "os.fsync = fail_directory_fsync\n"
            "'''\n"
            "    program = program.replace('import sys\\n', "
            "'import sys\\n' + injection, 1)\n"
            f"result = subprocess.run([{str(sys.executable)!r}, "
            "*sys.argv[1:]], input=program, text=True)\n"
            "raise SystemExit(result.returncode)\n",
            encoding="utf-8",
        )
        python_wrapper.chmod(0o755)

        result = sandbox.uninstall()

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertIn("simulated directory fsync failure", result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertNotEqual(
            "restart_pending",
            document["install_state"],
        )

    def test_enable_waits_for_delayed_plugin_discovery(self) -> None:
        """Enabling before rescan discovery completes would reject a fresh plugin."""
        sandbox = self.simulated_user(plugin_enabled=False, discovery_delay=2)

        self.assert_command_succeeded(sandbox.run_make("install"))

        commands = sandbox.commands()
        self.assertEqual(4, commands.count("plugin list --json"))
        self.assertLess(
            commands.index("shell shell rescanPlugins"),
            commands.index(f"plugin enable {PLUGIN_ID}"),
        )

    def test_failed_enable_then_user_enable_is_never_claimed_by_uninstall(
        self,
    ) -> None:
        """Observed enablement after failure is not proof of installer ownership."""
        sandbox = self.simulated_user(plugin_enabled=False, enable_exit=88)

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("installing", document.get("install_state"))
        self.assertEqual("enable_failed", document.get("plugin_enable_state"))
        self.assertFalse(document["plugin_enabled_by_installer"])
        sandbox.enabled_state.touch()
        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", sandbox.commands())
        self.assertTrue(sandbox.enabled_state.exists())
        self.assertFalse(sandbox.manifest.exists())

    def test_ambiguous_enable_is_never_claimed_by_uninstall(self) -> None:
        """An interrupted journal cannot prove who enabled the plugin."""
        sandbox = self.simulated_user(
            plugin_enabled=False,
            break_manifest_after_enable=True,
        )

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        document = json.loads(sandbox.manifest.read_text(encoding="utf-8"))
        self.assertEqual("enabling", document.get("plugin_enable_state"))
        state_directory = sandbox.manifest.parent
        state_directory.chmod(0o700)
        self.assert_command_succeeded(sandbox.run_make("uninstall"))
        commands = sandbox.commands()
        self.assertNotIn(f"plugin disable {PLUGIN_ID}", commands)
        self.assertTrue(sandbox.enabled_state.exists())
        self.assertFalse(sandbox.manifest.exists())

    def test_malformed_plugin_catalog_aborts_before_copying_files(self) -> None:
        """Treating unknown state as disabled could overwrite shell intent."""
        sandbox = self.simulated_user(plugin_enabled=None)

        result = sandbox.run_make("install")

        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertFalse(sandbox.manifest.exists())
        self.assertFalse(
            (
                sandbox.home
                / ".local/lib/omarchy-keyguide/bin/keyguide-observer"
            ).exists()
        )
        self.assertEqual(["plugin list --json"], sandbox.commands())

    def test_incompatible_live_system_aborts_before_plugin_or_files(self) -> None:
        sandbox = self.simulated_user(plugin_enabled=False)
        result = sandbox.run_make("install", extra_env={"KEYGUIDE_COMPAT_PROGRAM": "/bin/false"})
        self.assertNotEqual(0, result.returncode, result.stdout)
        self.assertFalse(sandbox.manifest.exists())
        self.assertEqual([], sandbox.commands())


if __name__ == "__main__":
    unittest.main()
