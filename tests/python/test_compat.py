"""Compatibility probe contract tests."""

import unittest

from keyguide_backend import compat


def fake_probe(
    omarchy: str = "4.0.0-1",
    hyprland: str = "0.56.2",
    input_readable: bool = True,
) -> compat.Probe:
    """Build a complete, deterministic probe result for compatibility checks."""
    return compat.Probe(
        omarchy_version=omarchy,
        hyprland_text=hyprland,
        input_readable=input_readable,
    )


class CompatibilityTests(unittest.TestCase):
    def test_compat_accepts_verified_versions(self) -> None:
        """The verified Omarchy/Hyprland pair with keyboard access is accepted."""
        result = compat.check(
            fake_probe(omarchy="4.0.0-1", hyprland="0.56.2", input_readable=True)
        )

        self.assertTrue(result["ok"])
        self.assertEqual([], result["errors"])

    def test_compat_rejects_unreadable_input(self) -> None:
        """An unreadable keyboard device prevents a safe installation."""
        result = compat.check(fake_probe(input_readable=False))

        self.assertFalse(result["ok"])
        self.assertIn("no readable keyboard event device", result["errors"])


if __name__ == "__main__":
    unittest.main()
