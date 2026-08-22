"""Human-oriented binding presentation order tests."""

from pathlib import Path
import unittest

from keyguide_backend.bindings import Binding, parse
from keyguide_backend.presentation import binding_sort_key


FIXTURES = Path(__file__).parents[1] / "fixtures"


def fake_bindings(keys: list[str]) -> list[Binding]:
    """Build independent fixtures with one visible binding per key."""
    return [
        Binding(
            id=f"binding-{key}",
            modifiers=("SUPER",),
            key=key,
            description=f"{key} action",
            dispatcher=None,
            argument=None,
            mouse=key.startswith("MOUSE_"),
            editable=False,
        )
        for key in keys
    ]


class BindingPresentationTests(unittest.TestCase):
    def test_real_return_binding_is_first_in_super_group(self) -> None:
        """Omarchy's RETURN spelling must receive the Enter presentation rank."""
        active = parse(
            (FIXTURES / "omarchy-keybindings.txt").read_text(encoding="utf-8"),
            (FIXTURES / "hyprctl-binds.txt").read_text(encoding="utf-8"),
        )

        super_bindings = [binding for binding in active if binding.modifiers == ("SUPER",)]

        self.assertEqual(("RETURN", "Terminal"), (
            super_bindings[0].key,
            super_bindings[0].description,
        ))

    def test_visual_order_places_mouse_last(self) -> None:
        """A mouse binding must not interrupt visual keyboard-key lookup."""
        keys = ["MOUSE_RIGHT", "B", "2", "LEFT", "COMMA", "SPACE", "A", "ENTER"]

        ordered = sorted(fake_bindings(keys), key=binding_sort_key)

        self.assertEqual(
            ["ENTER", "SPACE", "COMMA", "LEFT", "2", "A", "B", "MOUSE_RIGHT"],
            [item.key for item in ordered],
        )

    def test_parse_sorts_each_modifier_group_for_hud_columns(self) -> None:
        """The backend emits each group in visual order before QML lays it out."""
        omarchy = """\
SUPER + B → Bravo
SUPER + MOUSE_RIGHT → Mouse
SUPER + ENTER → Enter
SUPER + 2 → Two
SUPER + COMMA → Comma
SUPER + LEFT → Left
SUPER + A → Alpha
SUPER CTRL + Z → Zulu
SUPER CTRL + SPACE → Space
"""
        hyprctl = """\
bindd
\tmodmask: 64
\tkey: B
\tkeycode: 0
\tdescription: Bravo

bindd
\tmodmask: 64
\tkey: MOUSE_RIGHT
\tkeycode: 0
\tdescription: Mouse

bindd
\tmodmask: 64
\tkey: ENTER
\tkeycode: 0
\tdescription: Enter

bindd
\tmodmask: 64
\tkey: 2
\tkeycode: 0
\tdescription: Two

bindd
\tmodmask: 64
\tkey: COMMA
\tkeycode: 0
\tdescription: Comma

bindd
\tmodmask: 64
\tkey: LEFT
\tkeycode: 0
\tdescription: Left

bindd
\tmodmask: 64
\tkey: A
\tkeycode: 0
\tdescription: Alpha

bindd
\tmodmask: 68
\tkey: Z
\tkeycode: 0
\tdescription: Zulu

bindd
\tmodmask: 68
\tkey: SPACE
\tkeycode: 0
\tdescription: Space
"""

        active = parse(omarchy, hyprctl)

        self.assertEqual(
            ["ENTER", "COMMA", "LEFT", "2", "A", "B", "MOUSE_RIGHT", "SPACE", "Z"],
            [item.key for item in active],
        )


if __name__ == "__main__":
    unittest.main()
