import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class MakefileVerificationTests(unittest.TestCase):
    def test_clean_checkout_test_builds_required_observer_artifacts(self) -> None:
        result = subprocess.run(
            ["make", "-Bn", "test"], cwd=ROOT, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout)
        self.assertIn("src/observer/keyguide-observer.c", result.stdout)

    def test_test_target_plans_every_static_safety_gate(self):
        result = subprocess.run(
            [
                "make",
                "-Bn",
                "test",
                "QMLLINT=/portable/qmllint",
                "RG=/portable/rg",
            ],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )

        plan = result.stdout
        self.assertIn(
            "/portable/qmllint src/plugin/*.qml src/plugin/components/*.qml", plan
        )
        self.assertIn("bash -n", plan)
        self.assertIn("/portable/rg", plan)
        self.assertIn("EVIOCGRAB", plan)
        self.assertIn("/dev/uinput", plan)
        self.assertIn("bindings\\.lua", plan)
        self.assertNotIn("shortcut mutation/reload is prohibited", plan)


if __name__ == "__main__":
    unittest.main()
