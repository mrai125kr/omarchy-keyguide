"""Persistent input-access setup contract tests."""

from __future__ import annotations

import os
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
RULE_DESTINATION = Path("etc/udev/rules.d/70-omarchy-keyguide.rules")
EXPECTED_RULE = """# Managed by Omarchy Keyguide. Grants the active local seat input access.
ACTION!="remove", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_KEYBOARD}=="1", TAG+="uaccess"
ACTION!="remove", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_MOUSE}=="1", TAG+="uaccess"
ACTION!="remove", SUBSYSTEM=="input", KERNEL=="event*", ENV{ID_INPUT_TOUCHPAD}=="1", TAG+="uaccess"
"""


class InputAccessSetupTests(unittest.TestCase):
    def run_setup(self, root: Path, action: str) -> subprocess.CompletedProcess[str]:
        environment = os.environ.copy()
        environment["KEYGUIDE_UDEV_ROOT"] = str(root)
        return subprocess.run(
            ["fakeroot", "--", "bash", "scripts/input-access.sh", action],
            cwd=ROOT,
            env=environment,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )

    def test_install_creates_a_scoped_active_seat_rule(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_root:
            root = Path(temporary_root)

            result = self.run_setup(root, "install")

            self.assertEqual(0, result.returncode, result.stdout)
            destination = root / RULE_DESTINATION
            self.assertEqual(EXPECTED_RULE, destination.read_text(encoding="utf-8"))
            self.assertEqual(0o644, stat.S_IMODE(destination.stat().st_mode))

    def test_remove_deletes_only_the_unmodified_managed_rule(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_root:
            root = Path(temporary_root)
            self.assertEqual(0, self.run_setup(root, "install").returncode)

            result = self.run_setup(root, "remove")

            self.assertEqual(0, result.returncode, result.stdout)
            self.assertFalse((root / RULE_DESTINATION).exists())

    def test_remove_refuses_to_delete_a_changed_rule(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_root:
            root = Path(temporary_root)
            self.assertEqual(0, self.run_setup(root, "install").returncode)
            destination = root / RULE_DESTINATION
            destination.write_text("user-owned replacement\n", encoding="utf-8")

            result = self.run_setup(root, "remove")

            self.assertNotEqual(0, result.returncode, result.stdout)
            self.assertEqual(
                "user-owned replacement\n", destination.read_text(encoding="utf-8")
            )


if __name__ == "__main__":
    unittest.main()
