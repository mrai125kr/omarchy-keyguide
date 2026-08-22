"""Isolated discovery tests for the searchable application/command catalog."""

from __future__ import annotations

from dataclasses import asdict
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

from keyguide_backend import __main__ as cli
from keyguide_backend.catalog import (
    CatalogDiscovery,
    CatalogResolutionError,
)


def desktop(name: str, **fields: str) -> str:
    """Build a minimal freedesktop application entry for a fixture."""
    values = {
        "Type": "Application",
        "Name": name,
        "Exec": "demo",
        "Icon": "application-x-executable",
    }
    values.update(fields)
    return "[Desktop Entry]\n" + "".join(
        f"{key}={value}\n" for key, value in values.items()
    )


class CatalogDiscoveryTests(unittest.TestCase):
    """Discovery is deterministic, bounded, and independent of host inventory."""

    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.user_data = self.root / "user-data"
        self.system_data = self.root / "system-data"
        self.user_apps = self.user_data / "applications"
        self.system_apps = self.system_data / "applications"
        self.path_one = self.root / "path-one"
        self.path_two = self.root / "path-two"
        self.launcher = self.root / "gtk-launch"
        self.focus_launcher = self.root / "omarchy-launch-or-focus"
        self.session_launcher = self.root / "uwsm-app"
        for directory in (
            self.user_apps,
            self.system_apps,
            self.path_one,
            self.path_two,
        ):
            directory.mkdir(parents=True)
        self.launcher.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        self.launcher.chmod(0o755)
        self.focus_launcher.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        self.focus_launcher.chmod(0o755)
        self.session_launcher.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        self.session_launcher.chmod(0o755)
        self.environ = {
            "XDG_DATA_HOME": str(self.user_data),
            "XDG_DATA_DIRS": str(self.system_data),
            "PATH": os.pathsep.join((str(self.path_one), str(self.path_two))),
            "XDG_CURRENT_DESKTOP": "Omarchy:Hyprland",
        }

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def discovery(self, **environment: str) -> CatalogDiscovery:
        values = dict(self.environ)
        values.update(environment)
        return CatalogDiscovery(
            values,
            self.launcher,
            self.focus_launcher,
            self.session_launcher,
        )

    def write_user(self, name: str, contents: str) -> Path:
        path = self.user_apps / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")
        return path

    def write_system(self, name: str, contents: str) -> Path:
        path = self.system_apps / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")
        return path

    @staticmethod
    def make_command(path: Path, executable: bool = True) -> Path:
        path.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        path.chmod(0o755 if executable else 0o644)
        return path

    def test_user_desktop_id_shadows_system_and_uses_selected_locale(self) -> None:
        self.write_system(
            "demo.desktop", desktop("System Demo", **{"Name[ko]": "시스템"})
        )
        self.write_user(
            "demo.desktop", desktop("User Demo", **{"Name[ko]": "사용자 앱"})
        )

        item = self.discovery().snapshot("ko").items[0]

        self.assertEqual(
            ("application", "application:demo.desktop", "사용자 앱"),
            (item.kind, item.id, item.title),
        )
        self.assertEqual("User Demo", item.english_title)

    def test_hidden_and_nodisplay_entries_mask_lower_priority_duplicates(self) -> None:
        self.write_system("hidden.desktop", desktop("System Hidden"))
        self.write_system("nodisplay.desktop", desktop("System NoDisplay"))
        self.write_user("hidden.desktop", desktop("Hidden", Hidden="true"))
        self.write_user("nodisplay.desktop", desktop("No Display", NoDisplay="true"))

        applications = [
            item for item in self.discovery().snapshot("en").items
            if item.kind == "application"
        ]

        self.assertEqual([], applications)

    def test_tryexec_malformed_type_and_invalid_higher_priority_are_filtered(self) -> None:
        self.write_user(
            "missing.desktop", desktop("Missing", TryExec="not-installed")
        )
        self.write_user("link.desktop", "[Desktop Entry]\nType=Link\nName=Link\n")
        self.write_user("broken.desktop", "[Desktop Entry]\nName=Broken\nName=Again\n")
        self.write_system("broken.desktop", desktop("Must stay shadowed"))

        snapshot = self.discovery().snapshot("en")

        self.assertEqual(
            [], [item for item in snapshot.items if item.kind == "application"]
        )
        self.assertTrue(snapshot.warnings)

    def test_localized_fields_follow_exact_base_english_then_plain_order(self) -> None:
        self.write_user(
            "locale.desktop",
            desktop(
                "Plain",
                **{
                    "Name[en]": "English",
                    "Name[zh]": "中文",
                    "GenericName": "Plain generic",
                    "GenericName[zh_CN]": "简体说明",
                    "Comment": "Plain comment",
                    "Keywords": "plain;fallback;",
                    "Keywords[zh]": "中文;搜索;",
                },
            ),
        )

        item = self.discovery().snapshot("zh_CN").items[0]

        self.assertEqual("中文", item.title)
        self.assertEqual("English", item.english_title)
        self.assertEqual("简体说明", item.summary)
        self.assertIn("Plain", item.keywords)
        self.assertIn("搜索", item.keywords)

    def test_onlyshowin_and_notshowin_use_current_desktop(self) -> None:
        self.write_user("only.desktop", desktop("Only", OnlyShowIn="Hyprland;"))
        self.write_user("other.desktop", desktop("Other", OnlyShowIn="GNOME;"))
        self.write_user("blocked.desktop", desktop("Blocked", NotShowIn="Omarchy;"))

        titles = [
            item.title for item in self.discovery().snapshot("en").items
            if item.kind == "application"
        ]

        self.assertEqual(["Only"], titles)

    def test_absolute_and_path_tryexec_are_checked(self) -> None:
        available = self.make_command(self.path_one / "available")
        self.write_user("path.desktop", desktop("Path", TryExec="available"))
        self.write_user(
            "absolute.desktop", desktop("Absolute", TryExec=str(available))
        )
        self.write_user(
            "missing.desktop",
            desktop("Missing", TryExec=str(self.root / "does-not-exist")),
        )

        titles = [
            item.title for item in self.discovery().snapshot("en").items
            if item.kind == "application"
        ]

        self.assertEqual(["Absolute", "Path"], titles)

    def test_path_is_ordered_deduplicated_and_marked_as_command(self) -> None:
        first = self.make_command(self.path_one / "demo")
        self.make_command(self.path_two / "demo")
        self.make_command(self.path_two / "other")

        items = [
            item for item in self.discovery().snapshot("en").items
            if item.kind == "command"
        ]

        self.assertEqual(["demo", "other"], [item.title for item in items])
        self.assertEqual(str(first), items[0].path)
        self.assertTrue(all(item.id.startswith("command:") for item in items))
        self.assertTrue(all(item.icon == "" for item in items))

    def test_non_regular_non_executable_and_symlink_commands_are_ignored(self) -> None:
        (self.path_one / "directory").mkdir()
        self.make_command(self.path_one / "not-executable", executable=False)
        real = self.make_command(self.path_two / "real")
        (self.path_one / "linked").symlink_to(real)

        commands = [
            item.title for item in self.discovery().snapshot("en").items
            if item.kind == "command"
        ]

        self.assertEqual(["real"], commands)

    def test_control_characters_oversized_files_and_fields_are_rejected(self) -> None:
        self.write_user("control.desktop", desktop("Bad\x01Name"))
        self.write_user("field.desktop", desktop("x" * 513))
        oversized = self.user_apps / "oversized.desktop"
        oversized.write_bytes(b"[Desktop Entry]\n#" + b"x" * (256 * 1024))

        snapshot = self.discovery().snapshot("en")

        self.assertEqual(
            [], [item for item in snapshot.items if item.kind == "application"]
        )
        self.assertEqual(3, len(snapshot.warnings))

    def test_missing_launcher_prevents_application_results(self) -> None:
        self.write_user("demo.desktop", desktop("Demo"))

        snapshot = CatalogDiscovery(
            self.environ, self.root / "missing-launcher"
        ).snapshot("en")

        self.assertEqual(
            [], [item for item in snapshot.items if item.kind == "application"]
        )
        self.assertTrue(snapshot.warnings)

    def test_fingerprint_is_deterministic_and_tracks_add_remove(self) -> None:
        discovery = self.discovery()
        before = discovery.fingerprint()
        self.assertEqual(before, discovery.fingerprint())
        path = self.write_user("temporary.desktop", desktop("Temporary"))
        added = discovery.fingerprint()
        path.unlink()
        removed = discovery.fingerprint()

        self.assertNotEqual(before, added)
        self.assertNotEqual(added, removed)

    def test_application_resolution_rejects_traversal_and_rechecks_deletion(self) -> None:
        path = self.write_user("demo.desktop", desktop("Demo"))
        discovery = self.discovery()
        item = discovery.snapshot("en").items[0]

        resolved = discovery.resolve(item.kind, item.id)

        self.assertEqual("application", resolved.kind)
        self.assertEqual(str(self.focus_launcher), resolved.executable)
        self.assertEqual(
            "demo '" + str(self.session_launcher)
            + " -- " + str(self.launcher) + " demo.desktop'",
            resolved.arguments,
        )
        with self.assertRaises(CatalogResolutionError):
            discovery.resolve("application", "application:../demo.desktop")
        path.unlink()
        with self.assertRaises(CatalogResolutionError):
            discovery.resolve(item.kind, item.id)

    def test_application_resolution_prefers_an_escaped_startup_window_class(self) -> None:
        self.write_user(
            "demo.desktop",
            desktop(
                "Demo",
                Exec="/opt/demo/bin/demo-app %U",
                StartupWMClass="Demo.App+Window",
            ),
        )

        resolved = self.discovery().resolve(
            "application", "application:demo.desktop"
        )

        self.assertEqual(
            r"'Demo\.App\+Window' '" + str(self.session_launcher)
            + " -- " + str(self.launcher) + " demo.desktop'",
            resolved.arguments,
        )

    def test_application_resolution_falls_back_to_the_exec_basename(self) -> None:
        self.write_user(
            "chatgpt.desktop",
            desktop("ChatGPT", Exec="chatgpt %U"),
        )

        resolved = self.discovery().resolve(
            "application", "application:chatgpt.desktop"
        )

        self.assertEqual(
            "chatgpt '" + str(self.session_launcher)
            + " -- " + str(self.launcher) + " chatgpt.desktop'",
            resolved.arguments,
        )

    def test_application_resolution_normalizes_a_post_discovery_entry_race(self) -> None:
        path = self.write_user("demo.desktop", desktop("Demo"))
        discovery = self.discovery()
        real_applications = discovery._applications

        def mutate_after_discovery(language: str):
            result = real_applications(language)
            path.write_text(
                desktop("Demo", StartupWMClass="+++"),
                encoding="utf-8",
            )
            return result

        with (
            patch.object(
                discovery,
                "_applications",
                side_effect=mutate_after_discovery,
            ),
            self.assertRaisesRegex(
                CatalogResolutionError,
                "application is no longer available",
            ),
        ):
            discovery.resolve("application", "application:demo.desktop")

    def test_command_resolution_rechecks_path_winner_and_deletion(self) -> None:
        path = self.make_command(self.path_two / "demo")
        discovery = self.discovery()
        item = next(
            item for item in discovery.snapshot("en").items
            if item.kind == "command"
        )

        resolved = discovery.resolve(item.kind, item.id)

        self.assertEqual(str(path), resolved.executable)
        self.assertEqual("", resolved.arguments)
        higher_priority = self.make_command(self.path_one / "demo")
        with self.assertRaises(CatalogResolutionError):
            discovery.resolve(item.kind, item.id)
        higher_priority.unlink()
        path.unlink()
        with self.assertRaises(CatalogResolutionError):
            discovery.resolve(item.kind, item.id)

    def test_item_shape_and_command_identity_are_stable(self) -> None:
        command = self.make_command(self.path_one / "demo")
        item = next(
            item for item in self.discovery().snapshot("es").items
            if item.kind == "command"
        )

        self.assertEqual(
            {
                "kind", "id", "title", "english_title", "summary",
                "icon", "path", "keywords",
            },
            set(asdict(item)),
        )
        self.assertEqual(
            "command:" + hashlib.sha256(str(command).encode()).hexdigest(),
            item.id,
        )


