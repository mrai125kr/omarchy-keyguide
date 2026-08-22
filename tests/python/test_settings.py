"""Versioned Keyguide settings store contract tests."""

from __future__ import annotations

import json
from pathlib import Path
import tempfile
import unittest
from contextlib import redirect_stdout
import io
import os
import stat
import sys
from unittest.mock import Mock, patch

from keyguide_backend.settings import Settings, SettingsValidationError, default_path
from keyguide_backend import __main__ as cli


class SettingsTests(unittest.TestCase):
    """Settings persist only validated Keyguide presentation preferences."""

    def test_defaults_match_the_second_versioned_schema(self) -> None:
        """A wrong default would change the initial HUD behavior."""
        self.assertEqual(
            {
                "version": 2,
                "enabled": True,
                "position": "center",
                "scale": 1.0,
                "opacity": 0.94,
                "groups": [
                    "SUPER",
                    "SUPER+CTRL",
                    "SUPER+SHIFT",
                    "SUPER+ALT",
                    "SUPER+CTRL+SHIFT",
                    "SUPER+CTRL+ALT",
                    "SUPER+SHIFT+ALT",
                    "SUPER+CTRL+SHIFT+ALT",
                ],
                "hiddenBindingIds": [],
                "followTheme": True,
                "language": "en",
            },
            Settings.defaults().as_dict(),
        )

    def test_language_preference_round_trips_after_first_use(self) -> None:
        """Reopening Settings must preserve the selected supported language."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            Settings.defaults().update({"language": "ko"}).save_atomic(path)

            self.assertEqual("ko", Settings.load(path).as_dict()["language"])

    def test_load_migrates_version_one_without_losing_preferences(self) -> None:
        """Existing users receive English while every presentation choice survives."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            legacy = {
                "version": 1,
                "enabled": False,
                "position": "top",
                "scale": 1.25,
                "opacity": 0.8,
                "groups": ["SUPER"],
                "hiddenBindingIds": ["binding-a"],
                "showHiddenFiles": True,
                "followTheme": False,
            }
            path.write_text(json.dumps(legacy), encoding="utf-8")

            loaded = Settings.load(path).as_dict()

            self.assertEqual(2, loaded["version"])
            self.assertEqual("en", loaded["language"])
            self.assertEqual(0.8, loaded["opacity"])
            self.assertEqual(["binding-a"], loaded["hiddenBindingIds"])
            self.assertNotIn("showHiddenFiles", loaded)

    def test_load_migrates_version_one_without_hidden_file_preference(self) -> None:
        """The older pre-browser schema remains a valid migration input."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            legacy = {
                "version": 1,
                "enabled": True,
                "position": "center",
                "scale": 1.0,
                "opacity": 0.94,
                "groups": ["SUPER"],
                "hiddenBindingIds": [],
                "followTheme": True,
            }
            path.write_text(json.dumps(legacy), encoding="utf-8")

            loaded = Settings.load(path).as_dict()

            self.assertEqual("en", loaded["language"])
            self.assertNotIn("showHiddenFiles", loaded)

    def test_hidden_binding_does_not_disable_runtime_binding(self) -> None:
        """Dropping presentation filters would reveal a deliberately hidden row."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            Settings.defaults().update({"hiddenBindingIds": ["abc"]}).save_atomic(path)

            self.assertEqual(["abc"], json.loads(path.read_text())["hiddenBindingIds"])

    def test_load_round_trips_a_saved_settings_document(self) -> None:
        """Loading defaults after a valid save would discard user preferences."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            updated = Settings.defaults().update({"opacity": 0.8, "position": "top"})
            updated.save_atomic(path)

            self.assertEqual(updated, Settings.load(path))

    def test_load_preserves_a_valid_existing_group_subset(self) -> None:
        """An upgrade must not silently re-enable groups a user left disabled."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            existing_groups = ["SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT"]
            path.write_text(
                json.dumps({**Settings.defaults().as_dict(), "groups": existing_groups})
            )

            self.assertEqual(existing_groups, Settings.load(path).as_dict()["groups"])

    def test_failed_atomic_replace_preserves_old_bytes_and_removes_temp_file(self) -> None:
        """A failed replace must neither alter a prior document nor leave a temp file."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            original = b'{"preserve":"these exact bytes"}\n'
            path.write_bytes(original)

            with patch(
                "keyguide_backend.settings.os.replace",
                side_effect=OSError("simulated replace failure"),
            ):
                with self.assertRaises(OSError):
                    Settings.defaults().update({"opacity": 0.8}).save_atomic(path)

            self.assertEqual(original, path.read_bytes())
            self.assertEqual([], list(path.parent.glob(".settings.json.*.tmp")))

    def test_successful_atomic_replace_syncs_the_parent_directory(self) -> None:
        """The committed directory entry must survive a crash after replacement."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            real_fsync = os.fsync
            synced_directories: list[int] = []

            def record_fsync(descriptor: int) -> None:
                if stat.S_ISDIR(os.fstat(descriptor).st_mode):
                    synced_directories.append(descriptor)
                real_fsync(descriptor)

            with patch("keyguide_backend.settings.os.fsync", side_effect=record_fsync):
                Settings.defaults().save_atomic(path)

            self.assertEqual(1, len(synced_directories))

    def test_load_returns_defaults_when_no_settings_file_exists(self) -> None:
        """Treating a first launch as malformed would prevent initial use."""
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(Settings.defaults(), Settings.load(Path(directory) / "missing.json"))

    def test_empty_xdg_data_home_uses_the_standard_default_location(self) -> None:
        """An empty environment value must not create settings below the CWD."""
        with patch.dict(os.environ, {"XDG_DATA_HOME": ""}, clear=False):
            self.assertEqual(
                Path.home() / ".local" / "share" / "omarchy-keyguide" / "settings.json",
                default_path(),
            )

    def test_update_rejects_out_of_range_scale(self) -> None:
        """Accepting an inaccessible scale would make the HUD unusable."""
        with self.assertRaises(SettingsValidationError):
            Settings.defaults().update({"scale": 0.74})

    def test_update_rejects_unknown_modifier_group(self) -> None:
        """An unsupported group would silently fail to select HUD rows."""
        with self.assertRaises(SettingsValidationError):
            Settings.defaults().update({"groups": ["SUPER+META"]})

    def test_update_rejects_a_non_string_position(self) -> None:
        """Leaking a TypeError would make malformed JSON a CLI crash."""
        with self.assertRaises(SettingsValidationError):
            Settings.defaults().update({"position": ["center"]})

    def test_update_rejects_non_string_hidden_binding_id(self) -> None:
        """A non-string identity cannot match a runtime binding identity."""
        with self.assertRaises(SettingsValidationError):
            Settings.defaults().update({"hiddenBindingIds": [42]})

    def test_update_rejects_unknown_language(self) -> None:
        """A locale without a complete translation catalog must not persist."""
        with self.assertRaises(SettingsValidationError) as caught:
            Settings.defaults().update({"language": "zh_TW"})

        self.assertEqual("settings.language_invalid", caught.exception.code)
        self.assertEqual({"language": "zh_TW"}, caught.exception.context)

    def test_update_rejects_non_string_language(self) -> None:
        """A non-string locale cannot select a deterministic translation catalog."""
        with self.assertRaises(SettingsValidationError):
            Settings.defaults().update({"language": ["ko"]})

    def test_load_rejects_an_unknown_schema_version(self) -> None:
        """Silently accepting a future schema risks overwriting its data."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            path.write_text(json.dumps({**Settings.defaults().as_dict(), "version": 3}))

            with self.assertRaises(SettingsValidationError):
                Settings.load(path)

    def test_load_rejects_a_non_integer_schema_version(self) -> None:
        """Accepting version 1.0 would blur the versioned document contract."""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "settings.json"
            path.write_text(json.dumps({**Settings.defaults().as_dict(), "version": 1.0}))

            with self.assertRaises(SettingsValidationError):
                Settings.load(path)

    def test_settings_cli_get_and_patch_persist_a_valid_preference(self) -> None:
        """A non-persistent patch would reset opacity each time QML queries it."""
        with tempfile.TemporaryDirectory() as directory:
            output = io.StringIO()
            with (
                patch.dict(
                    os.environ,
                    {"XDG_DATA_HOME": directory},
                    clear=False,
                ),
                patch.object(
                    cli.shortcuts.ShortcutManager,
                    "recover_reset_transaction",
                    return_value=False,
                ),
                patch.object(sys, "argv", ["keyguide_backend", "settings", "get"]),
                redirect_stdout(output),
            ):
                self.assertEqual(0, cli.main())
            self.assertEqual(0.94, json.loads(output.getvalue())["opacity"])

            output = io.StringIO()
            with (
                patch.dict(
                    os.environ,
                    {"XDG_DATA_HOME": directory},
                    clear=False,
                ),
                patch.object(
                    cli.shortcuts.ShortcutManager,
                    "recover_reset_transaction",
                    return_value=False,
                ),
                patch.object(
                    sys,
                    "argv",
                    ["keyguide_backend", "settings", "patch", '{"opacity": 0.8}'],
                ),
                redirect_stdout(output),
            ):
                self.assertEqual(0, cli.main())
            self.assertEqual(0.8, json.loads(output.getvalue())["opacity"])

            self.assertEqual(
                0.8,
                Settings.load(Path(directory) / "omarchy-keyguide" / "settings.json")
                .as_dict()["opacity"],
            )

    def test_settings_cli_recovers_an_interrupted_reset_before_loading(self) -> None:
        """Settings refresh must not retain a fully committed but unacknowledged reset."""
        manager = Mock()
        output = io.StringIO()
        with tempfile.TemporaryDirectory() as directory:
            data_home = Path(directory) / "data"
            state_home = Path(directory) / "state"
            expected_path = data_home / "omarchy-keyguide" / "settings.json"
            with (
                patch.dict(
                    os.environ,
                    {
                        "XDG_DATA_HOME": str(data_home),
                        "XDG_STATE_HOME": str(state_home),
                    },
                    clear=False,
                ),
                patch.object(cli.shortcuts, "ShortcutManager", return_value=manager),
                patch.object(sys, "argv", ["keyguide_backend", "settings", "get"]),
                redirect_stdout(output),
            ):
                self.assertEqual(0, cli.main())

        manager.recover_reset_transaction.assert_called_once_with(expected_path)
        self.assertEqual(Settings.defaults().as_dict(), json.loads(output.getvalue()))


if __name__ == "__main__":
    unittest.main()
