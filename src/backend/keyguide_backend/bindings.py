"""Collect and normalize the active Hyprland binding model."""

from __future__ import annotations

from collections import defaultdict
from collections.abc import Callable
from dataclasses import dataclass
import hashlib
import json
import re
import subprocess
import unicodedata

from .groups import MODIFIER_ORDER, SUPPORTED_SHORTCUT_KEYS, canonical_modifiers
from .presentation import binding_sort_key


Runner = Callable[[tuple[str, ...]], str]

_MODIFIER_BITS = {"SUPER": 64, "CTRL": 4, "SHIFT": 1, "ALT": 8}
_MODIFIERS_BY_BIT = tuple((_MODIFIER_BITS[name], name) for name in MODIFIER_ORDER)
_KEY_ALIASES = {
    ",": "COMMA",
    "-": "MINUS",
    ".": "PERIOD",
    "/": "SLASH",
    "=": "EQUAL",
    "comma": "COMMA",
    "enter": "RETURN",
    "equal": "EQUAL",
    "minus": "MINUS",
    "mouse:272": "LEFT MOUSE BUTTON",
    "mouse:273": "RIGHT MOUSE BUTTON",
    "mouse:274": "MIDDLE MOUSE BUTTON",
    "period": "PERIOD",
    "slash": "SLASH",
}
_SUPPORTED_KEYS_BY_CASEFOLD = {
    key.casefold(): key for key in SUPPORTED_SHORTCUT_KEYS
}
_INTERNAL_DESCRIPTION_PREFIXES = (
    "keyguide internal",
    "[keyguide internal]",
)
_SUPPORTED_ACTION_KINDS = frozenset({"exec", "lua"})
_MALFORMED_ACTION_KIND = "\0malformed-action-record"
_SOURCE_RECORD_COMMAND = (
    "/usr/bin/bash",
    "-c",
    "source /usr/bin/omarchy-menu-keybindings --print >/dev/null; output_binding_records",
)


@dataclass(frozen=True)
class Binding:
    """One user-visible binding active in the running compositor."""

    id: str
    modifiers: tuple[str, ...]
    key: str
    description: str
    dispatcher: str | None
    argument: str | None
    mouse: bool
    editable: bool
    action_kind: str | None = None
    action_argument: str | None = None
    edit_reason: str = ""
    presentation_id: str = ""
    selection_kind: str = ""
    selection_id: str = ""
    label_key: str = ""
    title_override: str = ""


@dataclass(frozen=True)
class SourceBinding:
    """One reconstructable action emitted by Omarchy's source record generator."""

    modifiers: tuple[str, ...]
    key: str
    description: str
    action_kind: str | None
    action_argument: str | None


@dataclass(frozen=True)
class RuntimeBinding:
    modifiers: tuple[str, ...]
    key: str
    description: str
    dispatcher: str | None
    argument: str | None