class CatalogCliTests(unittest.TestCase):
    """The QML service receives one exact, versioned JSON contract."""

    def test_catalog_list_serializes_exact_camel_case_shape(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apps = root / "data" / "applications"
            commands = root / "bin"
            empty_system = root / "empty-system"
            apps.mkdir(parents=True)
            commands.mkdir()
            empty_system.mkdir()
            launcher = root / "gtk-launch"
            launcher.write_text("#!/bin/sh\n", encoding="utf-8")
            launcher.chmod(0o755)
            (apps / "demo.desktop").write_text(
                desktop("Demo", **{"Name[ko]": "데모"}), encoding="utf-8"
            )
            command = commands / "hello"
            command.write_text("#!/bin/sh\n", encoding="utf-8")
            command.chmod(0o755)
            environment = {
                "XDG_DATA_HOME": str(root / "data"),
                "XDG_DATA_DIRS": str(empty_system),
                "PATH": str(commands),
            }
            output = io.StringIO()
            with (
                patch.dict(os.environ, environment, clear=True),
                patch("keyguide_backend.__main__.catalog.DEFAULT_LAUNCHER", launcher),
                patch.object(
                    os.sys,
                    "argv",
                    [
                        "keyguide_backend", "catalog", "list",
                        "--language", "ko",
                    ],
                ),
                redirect_stdout(output),
            ):
                self.assertEqual(0, cli.main())

            payload = json.loads(output.getvalue())
            self.assertEqual({"version", "fingerprint", "items", "warnings"}, set(payload))
            self.assertEqual(
                {
                    "kind", "id", "title", "englishTitle", "summary",
                    "icon", "path", "keywords",
                },
                set(payload["items"][0]),
            )
            self.assertEqual("데모", payload["items"][0]["title"])

    def test_catalog_fingerprint_prints_exact_contract(self) -> None:
        fake = unittest.mock.Mock()
        fake.fingerprint.return_value = "abc123"
        output = io.StringIO()
        with (
            patch("keyguide_backend.__main__.catalog.CatalogDiscovery", return_value=fake),
            patch.object(
                os.sys,
                "argv",
                ["keyguide_backend", "catalog", "fingerprint"],
            ),
            redirect_stdout(output),
        ):
            self.assertEqual(0, cli.main())

        self.assertEqual(
            {"version": 1, "fingerprint": "abc123"},
            json.loads(output.getvalue()),
        )


if __name__ == "__main__":
    unittest.main()
