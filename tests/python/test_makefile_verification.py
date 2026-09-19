import os
import subprocess
import sys
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

    def test_ci_target_plans_portable_checks_without_omarchy_runtime(self):
        result = subprocess.run(
            [
                "make",
                "-Bn",
                "test-ci",
                "RG=/portable/rg",
            ],
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertEqual(0, result.returncode, result.stdout)
        plan = result.stdout
        self.assertIn("test_modifier_state", plan)
        self.assertIn("-m unittest", plan)
        self.assertIn("discover -s tests/python", plan)
        self.assertIn("bash -n", plan)
        self.assertIn("EVIOCGRAB", plan)
        self.assertIn("/dev/uinput", plan)
        self.assertIn("bindings\\.lua", plan)
        self.assertNotIn("qmltestrunner", plan)

    def test_manifest_suite_skips_only_live_validation_without_omarchy(self):
        environment = os.environ.copy()
        environment["PATH"] = ""
        result = subprocess.run(
            [sys.executable, "-m", "unittest", "tests.python.test_plugin_manifest", "-v"],
            cwd=ROOT,
            env=environment,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        self.assertEqual(0, result.returncode, result.stdout)
        self.assertIn("Ran 4 tests", result.stdout)
        self.assertIn("skipped=1", result.stdout)

    def test_ci_workflow_is_read_only_and_runs_the_portable_target(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")

        self.assertIn("contents: read", workflow)
        self.assertIn("make test-ci PYTHON=python3", workflow)
        self.assertRegex(workflow, r"actions/checkout@[0-9a-f]{40}")
        self.assertNotRegex(workflow, r"actions/checkout@v\d")


if __name__ == "__main__":
    unittest.main()