def stable_id(modifiers: tuple[str, ...], key: str, description: str) -> str:
    """Return an identity derived only from stable, user-visible fields."""
    payload = json.dumps(
        [list(modifiers), key, description],
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return "binding-" + hashlib.sha256(payload).hexdigest()


def _parse_chord(chord: str) -> tuple[tuple[str, ...] | None, str]:
    if " + " not in chord:
        return (), chord.strip()

    modifier_text, key = chord.rsplit(" + ", 1)
    modifiers = canonical_modifiers(
        "CTRL" if item.upper() == "CONTROL" else item.upper()
        for item in modifier_text.split()
    )
    return modifiers, key.strip()


def _runtime_modifiers(value: str) -> tuple[str, ...] | None:
    try:
        mask = int(value)
    except ValueError:
        names = value.split()
        return canonical_modifiers(names) if names else None

    known_mask = 0
    modifiers = []
    for bit, name in _MODIFIERS_BY_BIT:
        known_mask |= bit
        if mask & bit:
            modifiers.append(name)
    if mask & ~known_mask:
        return None
    return canonical_modifiers(modifiers)


def canonical_key(value: str) -> str:
    """Return one key spelling for menu, runtime, and mutation inputs."""
    key = value.rsplit(" + ", 1)[-1].strip()
    folded = key.casefold()
    alias = _KEY_ALIASES.get(folded)
    if alias is not None:
        return alias
    supported = _SUPPORTED_KEYS_BY_CASEFOLD.get(folded)
    if supported is not None:
        return supported
    if folded.startswith("code:"):
        return "code:" + key.split(":", 1)[1]
    return key


def _runtime_key(value: str) -> str:
    return canonical_key(value)


def parse_runtime_bindings(text: str) -> list[RuntimeBinding]:
    records: list[dict[str, str]] = []
    current: dict[str, str] | None = None

    for line in text.splitlines():
        if line.startswith("bind") and not line.startswith((" ", "\t")):
            if current is not None:
                records.append(current)
            current = {}
            continue
        if current is None:
            continue
        match = re.match(r"^\t([a-z]+): ?(.*)$", line)
        if match:
            current[match.group(1)] = match.group(2)
    if current is not None:
        records.append(current)

    parsed = []
    for record in records:
        modifiers = _runtime_modifiers(record.get("modmask", ""))
        description = record.get("description", "")
        key = record.get("key", "")
        keycode = record.get("keycode", "0")
        if not key and keycode != "0":
            key = f"code:{keycode}"
        if modifiers is None or not key:
            continue
        dispatcher = record.get("dispatcher") or None
        argument = record.get("arg") or None
        parsed.append(
            RuntimeBinding(
                modifiers=modifiers,
                key=_runtime_key(key),
                description=description,
                dispatcher=dispatcher,
                argument=argument,
            )
        )
    return parsed


def _is_internal(description: str) -> bool:
    normalized = description.strip().casefold()
    return normalized.startswith(_INTERNAL_DESCRIPTION_PREFIXES)


def _is_mouse_key(key: str) -> bool:
    return "mouse" in key.casefold()


def _has_control(value: str) -> bool:
    return any(unicodedata.category(character) == "Cc" for character in value)


def _source_binding(
    display: str, kind: str | None, argument: str | None
) -> SourceBinding | None:
    parts = re.split(r"\s+→\s+", display.strip(), maxsplit=1)
    if len(parts) != 2:
        return None
    chord, description = parts
    modifiers, key = _parse_chord(chord)
    if modifiers is None:
        return None
    if kind == _MALFORMED_ACTION_KIND:
        return SourceBinding(
            modifiers, canonical_key(key), description, _MALFORMED_ACTION_KIND, None
        )
    if not kind and not argument:
        return SourceBinding(modifiers, canonical_key(key), description, None, None)
    if kind not in _SUPPORTED_ACTION_KINDS:
        return SourceBinding(modifiers, canonical_key(key), description, kind, argument)
    if not argument or _has_control(argument):
        return SourceBinding(
            modifiers, canonical_key(key), description, _MALFORMED_ACTION_KIND, None
        )
    return SourceBinding(modifiers, canonical_key(key), description, kind, argument)


def parse_source_records(text: str) -> list[SourceBinding]:
    """Parse Omarchy source action records while retaining identifiable bad rows."""
    parsed = []
    for line in text.splitlines():
        if not line.strip():
            continue
        try:
            display, kind, argument = line.split("\t", 2)
        except ValueError:
            display = line.split("\t", 1)[0]
            kind = _MALFORMED_ACTION_KIND
            argument = None
        source = _source_binding(display, kind, argument)
        if source is not None:
            parsed.append(source)
    return parsed


def _editability(
    source_candidates: list[SourceBinding], *, key: str, mouse: bool, chord_unique: bool
) -> tuple[bool, str]:
    if mouse:
        return False, "Mouse binding"
    if not chord_unique:
        return False, "Duplicate chord"
    if key not in SUPPORTED_SHORTCUT_KEYS:
        return False, "Unsupported key"
    if not source_candidates:
        return False, "Action cannot be reconstructed"
    if len(source_candidates) != 1:
        return False, "Ambiguous action metadata"
    source = source_candidates[0]
    if source.action_kind is None:
        return False, "Action cannot be reconstructed"
    if source.action_kind == _MALFORMED_ACTION_KIND:
        return False, "Malformed action record"
    if source.action_kind not in _SUPPORTED_ACTION_KINDS:
        return False, "Unsupported action kind"
    if source.action_argument is None:
        return False, "Action cannot be reconstructed"
    return True, ""


def _one(candidates: list[RuntimeBinding]) -> RuntimeBinding | None:
    return candidates[0] if len(candidates) == 1 else None


def parse(
    omarchy_text: str, hyprctl_text: str, source_records_text: str = ""
) -> list[Binding]:
    """Join Omarchy's display rows with unambiguous runtime metadata."""
    exact: defaultdict[
        tuple[tuple[str, ...], str, str], list[RuntimeBinding]
    ] = defaultdict(list)
    physical_fallback: defaultdict[
        tuple[tuple[str, ...], str], list[RuntimeBinding]
    ] = defaultdict(list)
    by_chord: defaultdict[
        tuple[tuple[str, ...], str], list[RuntimeBinding]
    ] = defaultdict(list)
    source_exact: defaultdict[
        tuple[tuple[str, ...], str, str], list[SourceBinding]
    ] = defaultdict(list)
    for runtime in parse_runtime_bindings(hyprctl_text):
        exact[(runtime.modifiers, runtime.key, runtime.description)].append(runtime)
        if runtime.key.startswith("code:"):
            physical_fallback[(runtime.modifiers, runtime.description)].append(runtime)
        by_chord[(runtime.modifiers, runtime.key)].append(runtime)
    for source in parse_source_records(source_records_text):
        source_exact[(source.modifiers, source.key, source.description)].append(source)

    active = []
    for line_number, line in enumerate(omarchy_text.splitlines(), start=1):
        if not line.strip():
            continue
        parts = re.split(r"\s+→\s+", line.strip(), maxsplit=1)
        if len(parts) != 2:
            raise ValueError(f"invalid Omarchy keybinding on line {line_number}")
        chord, description = parts
        if _is_internal(description):
            continue

        modifiers, key = _parse_chord(chord)
        if modifiers is None:
            continue
        canonical = canonical_key(key)
        exact_candidates = exact[(modifiers, canonical, description)]
        exact_match = bool(exact_candidates)
        runtime = (
            _one(exact_candidates)
            if exact_match
            else _one(physical_fallback[(modifiers, description)])
        )
        if runtime is None:
            continue
        mouse = _is_mouse_key(canonical)
        chord_unique = len(by_chord[(runtime.modifiers, runtime.key)]) == 1
        source_candidates = (
            source_exact[(modifiers, canonical, description)] if exact_match else []
        )
        editable, edit_reason = _editability(
            source_candidates,
            key=canonical,
            mouse=mouse,
            chord_unique=chord_unique,
        )
        source = source_candidates[0] if len(source_candidates) == 1 else None
        binding_id = stable_id(modifiers, key, description)
        active.append(
            Binding(
                id=binding_id,
                modifiers=modifiers,
                key=key,
                description=description,
                dispatcher=runtime.dispatcher,
                argument=runtime.argument,
                mouse=mouse,
                editable=exact_match and editable,
                action_kind=source.action_kind if exact_match and editable and source else None,
                action_argument=(
                    source.action_argument if exact_match and editable and source else None
                ),
                edit_reason=edit_reason,
                presentation_id=binding_id,
            )
        )
    groups: dict[tuple[str, ...], list[Binding]] = {}
    for binding in active:
        groups.setdefault(binding.modifiers, []).append(binding)
    return [
        binding
        for group in groups.values()
        for binding in sorted(group, key=binding_sort_key)
    ]


def run_command(command: tuple[str, ...]) -> str:
    """Run one read-only binding query and return its standard output."""
    completed = subprocess.run(
        command,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout


def load_active_bindings(runner: Runner = run_command) -> list[Binding]:
    """Read the installed-system display and runtime binding sources."""
    omarchy_text = runner(("omarchy", "menu", "keybindings", "--print"))
    hyprctl_text = runner(("hyprctl", "binds"))
    try:
        source_records_text = runner(_SOURCE_RECORD_COMMAND)
    except (OSError, subprocess.SubprocessError):
        source_records_text = ""
    return parse(omarchy_text, hyprctl_text, source_records_text)


def load_runtime_bindings(runner: Runner = run_command) -> list[RuntimeBinding]:
    """Read every active runtime binding, including non-menu collision chords."""
    return parse_runtime_bindings(runner(("hyprctl", "binds")))


def load_binding_snapshot(
    runner: Runner = run_command,
) -> tuple[list[Binding], list[RuntimeBinding]]:
    """Read one coherent-enough display/runtime snapshot with one call per source."""
    omarchy_text = runner(("omarchy", "menu", "keybindings", "--print"))
    hyprctl_text = runner(("hyprctl", "binds"))
    return parse(omarchy_text, hyprctl_text), parse_runtime_bindings(hyprctl_text)


# Retain private aliases for callers that imported the original parser names.
_RuntimeBinding = RuntimeBinding
_parse_runtime_bindings = parse_runtime_bindings
