"""Presentation-only ordering for bindings shown in the HUD."""

from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from .bindings import Binding


PRIMARY_SPECIAL = {
    "ENTER": 0,
    "RETURN": 0,
    "SPACE": 1,
    "TAB": 2,
    "ESCAPE": 3,
    "BACKSPACE": 4,
}
SYMBOLS = {
    "COMMA",
    "PERIOD",
    "MINUS",
    "EQUAL",
    "SEMICOLON",
    "APOSTROPHE",
    "SLASH",
    "BACKSLASH",
}
NAVIGATION = {
    "LEFT",
    "RIGHT",
    "UP",
    "DOWN",
    "HOME",
    "END",
    "PAGEUP",
    "PAGEDOWN",
    "INSERT",
    "DELETE",
}


def binding_sort_key(binding: Binding) -> tuple[int, str, str]:
    """Return the visual lookup order without changing binding semantics."""
    key = binding.key.strip().upper()
    description = binding.description.casefold()

    if binding.mouse:
        return (6, key, description)
    if key in PRIMARY_SPECIAL:
        return (0, f"{PRIMARY_SPECIAL[key]:02d}", description)
    if key in SYMBOLS:
        return (1, key, description)
    if key in NAVIGATION:
        return (2, key, description)
    if key.isdigit():
        return (3, key, description)
    if len(key) == 1 and key.isalpha():
        return (4, key, description)
    return (5, key, description)
