"""Canonical modifier and HUD-group definitions shared by the backend."""

from __future__ import annotations

from collections.abc import Iterable


MODIFIER_ORDER: tuple[str, ...] = ("SUPER", "CTRL", "SHIFT", "ALT")
SUPER_GROUPS: tuple[str, ...] = (
    "SUPER",
    "SUPER+CTRL",
    "SUPER+SHIFT",
    "SUPER+ALT",
    "SUPER+CTRL+SHIFT",
    "SUPER+CTRL+ALT",
    "SUPER+SHIFT+ALT",
    "SUPER+CTRL+SHIFT+ALT",
)
SUPPORTED_SHORTCUT_KEYS: tuple[str, ...] = (
    *(chr(code) for code in range(ord("A"), ord("Z") + 1)),
    *(str(number) for number in range(10)),
    "SPACE",
    "RETURN",
    "ESCAPE",
    "TAB",
    "BACKSPACE",
    "DELETE",
    "HOME",
    "END",
    "LEFT",
    "RIGHT",
    "UP",
    "DOWN",
    *(f"F{number}" for number in range(1, 13)),
    "COMMA",
    "PERIOD",
    "SLASH",
    "MINUS",
    "EQUAL",
    "PRINT",
)


def canonical_modifiers(names: Iterable[str]) -> tuple[str, ...] | None:
    """Return known modifier names in their canonical display order."""
    raw = tuple(names)
    if len(raw) != len(set(raw)) or any(name not in MODIFIER_ORDER for name in raw):
        return None
    return tuple(name for name in MODIFIER_ORDER if name in raw)
