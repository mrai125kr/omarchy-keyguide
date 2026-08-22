import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class PluginManifestTests(unittest.TestCase):
    def test_manifests_keep_the_product_at_version_0_1_0(self):
        """Both supported installation layouts must identify the same 0.1 release."""
        source = json.loads(Path("src/plugin/manifest.json").read_text(encoding="utf-8"))
        published = json.loads(Path("manifest.json").read_text(encoding="utf-8"))

        self.assertEqual("0.1.0", published["version"])
        self.assertEqual(published["version"], source["version"])

    def test_declares_service_settings_overlay_and_single_bar_widget(self):
        manifest = json.loads(Path("src/plugin/manifest.json").read_text(encoding="utf-8"))

        self.assertEqual(
            set(manifest["kinds"]), {"service", "overlay", "bar-widget"}
        )
        self.assertTrue(manifest["keepLoaded"])
        self.assertEqual(manifest["entryPoints"]["service"], "Service.qml")
        self.assertEqual(manifest["entryPoints"]["overlay"], "Settings.qml")
        self.assertEqual(manifest["entryPoints"]["barWidget"], "BarWidget.qml")
        self.assertFalse(manifest["barWidget"]["allowMultiple"])

    def test_repository_root_is_an_installable_omarchy_plugin(self):
        source = json.loads(Path("src/plugin/manifest.json").read_text(encoding="utf-8"))
        published = json.loads(Path("manifest.json").read_text(encoding="utf-8"))

        self.assertEqual(source["id"], published["id"])
        self.assertEqual(source["version"], published["version"])
        self.assertEqual(source["kinds"], published["kinds"])
        self.assertEqual(
            {
                "service": "src/plugin/Service.qml",
                "overlay": "src/plugin/Settings.qml",
                "barWidget": "src/plugin/BarWidget.qml",
            },
            published["entryPoints"],
        )
        with tempfile.TemporaryDirectory() as temporary:
            staged = Path(temporary) / "omarchy-keyguide"
            shutil.copytree(
                ".",
                staged,
                ignore=shutil.ignore_patterns(
                    ".git", ".superpowers", "build", "__pycache__", "*.pyc"
                ),
            )
            result = subprocess.run(
                ["omarchy", "plugin", "validate", str(staged)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            self.assertEqual(0, result.returncode, result.stdout)
            bootstrap = subprocess.run(
                ["bash", str(staged / "scripts/plugin-bootstrap.sh")],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            self.assertEqual(0, bootstrap.returncode, bootstrap.stdout)
            self.assertTrue((staged / "build/keyguide-observer").is_file())
            post_build_validation = subprocess.run(
                ["omarchy", "plugin", "validate", str(staged)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
            )
            self.assertEqual(
                0, post_build_validation.returncode, post_build_validation.stdout
            )
        self.assertEqual(0, result.returncode, result.stdout)

    def test_repository_plugin_declares_a_source_bootstrap(self):
        service = Path("src/plugin/Service.qml").read_text(encoding="utf-8")

        self.assertIn("property var manifest", service)
        self.assertIn("scripts/plugin-bootstrap.sh", service)
        self.assertIn("runtimeReady", service)
        self.assertTrue(Path("scripts/plugin-bootstrap.sh").is_file())


if __name__ == "__main__":
    unittest.main()
