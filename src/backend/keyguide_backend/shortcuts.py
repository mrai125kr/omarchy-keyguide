"""Validated state and transactions for Keyguide-managed Omarchy shortcuts."""

from __future__ import annotations

import base64
import binascii
from collections.abc import Callable
from contextlib import contextmanager
import ctypes
from dataclasses import dataclass, replace
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import secrets
import shlex
import stat
import subprocess
from typing import Any
import unicodedata

from . import bindings, catalog, settings as settings_store
from .groups import SUPER_GROUPS, SUPPORTED_SHORTCUT_KEYS


_V1_HEADER = "-- Omarchy Keyguide managed shortcuts v1\n"
_V2_HEADER = "-- Omarchy Keyguide managed shortcuts v2\n"
_V3_HEADER = "-- Omarchy Keyguide managed shortcuts v3\n"
_V4_HEADER = "-- Omarchy Keyguide managed shortcuts v4\n"
_METADATA_PREFIX = "-- keyguide-state: "
_ID_PATTERN = re.compile(r"[a-z0-9][a-z0-9-]{0,79}")
_LUA_IDENTIFIER_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_LUA_NUMBER_PATTERN = re.compile(
    r"-?(?:(?:[0-9]+(?:\.[0-9]*)?)|(?:\.[0-9]+))(?:[eE][+-]?[0-9]+)?"
)
_LUA_LITERAL_IDENTIFIERS = frozenset({"true", "false", "nil"})
_LUA_RESERVED_IDENTIFIERS = _LUA_LITERAL_IDENTIFIERS | frozenset(
    {
        "and",
        "break",
        "do",
        "else",
        "elseif",
        "end",
        "for",
        "function",
        "goto",
        "if",
        "in",
        "local",
        "not",
        "or",
        "repeat",
        "return",
        "then",
        "until",
        "while",
    }
)
_LUA_PUNCTUATION = frozenset("{}[](),.=")
_CONFIG_KEY_NAMES = {
    "COMMA": "comma",
    "EQUAL": "equal",
    "MINUS": "minus",
    "PERIOD": "period",
    "SLASH": "slash",
}
_SOURCE_RECORD_COMMAND = (
    "/usr/bin/bash",
    "-c",
    "source /usr/bin/omarchy-menu-keybindings --print >/dev/null; "
    "output_binding_records",
)
SUPPORTED_KEYS = SUPPORTED_SHORTCUT_KEYS
_SUPPORTED_KEYS = frozenset(SUPPORTED_SHORTCUT_KEYS)
_SUPER_MODIFIER_TUPLES = frozenset(
    tuple(group.split("+")) for group in SUPER_GROUPS
)
ACTION_LABEL_KEYS = {
    "terminal": "action.terminal",
    "browser": "action.browser",
    "file manager": "action.fileManager",
    "application launcher": "action.applicationLauncher",
    "close window": "action.closeWindow",
    "toggle fullscreen": "action.toggleFullscreen",
    "full screen": "action.toggleFullscreen",
    "toggle floating": "action.toggleFloating",
    "lock screen": "action.lockScreen",
    "settings": "action.settings",
    "screenshot": "action.screenshot",
    "clipboard": "action.clipboard",
    "notifications": "action.notifications",
    "previous workspace": "action.previousWorkspace",
    "next workspace": "action.nextWorkspace",
    "download video from web app": "action.downloadVideoFromWebApp",
    "copy url from web app": "action.copyUrlFromWebApp",
    "activity": "action.activity",
    "agent": "action.agent",
    "apps menu": "action.appsMenu",
    "audio": "action.audio",
    "background switcher": "action.backgroundSwitcher",
    "bluetooth": "action.bluetooth",
    "browser (private)": "action.privateBrowser",
    "calculator": "action.calculator",
    "calendar": "action.calendar",
    "capture menu": "action.captureMenu",
    "clear reminders": "action.clearReminders",
    "clipboard manager": "action.clipboardManager",
    "color picker": "action.colorPicker",
    "dismiss all notifications": "action.dismissAllNotifications",
    "dismiss last notification": "action.dismissLastNotification",
    "display": "action.display",
    "editor": "action.editor",
    "email": "action.email",
    "emojis": "action.emojis",
    "extract text (ocr) from screenshot": "action.extractTextOcr",
    "file manager (cwd)": "action.fileManagerCwd",
    "focus on above window": "action.focusWindowAbove",
    "focus on below window": "action.focusWindowBelow",
    "focus on left window": "action.focusWindowLeft",
    "focus on right window": "action.focusWindowRight",
    "former workspace": "action.formerWorkspace",
    "full width": "action.fullWidth",
    "hardware menu": "action.hardwareMenu",
    "herdr keybindings": "action.herdrKeybindings",
    "invoke last notification": "action.invokeLastNotification",
    "keybindings": "action.keybindings",
    "lock system": "action.lockSystem",
    "monitor scaling down": "action.monitorScalingDown",
    "monitor scaling up": "action.monitorScalingUp",
    "move active window out of group": "action.moveActiveWindowOutOfGroup",
    "move grouped window focus left": "action.moveGroupedWindowFocusLeft",
    "move grouped window focus right": "action.moveGroupedWindowFocusRight",
    "move window to group on bottom": "action.moveWindowToGroupBottom",
    "move window to group on left": "action.moveWindowToGroupLeft",
    "move window to group on right": "action.moveWindowToGroupRight",
    "move window to group on top": "action.moveWindowToGroupTop",
    "move window to scratchpad": "action.moveWindowToScratchpad",
    "move workspace to down monitor": "action.moveWorkspaceToMonitorDown",
    "move workspace to left monitor": "action.moveWorkspaceToMonitorLeft",
    "move workspace to right monitor": "action.moveWorkspaceToMonitorRight",
    "move workspace to up monitor": "action.moveWorkspaceToMonitorUp",
    "music": "action.music",
    "music tui": "action.musicTui",
    "network": "action.network",
    "new email": "action.newEmail",
    "next window in group": "action.nextWindowInGroup",
    "omarchy menu": "action.omarchyMenu",
    "open notification history": "action.openNotificationHistory",
    "passwords": "action.passwords",
    "pop window out (float & pin)": "action.popWindowOut",
    "power": "action.power",
    "previous window in group": "action.previousWindowInGroup",
    "pseudo window": "action.pseudoWindow",
    "restore window width": "action.restoreWindowWidth",
    "save window width": "action.saveWindowWidth",
    "set reminder": "action.setReminder",
    "share": "action.share",
    "show battery remaining": "action.showBatteryRemaining",
    "show reminders": "action.showReminders",
    "show time": "action.showTime",
    "swap window down": "action.swapWindowDown",
    "swap window to the left": "action.swapWindowLeft",
    "swap window to the right": "action.swapWindowRight",
    "swap window up": "action.swapWindowUp",
    "system menu": "action.systemMenu",
    "theme menu": "action.themeMenu",
    "tiled full screen": "action.tiledFullScreen",
    "tmux keybindings": "action.tmuxKeybindings",
    "toggle dictation": "action.toggleDictation",
    "toggle laptop display": "action.toggleLaptopDisplay",
    "toggle laptop display mirroring": "action.toggleLaptopDisplayMirroring",
    "toggle locking on idle": "action.toggleLockingOnIdle",
    "toggle menu": "action.toggleMenu",
    "toggle nightlight": "action.toggleNightlight",
    "toggle scratchpad": "action.toggleScratchpad",
    "toggle silencing notifications": "action.toggleSilencingNotifications",
    "toggle single-window square aspect": "action.toggleSingleWindowSquareAspect",
    "toggle top bar": "action.toggleTopBar",
    "toggle weather": "action.toggleWeather",
    "toggle window floating/tiling": "action.toggleWindowFloatingTiling",
    "toggle window gaps": "action.toggleWindowGaps",
    "toggle window grouping": "action.toggleWindowGrouping",
    "toggle window split": "action.toggleWindowSplit",
    "toggle window transparency": "action.toggleWindowTransparency",
    "toggle workspace layout": "action.toggleWorkspaceLayout",
    "transcode": "action.transcode",
    "x post": "action.xPost",
    "brightness down": "action.brightnessDown",
    "brightness down precise": "action.brightnessDownPrecise",
    "brightness maximum": "action.brightnessMaximum",
    "brightness minimum": "action.brightnessMinimum",
    "brightness up": "action.brightnessUp",
    "brightness up precise": "action.brightnessUpPrecise",
    "capture entire screen": "action.captureEntireScreen",
    "capture highlighted window": "action.captureHighlightedWindow",
    "close all windows": "action.closeAllWindows",
    "disable touchpad": "action.disableTouchpad",
    "eject media": "action.ejectMedia",
    "enable touchpad": "action.enableTouchpad",
    "expand window down": "action.expandWindowDown",
    "expand window down a little": "action.expandWindowDownALittle",
    "expand window down a lot": "action.expandWindowDownALot",
    "expand window left": "action.expandWindowLeft",
    "expand window left a little": "action.expandWindowLeftALittle",
    "expand window left a lot": "action.expandWindowLeftALot",
    "focus on next monitor": "action.focusNextMonitor",
    "focus on next window": "action.focusNextWindow",
    "focus on previous monitor": "action.focusPreviousMonitor",
    "focus on previous window": "action.focusPreviousWindow",
    "keyboard backlight cycle": "action.keyboardBacklightCycle",
    "keyboard brightness down": "action.keyboardBrightnessDown",
    "keyboard brightness up": "action.keyboardBrightnessUp",
    "make webcam overlay larger": "action.webcamOverlayLarger",
    "make webcam overlay smaller": "action.webcamOverlaySmaller",
    "move window": "action.moveWindow",
    "mute": "action.mute",
    "mute microphone": "action.muteMicrophone",
    "next track": "action.nextTrack",
    "pause": "action.pauseMedia",
    "play": "action.playMedia",
    "power menu": "action.powerMenu",
    "previous track": "action.previousTrack",
    "reset zoom": "action.resetZoom",
    "resize window": "action.resizeWindow",
    "reveal active window on top": "action.revealActiveWindow",
    "screenrecording": "action.screenRecording",
    "scroll active workspace backward": "action.scrollWorkspaceBackward",
    "scroll active workspace forward": "action.scrollWorkspaceForward",
    "select next window to capture": "action.selectNextCaptureWindow",
    "select previous window to capture": "action.selectPreviousCaptureWindow",
    "select window to capture": "action.selectCaptureWindow",
    "shrink window left": "action.shrinkWindowLeft",
    "shrink window left a little": "action.shrinkWindowLeftALittle",
    "shrink window left a lot": "action.shrinkWindowLeftALot",
    "shrink window up": "action.shrinkWindowUp",
    "shrink window up a little": "action.shrinkWindowUpALittle",
    "shrink window up a lot": "action.shrinkWindowUpALot",
    "start dictation (push-to-talk)": "action.startDictationPushToTalk",
    "stop dictation (push-to-talk)": "action.stopDictationPushToTalk",
    "switch audio output": "action.switchAudioOutput",
    "switch media source": "action.switchMediaSource",
    "toggle touchpad": "action.toggleTouchpad",
    "universal copy": "action.universalCopy",
    "universal cut": "action.universalCut",
    "universal paste": "action.universalPaste",
    "volume down": "action.volumeDown",
    "volume down precise": "action.volumeDownPrecise",
    "volume up": "action.volumeUp",
    "volume up precise": "action.volumeUpPrecise",
    "zoom in": "action.zoomIn",
}
ACTION_LABEL_PATTERNS = (
    (re.compile(r"^bar panel [0-9]+$"), "action.barPanel"),
    (re.compile(r"^switch to workspace [0-9]+$"), "action.switchWorkspace"),
    (
        re.compile(r"^move window to workspace [0-9]+$"),
        "action.moveWindowToWorkspace",
    ),
    (
        re.compile(r"^move window silently to workspace [0-9]+$"),
        "action.moveWindowSilentlyToWorkspace",
    ),
    (
        re.compile(r"^switch to group window [0-9]+$"),
        "action.switchGroupWindow",
    ),
)
_LABEL_KEY_PATTERN = re.compile(r"action\.[A-Za-z][A-Za-z0-9]*")
_XKB_KEYCODE_PATTERN = re.compile(
    r"^\s*<([^>]+)>\s*=\s*([0-9]+);\s*$",
    re.MULTILINE,
)
_XKB_KEY_BLOCK_PATTERN = re.compile(
    r"^\s*key\s+<([^>]+)>\s*\{(.*?)\}\s*;",
    re.MULTILINE | re.DOTALL,
)
_XKB_GROUP_ONE_SYMBOL_PATTERN = re.compile(
    r"symbols\[(?:1|Group1)\]\s*=\s*\[\s*([^,\]\s]+)",
)
_XKB_DIRECT_SYMBOL_PATTERN = re.compile(
    r"^\s*\[\s*([^,\]\s]+)",
)


class ShortcutValidationError(ValueError):
    """Raised when managed shortcut state is unsafe or non-canonical."""

    default_code = "shortcut.invalid"

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        context: dict[str, str] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code or self.default_code
        self.context = dict(context or {})


class ShortcutConflictError(ShortcutValidationError):
    """Raised when live bindings changed or a requested chord is occupied."""

    default_code = "shortcut.conflict"


class ShortcutMutationError(RuntimeError):
    """Raised when an authenticated shortcut publication cannot be completed."""

    default_code = "shortcut.mutation_failed"

    def __init__(
        self,
        message: str,
        *,
        code: str | None = None,
        context: dict[str, str] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code or self.default_code
        self.context = dict(context or {})


def _has_control(value: str) -> bool:
    return any(ord(character) < 32 or ord(character) == 127 for character in value)


def _has_unicode_control(value: str) -> bool:
    return any(unicodedata.category(character) == "Cc" for character in value)


def action_label_key(english_title: str) -> str:
    """Return the stable presentation key for a recognized English action."""
    normalized = " ".join(str(english_title or "").split()).casefold()
    exact = ACTION_LABEL_KEYS.get(normalized, "")
    if exact:
        return exact
    for pattern, label_key in ACTION_LABEL_PATTERNS:
        if pattern.fullmatch(normalized):
            return label_key
    return ""


def action_launch_kind(action: "ShortcutAction") -> str:
    """Classify launcher-backed actions that need an explicit picker badge."""
    if action.action_kind != "exec":
        return ""
    if catalog.webapp_target_id(action.action_argument):
        return "webapp"
    return ""


_AGENT_DISPLAY_NAMES = {
    "pi": "Pi",
    "omp": "Oh My Pi",
    "opencode": "OpenCode",
    "claude": "Claude Code",
    "codex": "Codex",
    "crush": "Crush",
    "grok": "Grok",
    "gemini": "Gemini",
    "copilot": "GitHub Copilot",
}

_BROWSER_DISPLAY_NAMES = {
    "chromium": "Chromium",
    "chrome": "Chrome",
    "brave": "Brave",
    "brave-origin": "Brave Origin",
    "edge": "Edge",
    "firefox": "Firefox",
    "zen": "Zen",
}

_BROWSER_DESKTOP_IDS = {
    "chromium": "chromium.desktop",
    "chrome": "google-chrome.desktop",
    "brave": "brave-browser.desktop",
    "brave-origin": "brave-origin.desktop",
    "edge": "microsoft-edge.desktop",
    "firefox": "firefox.desktop",
    "zen": "zen.desktop",
}

_EDITOR_DISPLAY_NAMES = {
    "code": "VSCode",
    "cursor": "Cursor",
    "zeditor": "Zed",
    "zed": "Zed",
    "sublime_text": "Sublime Text",
    "helix": "Helix",
    "hx": "Helix",
    "vim": "Vim",
    "emacs": "Emacs",
    "nvim": "Neovim",
}

_TERMINAL_EDITORS = {"nvim", "vim", "nano", "micro", "hx", "helix", "fresh"}


def _lua_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _lua_tokens(value: str) -> list[tuple[str, str]]:
    tokens: list[tuple[str, str]] = []
    position = 0
    while position < len(value):
        character = value[position]
        if character == " ":
            position += 1
            continue
        if character in {'"', "'"}:
            quote = character
            end = position + 1
            while end < len(value):
                if value[end] == "\\":
                    end += 2
                    continue
                if value[end] == quote:
                    end += 1
                    tokens.append(("string", value[position:end]))
                    position = end
                    break
                if value[end] in "\r\n":
                    raise ShortcutValidationError("Lua action string is invalid")
                end += 1
            else:
                raise ShortcutValidationError("Lua action string is unterminated")
            continue
        number = _LUA_NUMBER_PATTERN.match(value, position)
        if number is not None:
            literal = number.group()
            if not math.isfinite(float(literal)):
                raise ShortcutValidationError("Lua action number must be finite")
            tokens.append(("number", literal))
            position = number.end()
            continue
        identifier = _LUA_IDENTIFIER_PATTERN.match(value, position)
        if identifier is not None:
            tokens.append(("identifier", identifier.group()))
            position = identifier.end()
            continue
        if character in _LUA_PUNCTUATION:
            tokens.append((character, character))
            position += 1
            continue
        raise ShortcutValidationError("Lua action contains an unsupported token")
    return tokens


class _LuaExpressionParser:
    def __init__(self, tokens: list[tuple[str, str]]) -> None:
        self.tokens = tokens
        self.position = 0

    def _peek(self, kind: str, value: str | None = None) -> bool:
        if self.position >= len(self.tokens):
            return False
        token_kind, token_value = self.tokens[self.position]
        return token_kind == kind and (value is None or token_value == value)

    def _take(self, kind: str, value: str | None = None) -> str:
        if not self._peek(kind, value):
            raise ShortcutValidationError("Lua action expression does not match grammar")
        token_value = self.tokens[self.position][1]
        self.position += 1
        return token_value

    def _take_identifier(self) -> str:
        identifier = self._take("identifier")
        if identifier in _LUA_RESERVED_IDENTIFIERS:
            raise ShortcutValidationError("Lua action identifier is reserved")
        return identifier

    def parse(self) -> None:
        self._take("identifier", "hl")
        self._take(".")
        self._take("identifier", "dsp")
        self._take(".")
        self._take_identifier()
        while self._peek("."):
            self._take(".")
            self._take_identifier()
        self._take("(")
        if not self._peek(")"):
            self._parse_value()
            while self._peek(","):
                self._take(",")
                self._parse_value()
        self._take(")")
        if self.position != len(self.tokens):
            raise ShortcutValidationError("Lua action has trailing text")

    def _parse_value(self) -> None:
        if self._peek("string") or self._peek("number"):
            self.position += 1
            return
        if self._peek("identifier"):
            literal = self.tokens[self.position][1]
            if literal not in _LUA_LITERAL_IDENTIFIERS:
                raise ShortcutValidationError("Lua action value is not a literal")
            self.position += 1
            return
        if self._peek("{"):
            self._parse_table()
            return
        raise ShortcutValidationError("Lua action value does not match grammar")

    def _parse_table(self) -> None:
        self._take("{")
        if self._peek("}"):
            self._take("}")
            return
        while True:
            self._parse_table_entry()
            if not self._peek(","):
                break
            self._take(",")
            if self._peek("}"):
                break
        self._take("}")

    def _parse_table_entry(self) -> None:
        if self._peek("["):
            self._take("[")
            self._parse_value()
            self._take("]")
            self._take("=")
            self._parse_value()
            return
        if (
            self._peek("identifier")
            and self.tokens[self.position][1] not in _LUA_RESERVED_IDENTIFIERS
            and self.position + 1 < len(self.tokens)
            and self.tokens[self.position + 1][0] == "="
        ):
            self._take_identifier()
            self._take("=")
            self._parse_value()
            return
        self._parse_value()


def validate_lua_dispatcher_expression(value: str) -> str:
    """Validate one scanner-produced hl.dsp call without executing it."""
    if (
        not isinstance(value, str)
        or not value
        or len(value) > 4096
        or _has_unicode_control(value)
    ):
        raise ShortcutValidationError("Lua action expression is invalid")
    try:
        _LuaExpressionParser(_lua_tokens(value)).parse()
    except (OverflowError, RecursionError) as error:
        raise ShortcutValidationError("Lua action expression is invalid") from error
    return value


def _json_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ShortcutValidationError(f"duplicate managed shortcut key: {key}")
        result[key] = value
    return result


def _xkb_keycode_symbols(keymap: str) -> dict[int, str | None]:
    """Map physical codes to unmodified symbols from canonical XKB output."""
    if not isinstance(keymap, str) or not keymap or len(keymap) > 4 * 1024 * 1024:
        raise ShortcutConflictError("compiled XKB keymap is invalid")

    codes_by_name: dict[str, int] = {}
    names_by_code: dict[int, str] = {}
    for name, raw_code in _XKB_KEYCODE_PATTERN.findall(keymap):
        code = int(raw_code)
        if name in codes_by_name or code in names_by_code:
            raise ShortcutConflictError("compiled XKB keymap has duplicate keycodes")
        codes_by_name[name] = code
        names_by_code[code] = name

    symbols_by_name: dict[str, str] = {}
    for name, block in _XKB_KEY_BLOCK_PATTERN.findall(keymap):
        if name in symbols_by_name:
            raise ShortcutConflictError("compiled XKB keymap has duplicate symbols")
        match = _XKB_GROUP_ONE_SYMBOL_PATTERN.search(block)
        if match is None:
            match = _XKB_DIRECT_SYMBOL_PATTERN.match(block)
        if match is None:
            continue
        symbol = match.group(1)
        symbols_by_name[name] = symbol

    result: dict[int, str | None] = {}
    for name, code in codes_by_name.items():
        symbol = symbols_by_name.get(name)
        if symbol is None:
            continue
        canonical = bindings.canonical_key(symbol)
        result[code] = canonical if canonical in _SUPPORTED_KEYS else None
    if not result:
        raise ShortcutConflictError("compiled XKB keymap has no usable key definitions")
    return result


@dataclass(frozen=True)
class ShortcutAction:
    """One reconstructable keyboard-only action represented in generated Lua."""

    modifiers: tuple[str, ...]
    key: str
    description: str
    action_kind: str
    action_argument: str

    def __post_init__(self) -> None:
        if not isinstance(self.modifiers, tuple) or self.modifiers not in _SUPER_MODIFIER_TUPLES:
            raise ShortcutValidationError("shortcut modifiers must be one supported Super group")
        if not isinstance(self.key, str) or self.key not in _SUPPORTED_KEYS:
            raise ShortcutValidationError("shortcut key is not supported")
        if (
            not isinstance(self.description, str)
            or not self.description.strip()
            or len(self.description) > 120
            or _has_control(self.description)
        ):
            raise ShortcutValidationError("shortcut description is invalid")
        if not isinstance(self.action_kind, str) or self.action_kind not in {
            "exec",
            "lua",
        }:
            raise ShortcutValidationError("shortcut action kind is invalid")
        if self.action_kind == "exec":
            if (
                not isinstance(self.action_argument, str)
                or not self.action_argument.strip()
                or len(self.action_argument) > 4096
                or _has_control(self.action_argument)
            ):
                raise ShortcutValidationError("shortcut command is invalid")
        else:
            validate_lua_dispatcher_expression(self.action_argument)

    @property
    def chord(self) -> tuple[tuple[str, ...], str]:
        return self.modifiers, self.key

    def config_chord(self) -> str:
        key = _CONFIG_KEY_NAMES.get(self.key, self.key)
        return " + ".join((*self.modifiers, key))

    def as_dict(self) -> dict[str, Any]:
        return {
            "modifiers": list(self.modifiers),
            "key": self.key,
            "description": self.description,
            "actionKind": self.action_kind,
            "actionArgument": self.action_argument,
        }

    @classmethod
    def from_dict(cls, value: object) -> "ShortcutAction":
        if not isinstance(value, dict) or set(value) != {
            "modifiers",
            "key",
            "description",
            "actionKind",
            "actionArgument",
        }:
            raise ShortcutValidationError("shortcut action keys do not match schema")
        modifiers = value["modifiers"]
        if not isinstance(modifiers, list) or not all(
            isinstance(modifier, str) for modifier in modifiers
        ):
            raise ShortcutValidationError("shortcut action modifiers must be strings")
        return cls(
            modifiers=tuple(modifiers),
            key=value["key"],
            description=value["description"],
            action_kind=value["actionKind"],
            action_argument=value["actionArgument"],
        )

    def as_v1_dict(self) -> dict[str, Any]:
        if self.action_kind != "exec":
            raise ShortcutValidationError("version 1 shortcuts must be exec actions")
        return {
            "modifiers": list(self.modifiers),
            "key": self.key,
            "description": self.description,
            "command": self.action_argument,
        }

    @classmethod
    def from_v1_dict(cls, value: object) -> "ShortcutAction":
        if not isinstance(value, dict) or set(value) != {
            "modifiers",
            "key",
            "description",
            "command",
        }:
            raise ShortcutValidationError("version 1 shortcut action keys do not match schema")
        modifiers = value["modifiers"]
        if not isinstance(modifiers, list) or not all(
            isinstance(modifier, str) for modifier in modifiers
        ):
            raise ShortcutValidationError("shortcut action modifiers must be strings")
        return cls(
            modifiers=tuple(modifiers),
            key=value["key"],
            description=value["description"],
            action_kind="exec",
            action_argument=value["command"],
        )


@dataclass(frozen=True)
class ManagedShortcutEntry:
    """A new action or one exact override of an inspected source binding."""

    id: str
    kind: str
    source_binding_id: str | None
    original: ShortcutAction | None
    current: ShortcutAction
    selection_kind: str = ""
    selection_id: str = ""
    label_key: str = ""
    title_override: str = ""

    def __post_init__(self) -> None:
        if not isinstance(self.id, str) or _ID_PATTERN.fullmatch(self.id) is None:
            raise ShortcutValidationError("managed shortcut id is invalid")
        if not isinstance(self.current, ShortcutAction):
            raise ShortcutValidationError("managed shortcut current action is invalid")
        if (
            not isinstance(self.selection_kind, str)
            or self.selection_kind not in {"", "action", "application", "command"}
        ):
            raise ShortcutValidationError("managed shortcut selection kind is invalid")
        if self.selection_kind == "":
            valid_selection = self.selection_id == ""
        elif self.selection_kind == "action":
            valid_selection = (
                isinstance(self.selection_id, str)
                and _ID_PATTERN.fullmatch(self.selection_id) is not None
            )
        else:
            valid_selection = catalog.is_valid_identity(
                self.selection_kind, self.selection_id
            )
        if not valid_selection:
            raise ShortcutValidationError("managed shortcut selection identity is invalid")
        if (
            not isinstance(self.label_key, str)
            or (
                self.label_key
                and _LABEL_KEY_PATTERN.fullmatch(self.label_key) is None
            )
            or (self.selection_kind in {"application", "command"} and self.label_key)
        ):
            raise ShortcutValidationError("managed shortcut label key is invalid")
        if (
            not isinstance(self.title_override, str)
            or len(self.title_override) > 120
            or _has_control(self.title_override)
        ):
            raise ShortcutValidationError("managed shortcut title override is invalid")
        if self.kind == "new":
            if self.source_binding_id is not None or self.original is not None:
                raise ShortcutValidationError("new shortcut cannot claim an original binding")
            return
        if self.kind == "override":
            if (
                not isinstance(self.source_binding_id, str)
                or not self.source_binding_id
                or len(self.source_binding_id) > 200
                or _has_control(self.source_binding_id)
                or not isinstance(self.original, ShortcutAction)
            ):
                raise ShortcutValidationError("override shortcut source is invalid")
            return
        raise ShortcutValidationError("managed shortcut kind is invalid")

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "kind": self.kind,
            "sourceBindingId": self.source_binding_id,
            "original": self.original.as_dict() if self.original is not None else None,
            "current": self.current.as_dict(),
            "selectionKind": self.selection_kind,
            "selectionId": self.selection_id,
            "labelKey": self.label_key,
            "titleOverride": self.title_override,
        }

    def as_v2_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "kind": self.kind,
            "sourceBindingId": self.source_binding_id,
            "original": self.original.as_dict() if self.original is not None else None,
            "current": self.current.as_dict(),
        }

    def as_v1_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "kind": self.kind,
            "sourceBindingId": self.source_binding_id,
            "original": (
                self.original.as_v1_dict() if self.original is not None else None
            ),
            "current": self.current.as_v1_dict(),
        }

    @classmethod
    def from_dict(cls, value: object) -> "ManagedShortcutEntry":
        if not isinstance(value, dict) or set(value) != {
            "id",
            "kind",
            "sourceBindingId",
            "original",
            "current",
            "selectionKind",
            "selectionId",
            "labelKey",
            "titleOverride",
        }:
            raise ShortcutValidationError("managed shortcut entry keys do not match schema")
        original = value["original"]
        return cls(
            id=value["id"],
            kind=value["kind"],
            source_binding_id=value["sourceBindingId"],
            original=(ShortcutAction.from_dict(original) if original is not None else None),
            current=ShortcutAction.from_dict(value["current"]),
            selection_kind=value["selectionKind"],
            selection_id=value["selectionId"],
            label_key=value["labelKey"],
            title_override=value["titleOverride"],
        )

    @classmethod
    def from_v2_dict(cls, value: object) -> "ManagedShortcutEntry":
        if not isinstance(value, dict) or set(value) != {
            "id",
            "kind",
            "sourceBindingId",
            "original",
            "current",
        }:
            raise ShortcutValidationError(
                "version 2 managed shortcut entry keys do not match schema"
            )
        original = value["original"]
        return cls(
            id=value["id"],
            kind=value["kind"],
            source_binding_id=value["sourceBindingId"],
            original=(ShortcutAction.from_dict(original) if original is not None else None),
            current=ShortcutAction.from_dict(value["current"]),
        )

    @classmethod
    def from_v1_dict(cls, value: object) -> "ManagedShortcutEntry":
        if not isinstance(value, dict) or set(value) != {
            "id",
            "kind",
            "sourceBindingId",
            "original",
            "current",
        }:
            raise ShortcutValidationError(
                "version 1 managed shortcut entry keys do not match schema"
            )
        original = value["original"]
        return cls(
            id=value["id"],
            kind=value["kind"],
            source_binding_id=value["sourceBindingId"],
            original=(
                ShortcutAction.from_v1_dict(original) if original is not None else None
            ),
            current=ShortcutAction.from_v1_dict(value["current"]),
        )


@dataclass(frozen=True)
class SuppressedShortcut:
    """One exact source binding intentionally hidden until Reset restores it."""

    id: str
    source_binding_id: str
    modifiers: tuple[str, ...]
    key: str
    description: str
    dispatcher: str | None
    argument: str | None
    original: ShortcutAction | None

    def __post_init__(self) -> None:
        if not isinstance(self.id, str) or _ID_PATTERN.fullmatch(self.id) is None:
            raise ShortcutValidationError("suppressed shortcut id is invalid")
        if (
            not isinstance(self.source_binding_id, str)
            or not self.source_binding_id
            or len(self.source_binding_id) > 200
            or _has_control(self.source_binding_id)
        ):
            raise ShortcutValidationError("suppressed shortcut source is invalid")
        if not isinstance(self.modifiers, tuple) or self.modifiers not in _SUPER_MODIFIER_TUPLES:
            raise ShortcutValidationError(
                "suppressed shortcut modifiers must be one supported Super group"
            )
        if not isinstance(self.key, str) or self.key not in _SUPPORTED_KEYS:
            raise ShortcutValidationError("suppressed shortcut key is not supported")
        if (
            not isinstance(self.description, str)
            or not self.description.strip()
            or len(self.description) > 120
            or _has_control(self.description)
        ):
            raise ShortcutValidationError("suppressed shortcut description is invalid")
        if (self.dispatcher is None) != (self.argument is None):
            raise ShortcutValidationError(
                "suppressed shortcut runtime identity must be complete"
            )
        if self.dispatcher is not None and (
            not isinstance(self.dispatcher, str)
            or not self.dispatcher
            or len(self.dispatcher) > 120
            or _has_control(self.dispatcher)
            or not isinstance(self.argument, str)
            or len(self.argument) > 4096
            or _has_control(self.argument)
        ):
            raise ShortcutValidationError(
                "suppressed shortcut runtime identity is invalid"
            )
        if self.original is None and self.dispatcher is None:
            raise ShortcutValidationError(
                "suppressed shortcut must retain a restorable identity"
            )
        if self.original is not None:
            if not isinstance(self.original, ShortcutAction):
                raise ShortcutValidationError(
                    "suppressed shortcut original action is invalid"
                )
            if self.original.chord != self.chord:
                raise ShortcutValidationError(
                    "suppressed shortcut original chord does not match"
                )
            if self.original.description != self.description:
                raise ShortcutValidationError(
                    "suppressed shortcut original title does not match"
                )

    @property
    def chord(self) -> tuple[tuple[str, ...], str]:
        return self.modifiers, self.key

    def config_chord(self) -> str:
        key = _CONFIG_KEY_NAMES.get(self.key, self.key)
        return " + ".join((*self.modifiers, key))

    def as_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "sourceBindingId": self.source_binding_id,
            "modifiers": list(self.modifiers),
            "key": self.key,
            "description": self.description,
            "dispatcher": self.dispatcher,
            "argument": self.argument,
            "original": self.original.as_dict() if self.original is not None else None,
        }

    @classmethod
    def from_dict(cls, value: object) -> "SuppressedShortcut":
        if not isinstance(value, dict) or set(value) != {
            "id",
            "sourceBindingId",
            "modifiers",
            "key",
            "description",
            "dispatcher",
            "argument",
            "original",
        }:
            raise ShortcutValidationError(
                "suppressed shortcut keys do not match schema"
            )
        modifiers = value["modifiers"]
        if not isinstance(modifiers, list) or not all(
            isinstance(modifier, str) for modifier in modifiers
        ):
            raise ShortcutValidationError(
                "suppressed shortcut modifiers must be strings"
            )
        original = value["original"]
        return cls(
            id=value["id"],
            source_binding_id=value["sourceBindingId"],
            modifiers=tuple(modifiers),
            key=value["key"],
            description=value["description"],
            dispatcher=value["dispatcher"],
            argument=value["argument"],
            original=(
                ShortcutAction.from_dict(original) if original is not None else None
            ),
        )


@dataclass(frozen=True)
class ManagedShortcutState:
    """Canonical metadata and executable Lua stored as one atomic file."""

    entries: tuple[ManagedShortcutEntry, ...]
    suppressed: tuple[SuppressedShortcut, ...] = ()

    def __post_init__(self) -> None:
        if not isinstance(self.entries, tuple) or not all(
            isinstance(entry, ManagedShortcutEntry) for entry in self.entries
        ):
            raise ShortcutValidationError("managed shortcut entries must be a tuple")
        if not isinstance(self.suppressed, tuple) or not all(
            isinstance(item, SuppressedShortcut) for item in self.suppressed
        ):
            raise ShortcutValidationError("suppressed shortcuts must be a tuple")
        ids = [entry.id for entry in self.entries] + [
            item.id for item in self.suppressed
        ]
        current_chords = [entry.current.chord for entry in self.entries]
        original_chords = [
            entry.original.chord
            for entry in self.entries
            if entry.kind == "override" and entry.original is not None
        ]
        suppressed_chords = [item.chord for item in self.suppressed]
        source_ids = [
            entry.source_binding_id
            for entry in self.entries
            if entry.kind == "override"
        ] + [item.source_binding_id for item in self.suppressed]
        if len(ids) != len(set(ids)):
            raise ShortcutValidationError("managed shortcut ids must be unique")
        if len(current_chords) != len(set(current_chords)):
            raise ShortcutValidationError("managed current shortcut chords must be unique")
        if len(original_chords) != len(set(original_chords)):
            raise ShortcutValidationError("managed original shortcut chords must be unique")
        if len(suppressed_chords) != len(set(suppressed_chords)):
            raise ShortcutValidationError("suppressed shortcut chords must be unique")
        if len(original_chords + suppressed_chords) != len(
            set(original_chords + suppressed_chords)
        ):
            raise ShortcutValidationError(
                "effective suppressed shortcut chords must be unique"
            )
        if len(source_ids) != len(set(source_ids)):
            raise ShortcutValidationError(
                "managed shortcut source identities must be unique"
            )
        object.__setattr__(self, "entries", tuple(sorted(self.entries, key=lambda entry: entry.id)))
        object.__setattr__(
            self,
            "suppressed",
            tuple(sorted(self.suppressed, key=lambda item: item.id)),
        )

    @classmethod
    def empty(cls) -> "ManagedShortcutState":
        return cls(entries=(), suppressed=())

    def as_dict(self) -> dict[str, Any]:
        return {
            "version": 4,
            "entries": [entry.as_dict() for entry in self.entries],
            "suppressed": [item.as_dict() for item in self.suppressed],
        }

    def _as_v3_dict(self) -> dict[str, Any]:
        return {
            "version": 3,
            "entries": [entry.as_dict() for entry in self.entries],
        }

    def _as_v2_dict(self) -> dict[str, Any]:
        return {
            "version": 2,
            "entries": [entry.as_v2_dict() for entry in self.entries],
        }

    def _as_v1_dict(self) -> dict[str, Any]:
        return {
            "version": 1,
            "entries": [entry.as_v1_dict() for entry in self.entries],
        }

    def _render(self, *, version: int) -> bytes:
        if version < 4 and self.suppressed:
            raise ShortcutValidationError(
                "historical managed shortcut versions cannot store suppression"
            )
        if version == 1:
            document = self._as_v1_dict()
            header = _V1_HEADER
        elif version == 2:
            document = self._as_v2_dict()
            header = _V2_HEADER
        elif version == 3:
            document = self._as_v3_dict()
            header = _V3_HEADER
        elif version == 4:
            document = self.as_dict()
            header = _V4_HEADER
        else:
            raise ShortcutValidationError("managed shortcut version is unsupported")
        metadata = json.dumps(
            document,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
        encoded = base64.urlsafe_b64encode(metadata).rstrip(b"=").decode("ascii")
        lines = [
            header.rstrip("\n"),
            _METADATA_PREFIX + encoded,
            "-- Generated by Omarchy Keyguide. Use Settings instead of editing this file.",
        ]
        if not self.entries and not self.suppressed:
            lines.append("-- No managed shortcuts.")
        for item in self.suppressed:
            lines.append(f"hl.unbind({_lua_string(item.config_chord())})")
        for entry in self.entries:
            if entry.kind == "override" and entry.original is not None:
                lines.append(f"hl.unbind({_lua_string(entry.original.config_chord())})")
        for entry in self.entries:
            lines.append(
                "o.bind("
                + ", ".join(
                    (
                        _lua_string(entry.current.config_chord()),
                        _lua_string(entry.current.description),
                        _lua_string(entry.current.action_argument),
                    )
                )
                + ")"
                if entry.current.action_kind == "exec"
                else "hl.bind("
                + ", ".join(
                    (
                        _lua_string(entry.current.config_chord()),
                        entry.current.action_argument,
                        "{ description = "
                        + _lua_string(entry.current.description)
                        + " }",
                    )
                )
                + ")"
            )
        return ("\n".join(lines) + "\n").encode("utf-8")

    def to_bytes(self) -> bytes:
        return self._render(version=4)

    @classmethod
    def from_bytes(cls, value: bytes) -> "ManagedShortcutState":
        if not isinstance(value, bytes):
            raise ShortcutValidationError("managed shortcut module must be bytes")
        lines = value.splitlines()
        if len(lines) < 3:
            raise ShortcutValidationError("managed shortcut module header is invalid")
        if lines[0] == _V1_HEADER.rstrip("\n").encode("ascii"):
            expected_version = 1
        elif lines[0] == _V2_HEADER.rstrip("\n").encode("ascii"):
            expected_version = 2
        elif lines[0] == _V3_HEADER.rstrip("\n").encode("ascii"):
            expected_version = 3
        elif lines[0] == _V4_HEADER.rstrip("\n").encode("ascii"):
            expected_version = 4
        else:
            raise ShortcutValidationError("managed shortcut module header is invalid")
        prefix = _METADATA_PREFIX.encode("ascii")
        if not lines[1].startswith(prefix):
            raise ShortcutValidationError("managed shortcut metadata is missing")
        encoded = lines[1][len(prefix) :]
        try:
            padding = b"=" * (-len(encoded) % 4)
            metadata = base64.b64decode(encoded + padding, altchars=b"-_", validate=True)
            document = json.loads(
                metadata.decode("utf-8"), object_pairs_hook=_json_object
            )
        except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ShortcutValidationError("managed shortcut metadata is invalid") from error
        expected_keys = (
            {"version", "entries", "suppressed"}
            if expected_version == 4
            else {"version", "entries"}
        )
        if not isinstance(document, dict) or set(document) != expected_keys:
            raise ShortcutValidationError("managed shortcut document keys do not match schema")
        version = document["version"]
        if (
            not isinstance(version, int)
            or isinstance(version, bool)
            or version != expected_version
        ):
            raise ShortcutValidationError("managed shortcut version is unsupported")
        raw_entries = document["entries"]
        if not isinstance(raw_entries, list):
            raise ShortcutValidationError("managed shortcut entries must be a list")
        if version == 1:
            state = cls(
                entries=tuple(
                    ManagedShortcutEntry.from_v1_dict(item) for item in raw_entries
                )
            )
            canonical = state._render(version=1)
        elif version == 2:
            state = cls(
                entries=tuple(
                    ManagedShortcutEntry.from_v2_dict(item) for item in raw_entries
                )
            )
            canonical = state._render(version=2)
        elif version == 3:
            state = cls(
                entries=tuple(ManagedShortcutEntry.from_dict(item) for item in raw_entries)
            )
            canonical = state._render(version=3)
        else:
            raw_suppressed = document["suppressed"]
            if not isinstance(raw_suppressed, list):
                raise ShortcutValidationError(
                    "suppressed shortcuts must be a list"
                )
            state = cls(
                entries=tuple(
                    ManagedShortcutEntry.from_dict(item) for item in raw_entries
                ),
                suppressed=tuple(
                    SuppressedShortcut.from_dict(item) for item in raw_suppressed
                ),
            )
            canonical = state.to_bytes()
        if canonical != value:
            raise ShortcutValidationError("managed shortcut module is not canonical")
        return state


@dataclass(frozen=True)
class _FileSnapshot:
    data: bytes
    device: int
    inode: int
    mode: int
    uid: int
    gid: int


@dataclass(frozen=True)
class _CatalogAction:
    id: str
    binding: bindings.Binding
    action: ShortcutAction
    entry: ManagedShortcutEntry | None


ShortcutRunner = Callable[[tuple[str, ...]], str]


class ShortcutManager:
    """Apply one authenticated generated shortcut module and validate reloads."""

    _RENAME_EXCHANGE = 2

    def __init__(
        self,
        *,
        home: str | Path | None = None,
        state_home: str | Path | None = None,
        runner: ShortcutRunner = bindings.run_command,
        keycode_symbols: dict[int, str | None] | None = None,
        catalog_discovery: catalog.CatalogDiscovery | None = None,
    ) -> None:
        requested_home = Path(home) if home is not None else Path.home()
        self.home = requested_home.resolve()
        requested_state = (
            Path(state_home)
            if state_home is not None
            else Path(os.environ.get("XDG_STATE_HOME") or self.home / ".local/state")
        )
        self.state_home = requested_state.resolve(strict=False)
        try:
            self.state_home.relative_to(self.home)
        except ValueError as error:
            raise ShortcutValidationError("shortcut state home must stay below HOME") from error
        self.path = (
            self.state_home
            / "omarchy"
            / "toggles"
            / "hypr"
            / "omarchy-keyguide.lua"
        )
        self.lock_path = self.state_home / "omarchy-keyguide" / "shortcuts.lock"
        self.reset_journal_path = (
            self.state_home / "omarchy-keyguide" / "reset-all-transaction.json"
        )
        self.runner = runner
        self.catalog_discovery = catalog_discovery or catalog.CatalogDiscovery()
        self._keycode_symbols_injected = keycode_symbols is not None
        self._keycode_symbols = (
            dict(keycode_symbols) if keycode_symbols is not None else None
        )

    def _open_directory(self, directory: Path, *, create: bool) -> int:
        try:
            relative = directory.relative_to(self.home)
        except ValueError as error:
            raise ShortcutValidationError("shortcut directory escapes HOME") from error
        descriptor = os.open(
            self.home,
            os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
        )
        try:
            for component in relative.parts:
                if component in {"", ".", ".."}:
                    raise ShortcutValidationError("shortcut directory has an unsafe component")
                try:
                    next_descriptor = os.open(
                        component,
                        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                        dir_fd=descriptor,
                    )
                except FileNotFoundError:
                    if not create:
                        raise
                    os.mkdir(component, 0o700, dir_fd=descriptor)
                    os.fsync(descriptor)
                    next_descriptor = os.open(
                        component,
                        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                        dir_fd=descriptor,
                    )
                info = os.fstat(next_descriptor)
                if info.st_uid != os.getuid():
                    os.close(next_descriptor)
                    raise ShortcutValidationError("shortcut directory is not owned by the user")
                os.close(descriptor)
                descriptor = next_descriptor
            return descriptor
        except BaseException:
            os.close(descriptor)
            raise

    def _default_agent_name(self) -> str:
        path = self.home / ".config" / "omarchy" / "defaults" / "agent"
        descriptor = -1
        try:
            descriptor = os.open(
                path,
                os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
            )
            info = os.fstat(descriptor)
            if (
                not stat.S_ISREG(info.st_mode)
                or info.st_size > 64
                or info.st_uid != os.getuid()
            ):
                return ""
            data = os.read(descriptor, 65)
            if len(data) > 64:
                return ""
            value = data.decode("utf-8").strip()
        except (OSError, UnicodeError):
            return ""
        finally:
            if descriptor >= 0:
                os.close(descriptor)
        return _AGENT_DISPLAY_NAMES.get(value, "")

    @staticmethod
    def _is_agent_action(action: ShortcutAction) -> bool:
        if action.action_kind != "exec":
            return False
        try:
            command = shlex.split(action.action_argument, posix=True)
        except ValueError:
            return False
        return bool(command and Path(command[0]).name == "omarchy-agent")

    def _default_browser_details(
        self, applications_by_id: dict[str, catalog.CatalogItem]
    ) -> tuple[str, str]:
        try:
            desktop_id = str(self.runner(
                ("env", "-u", "BROWSER", "xdg-settings", "get", "default-web-browser")
            ) or "").strip()
        except (OSError, subprocess.SubprocessError):
            desktop_id = ""
        value = ""
        if not desktop_id.endswith(".desktop"):
            try:
                value = str(self.runner(("omarchy-default-browser",)) or "").strip()
            except (OSError, subprocess.SubprocessError):
                return "", ""
            desktop_id = (
                value if value.endswith(".desktop")
                else _BROWSER_DESKTOP_IDS.get(value, "")
            )
        target_id = f"application:{desktop_id}" if desktop_id else ""
        key = value or desktop_id.removesuffix(".desktop")
        name = _BROWSER_DISPLAY_NAMES.get(key, "")
        if not name and target_id:
            application = applications_by_id.get(target_id)
            name = application.title if application is not None else ""
        if not name and desktop_id:
            name = desktop_id.removesuffix(".desktop").replace("-", " ").title()
        return name, target_id

    @staticmethod
    def _is_browser_action(action: ShortcutAction) -> bool:
        if action.action_kind != "exec":
            return False
        try:
            command = shlex.split(action.action_argument, posix=True)
        except ValueError:
            return False
        return bool(command and Path(command[0]).name == "omarchy-launch-browser")

    @staticmethod
    def _is_plain_browser_action(action: ShortcutAction) -> bool:
        if action.action_kind != "exec":
            return False
        try:
            command = shlex.split(action.action_argument, posix=True)
        except ValueError:
            return False
        return len(command) == 1 and Path(command[0]).name == "omarchy-launch-browser"

    @staticmethod
    def _is_editor_action(action: ShortcutAction) -> bool:
        if action.action_kind != "exec":
            return False
        try:
            command = shlex.split(action.action_argument, posix=True)
        except ValueError:
            return False
        return bool(command and Path(command[0]).name == "omarchy-launch-editor")

    @staticmethod
    def _is_plain_editor_action(action: ShortcutAction) -> bool:
        if action.action_kind != "exec":
            return False
        try:
            command = shlex.split(action.action_argument, posix=True)
        except ValueError:
            return False
        return len(command) == 1 and Path(command[0]).name == "omarchy-launch-editor"

    def _default_editor_details(
        self, applications_by_executable: dict[str, catalog.CatalogItem]
    ) -> tuple[str, str, str]:
        try:
            value = str(self.runner(("omarchy-default-editor",)) or "").strip()
        except (OSError, subprocess.SubprocessError):
            return "", "", ""
        executable = Path(value).name
        if not executable:
            return "", "", ""
        application = applications_by_executable.get(executable)
        name = (
            application.title if application is not None
            else _EDITOR_DISPLAY_NAMES.get(executable, executable)
        )
        editor_slug = re.sub(
            r"[^a-z0-9]+", "-", executable.casefold()
        ).strip("-")
        target_id = (
            application.target_id if application is not None
            else f"editor:{editor_slug}" if editor_slug
            else ""
        )
        display_kind = (
            application.launch_kind if application is not None
            else "cmd" if executable in _TERMINAL_EDITORS
            else "desktopApp"
        )
        return name, target_id, display_kind

    @staticmethod
    def _opens_system_ui(action: ShortcutAction) -> bool:
        """Return whether an exec opens an interactive desktop surface.

        Classification follows executable shapes instead of translated labels so
        newly discovered bindings inherit the same rule. Direct state changes,
        print-only helpers, and malformed near-matches intentionally stay actions.
        """
        if action.action_kind != "exec":
            return False
        try:
            command = shlex.split(action.action_argument, posix=True)
        except ValueError:
            return False
        if not command:
            return False

        launcher = Path(command[0]).name
        arguments = command[1:]
        print_only_flags = {"--help", "-h", "--print", "-p"}

        if launcher == "omarchy-shell":
            shell_surface = (
                len(command) >= 4
                and command[1] == "shell"
                and command[2] in {"toggle", "summon"}
                and bool(command[3])
                and not command[3].startswith("-")
            )
            notification_surface = (
                len(command) >= 3
                and command[1] == "notifications"
                and command[2] == "showHistory"
            )
            return shell_surface or notification_surface

        if launcher == "omarchy-menu":
            verb = arguments[0] if arguments else "toggle"
            return verb in {"toggle", "summon"}

        if launcher.startswith("omarchy-menu-"):
            return not any(argument in print_only_flags for argument in arguments)

        if launcher == "omarchy-toggle-bar":
            return len(arguments) <= 1 and (
                not arguments or arguments[0] in {"toggle", "on", "off"}
            )

        if launcher == "omarchy-capture-text":
            return not arguments

        if launcher == "omarchy-reminder":
            return bool(arguments and arguments[0] in {"-i", "--interactive"})

        if launcher == "omarchy-transcode":
            positional_count = 0
            index = 0
            while index < len(arguments):
                argument = arguments[index]
                if argument in {"--help", "-h"}:
                    return False
                if argument == "--path":
                    if index + 1 >= len(arguments):
                        return False
                    index += 2
                    continue
                if argument == "--":
                    positional_count += len(arguments) - index - 1
                    break
                if argument.startswith("-"):
                    return False
                positional_count += 1
                index += 1
            return positional_count < 3

        command_starts = {0}
        shell_operators = {"&&", "||", ";", "|"}
        for index, token in enumerate(command[:-1]):
            if token in shell_operators:
                command_starts.add(index + 1)
        return any(
            Path(command[index]).name in {"hyprpicker", "slurp"}
            for index in command_starts
        )

    @staticmethod
    def _opens_terminal(action: ShortcutAction) -> bool:
        if action.action_kind != "exec":
            return False
        try:
            command = shlex.split(action.action_argument, posix=True)
        except ValueError:
            return False
        if not command:
            return False
        launcher = Path(command[0]).name
        return (
            launcher == "xdg-terminal-exec"
            or launcher == "omarchy-launch-tui"
            or launcher == "omarchy-launch-or-focus-tui"
            or launcher == "omarchy-launch-floating-terminal-with-presentation"
            or launcher.startswith("omarchy-launch-terminal")
        )

    @classmethod
    def _application_executable_candidates(
        cls, action: ShortcutAction, *, depth: int = 0
    ) -> tuple[str, ...]:
        """Extract app executables only from supported native launch shapes."""
        if action.action_kind != "exec" or depth > 3:
            return ()
        try:
            command = shlex.split(action.action_argument, posix=True)
        except ValueError:
            return ()
        if not command:
            return ()
        launcher = Path(command[0]).name
        if launcher == "uwsm-app":
            try:
                separator = command.index("--")
            except ValueError:
                return ()
            if separator + 1 >= len(command):
                return ()
            return (Path(command[separator + 1]).name,)
        if launcher == "omarchy-launch-or-focus":
            if len(command) < 3:
                return ()
            nested = replace(action, action_argument=command[2])
            return cls._application_executable_candidates(nested, depth=depth + 1)
        prefix = "omarchy-launch-"
        if not launcher.startswith(prefix):
            return (launcher,) if len(command) == 1 else ()
        candidate = launcher[len(prefix):]
        while candidate.endswith("-cwd"):
            candidate = candidate[:-4]
        blocked = {
            "browser", "editor", "or-focus", "or-focus-tui", "tui",
            "webapp", "or-focus-webapp", "floating-terminal-with-presentation",
        }
        if not candidate or candidate in blocked or candidate.startswith("terminal"):
            return ()
        return (candidate, candidate + "-desktop")

    def _application_for_action(
        self,
        action: ShortcutAction,
        applications_by_executable: dict[str, catalog.CatalogItem],
    ) -> catalog.CatalogItem | None:
        for executable in self._application_executable_candidates(action):
            application = applications_by_executable.get(executable)
            if application is not None:
                return application
        return None

    def _action_target_id(
        self,
        item: _CatalogAction,
        selection_kind: str,
        selection_id: str,
        agent_name: str,
        browser_target_id: str,
        editor_target_id: str,
        application_target_id: str,
    ) -> str:
        webapp_id = catalog.webapp_target_id(item.action.action_argument)
        if webapp_id:
            return webapp_id
        if selection_kind == "application" and application_target_id:
            return application_target_id
        if selection_kind in {"application", "command"} and selection_id:
            return selection_id
        if agent_name and self._is_agent_action(item.action):
            return "agent:" + re.sub(r"[^a-z0-9]+", "-", agent_name.casefold()).strip("-")
        if browser_target_id and self._is_plain_browser_action(item.action):
            return browser_target_id
        if editor_target_id and self._is_plain_editor_action(item.action):
            return editor_target_id
        if application_target_id:
            return application_target_id
        return f"action:{item.id}"

    @contextmanager
    def _locked(self):
        directory_descriptor = self._open_directory(self.lock_path.parent, create=True)
        lock_descriptor = -1
        try:
            lock_descriptor = os.open(
                self.lock_path.name,
                os.O_RDWR | os.O_CREAT | os.O_CLOEXEC | os.O_NOFOLLOW,
                0o600,
                dir_fd=directory_descriptor,
            )
            info = os.fstat(lock_descriptor)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
                raise ShortcutValidationError("shortcut lock is not a user-owned regular file")
            os.fchmod(lock_descriptor, 0o600)
            fcntl.flock(lock_descriptor, fcntl.LOCK_EX)
            yield
        finally:
            if lock_descriptor >= 0:
                os.close(lock_descriptor)
            os.close(directory_descriptor)

    @staticmethod
    def _snapshot_name(directory_descriptor: int, name: str) -> _FileSnapshot | None:
        try:
            descriptor = os.open(
                name,
                os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW,
                dir_fd=directory_descriptor,
            )
        except FileNotFoundError:
            return None
        try:
            info = os.fstat(descriptor)
            if not stat.S_ISREG(info.st_mode):
                raise ShortcutValidationError("managed shortcut module is not a regular file")
            if info.st_uid != os.getuid():
                raise ShortcutValidationError("managed shortcut module is not owned by the user")
            chunks = []
            while True:
                chunk = os.read(descriptor, 65536)
                if not chunk:
                    break
                chunks.append(chunk)
            return _FileSnapshot(
                data=b"".join(chunks),
                device=info.st_dev,
                inode=info.st_ino,
                mode=stat.S_IMODE(info.st_mode),
                uid=info.st_uid,
                gid=info.st_gid,
            )
        finally:
            os.close(descriptor)

    @staticmethod
    def _same_file(first: _FileSnapshot | None, second: _FileSnapshot | None) -> bool:
        return first == second

    def _read_state(self) -> tuple[ManagedShortcutState, _FileSnapshot | None]:
        directory_descriptor = self._open_directory(self.path.parent, create=True)
        try:
            snapshot = self._snapshot_name(directory_descriptor, self.path.name)
        finally:
            os.close(directory_descriptor)
        if snapshot is None:
            return ManagedShortcutState.empty(), None
        if snapshot.mode != 0o600:
            raise ShortcutValidationError("managed shortcut module mode must be 0600")
        return ManagedShortcutState.from_bytes(snapshot.data), snapshot

    @staticmethod
    def _reset_journal_document(
        shortcut_data: bytes | None,
        settings_path: Path,
        settings_snapshot: settings_store.SettingsFileSnapshot,
    ) -> dict[str, Any]:
        return {
            "version": 1,
            "settingsPath": str(settings_path.resolve(strict=False)),
            "shortcutData": (
                base64.b64encode(shortcut_data).decode("ascii")
                if shortcut_data is not None
                else None
            ),
            "settingsData": (
                base64.b64encode(settings_snapshot.data).decode("ascii")
                if settings_snapshot.data is not None
                else None
            ),
            "settingsMode": settings_snapshot.mode,
        }

    @staticmethod
    def _reset_journal_bytes(document: dict[str, Any]) -> bytes:
        return (
            json.dumps(
                document,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            )
            + "\n"
        ).encode("utf-8")

    def _write_reset_journal(
        self,
        shortcut_snapshot: _FileSnapshot | None,
        settings_path: Path,
        settings_snapshot: settings_store.SettingsFileSnapshot,
    ) -> None:
        document = self._reset_journal_document(
            shortcut_snapshot.data if shortcut_snapshot is not None else None,
            settings_path,
            settings_snapshot,
        )
        data = self._reset_journal_bytes(document)
        directory_descriptor = self._open_directory(
            self.reset_journal_path.parent,
            create=True,
        )
        temporary_name = ""
        try:
            if self._snapshot_name(
                directory_descriptor,
                self.reset_journal_path.name,
            ) is not None:
                raise ShortcutMutationError(
                    "an interrupted reset-all transaction requires recovery"
                )
            temporary_name, _ = self._create_candidate(directory_descriptor, data)
            try:
                os.link(
                    temporary_name,
                    self.reset_journal_path.name,
                    src_dir_fd=directory_descriptor,
                    dst_dir_fd=directory_descriptor,
                    follow_symlinks=False,
                )
            except FileExistsError as error:
                raise ShortcutMutationError(
                    "an interrupted reset-all transaction appeared concurrently"
                ) from error
            os.fsync(directory_descriptor)
            os.unlink(temporary_name, dir_fd=directory_descriptor)
            temporary_name = ""
            os.fsync(directory_descriptor)
        finally:
            if temporary_name:
                try:
                    os.unlink(temporary_name, dir_fd=directory_descriptor)
                    os.fsync(directory_descriptor)
                except OSError:
                    pass
            os.close(directory_descriptor)

    def _read_reset_journal(
        self,
        settings_path: Path,
    ) -> tuple[ManagedShortcutState, settings_store.SettingsFileSnapshot] | None:
        directory_descriptor = self._open_directory(
            self.reset_journal_path.parent,
            create=False,
        )
        try:
            snapshot = self._snapshot_name(
                directory_descriptor,
                self.reset_journal_path.name,
            )
        finally:
            os.close(directory_descriptor)
        if snapshot is None:
            return None
        if snapshot.mode != 0o600 or snapshot.uid != os.getuid():
            raise ShortcutValidationError("reset-all journal must be user-owned mode 0600")
        try:
            document = json.loads(snapshot.data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise ShortcutValidationError("reset-all journal is not valid JSON") from error
        names = {
            "version",
            "settingsPath",
            "shortcutData",
            "settingsData",
            "settingsMode",
        }
        if (
            not isinstance(document, dict)
            or set(document) != names
            or document["version"] != 1
            or document["settingsPath"]
            != str(settings_path.resolve(strict=False))
            or not isinstance(document["settingsPath"], str)
        ):
            raise ShortcutValidationError("reset-all journal has an invalid schema")
        if snapshot.data != self._reset_journal_bytes(document):
            raise ShortcutValidationError("reset-all journal is not canonical")

        def decode_optional(name: str) -> bytes | None:
            value = document[name]
            if value is None:
                return None
            if not isinstance(value, str):
                raise ShortcutValidationError("reset-all journal data is invalid")
            try:
                return base64.b64decode(value, validate=True)
            except (ValueError, binascii.Error) as error:
                raise ShortcutValidationError(
                    "reset-all journal data is invalid"
                ) from error

        shortcut_data = decode_optional("shortcutData")
        settings_data = decode_optional("settingsData")
        settings_mode = document["settingsMode"]
        if settings_data is None:
            if settings_mode is not None:
                raise ShortcutValidationError("reset-all journal settings mode is invalid")
        elif (
            not isinstance(settings_mode, int)
            or isinstance(settings_mode, bool)
            or not 0 <= settings_mode <= 0o777
        ):
            raise ShortcutValidationError("reset-all journal settings mode is invalid")
        prior_state = (
            ManagedShortcutState.empty()
            if shortcut_data is None
            else ManagedShortcutState.from_bytes(shortcut_data)
        )
        return prior_state, settings_store.SettingsFileSnapshot(
            settings_data,
            settings_mode,
        )

    def _discard_reset_journal(self) -> None:
        if not self.reset_journal_path.exists():
            return
        directory_descriptor = self._open_directory(
            self.reset_journal_path.parent,
            create=False,
        )
        try:
            os.unlink(self.reset_journal_path.name, dir_fd=directory_descriptor)
            os.fsync(directory_descriptor)
        except FileNotFoundError:
            pass
        finally:
            os.close(directory_descriptor)

    def recover_reset_transaction(self, settings_path: str | Path) -> bool:
        """Rollback a durable, interrupted reset-all before serving new commands."""
        if not self.reset_journal_path.exists():
            return False
        resolved_settings_path = Path(settings_path)
        with self._locked():
            journal = self._read_reset_journal(resolved_settings_path)
            if journal is None:
                return False
            prior_state, settings_snapshot = journal
            current_state, current_snapshot = self._read_state()
            if current_state != prior_state:
                if current_state != ManagedShortcutState.empty():
                    raise ShortcutMutationError(
                        "managed shortcuts changed after interrupted reset-all"
                    )
                self._preflight_config()
                self._publish_state(
                    current_state,
                    prior_state,
                    current_snapshot,
                )
            settings_store.restore_file_snapshot(
                resolved_settings_path,
                settings_snapshot,
            )
            self._discard_reset_journal()
            return True

    @staticmethod
    def _write_all(descriptor: int, data: bytes) -> None:
        view = memoryview(data)
        while view:
            written = os.write(descriptor, view)
            if written <= 0:
                raise OSError("short write while staging managed shortcuts")
            view = view[written:]

    def _create_candidate(
        self, directory_descriptor: int, data: bytes
    ) -> tuple[str, _FileSnapshot]:
        for _ in range(32):
            name = f".{self.path.name}.{secrets.token_hex(16)}.tmp"
            try:
                descriptor = os.open(
                    name,
                    os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC | os.O_NOFOLLOW,
                    0o600,
                    dir_fd=directory_descriptor,
                )
            except FileExistsError:
                continue
            try:
                self._write_all(descriptor, data)
                os.fchmod(descriptor, 0o600)
                os.fsync(descriptor)
            finally:
                os.close(descriptor)
            snapshot = self._snapshot_name(directory_descriptor, name)
            if snapshot is None or snapshot.data != data or snapshot.mode != 0o600:
                os.unlink(name, dir_fd=directory_descriptor)
                raise ShortcutMutationError("staged shortcut module verification failed")
            return name, snapshot
        raise ShortcutMutationError("could not reserve a shortcut staging file")

    def _exchange_names(
        self, directory_descriptor: int, first: str, second: str
    ) -> None:
        libc = ctypes.CDLL(None, use_errno=True)
        renameat2 = getattr(libc, "renameat2", None)
        if renameat2 is None:
            raise ShortcutMutationError("renameat2 is unavailable on this system")
        renameat2.argtypes = (
            ctypes.c_int,
            ctypes.c_char_p,
            ctypes.c_int,
            ctypes.c_char_p,
            ctypes.c_uint,
        )
        renameat2.restype = ctypes.c_int
        result = renameat2(
            directory_descriptor,
            os.fsencode(first),
            directory_descriptor,
            os.fsencode(second),
            self._RENAME_EXCHANGE,
        )
        if result != 0:
            error_number = ctypes.get_errno()
            raise OSError(error_number, os.strerror(error_number))

    def _config_errors(self) -> str:
        try:
            return str(self.runner(("hyprctl", "configerrors")) or "").strip()
        except (OSError, subprocess.SubprocessError) as error:
            raise ShortcutMutationError(f"cannot query Hyprland config errors: {error}") from error

    def _reload_and_validate(self) -> None:
        try:
            self.runner(("hyprctl", "reload"))
        except (OSError, subprocess.SubprocessError) as error:
            raise ShortcutMutationError(f"Hyprland reload failed: {error}") from error
        errors = self._config_errors()
        if errors:
            raise ShortcutMutationError(f"Hyprland reported configuration errors: {errors}")

    def _rollback_publication(
        self,
        directory_descriptor: int,
        temporary_name: str,
        candidate: _FileSnapshot,
        previous: _FileSnapshot | None,
        previous_state: ManagedShortcutState,
        candidate_state: ManagedShortcutState,
    ) -> None:
        live = self._snapshot_name(directory_descriptor, self.path.name)
        if not self._same_file(live, candidate):
            raise ShortcutMutationError("managed shortcut module changed externally")
        if previous is None:
            os.unlink(self.path.name, dir_fd=directory_descriptor)
        else:
            self._exchange_names(directory_descriptor, temporary_name, self.path.name)
            restored = self._snapshot_name(directory_descriptor, self.path.name)
            if not self._same_file(restored, previous):
                raise ShortcutMutationError("prior shortcut module could not be restored exactly")
        os.fsync(directory_descriptor)
        self._reload_and_validate()
        restored_active, restored_runtime, _ = self._load_catalog_snapshot()
        self._assert_runtime_transition(
            candidate_state,
            previous_state,
            restored_runtime,
            restored_active,
        )

    def _preserve_recovery(
        self,
        directory_descriptor: int,
        temporary_name: str,
    ) -> str:
        """Give a displaced snapshot a durable, user-visible recovery name."""
        source = self._snapshot_name(directory_descriptor, temporary_name)
        if source is None:
            raise ShortcutMutationError("shortcut recovery source disappeared")
        recovery_directory = self.lock_path.parent / "recovery"
        recovery_descriptor = self._open_directory(
            recovery_directory,
            create=True,
        )
        recovery_name = ""
        recovery_committed = False
        try:
            for _ in range(32):
                recovery_name = f"shortcut-recovery-{secrets.token_hex(8)}.state"
                try:
                    destination = os.open(
                        recovery_name,
                        os.O_WRONLY
                        | os.O_CREAT
                        | os.O_EXCL
                        | os.O_CLOEXEC
                        | os.O_NOFOLLOW,
                        0o600,
                        dir_fd=recovery_descriptor,
                    )
                except FileExistsError:
                    recovery_name = ""
                    continue
                try:
                    self._write_all(destination, source.data)
                    os.fchmod(destination, 0o600)
                    os.fsync(destination)
                finally:
                    os.close(destination)
                recovered = self._snapshot_name(
                    recovery_descriptor,
                    recovery_name,
                )
                if (
                    recovered is None
                    or recovered.data != source.data
                    or recovered.mode != 0o600
                    or recovered.uid != os.getuid()
                ):
                    raise ShortcutMutationError(
                        "shortcut recovery copy verification failed"
                    )
                os.fsync(recovery_descriptor)
                recovery_committed = True
                break
            if not recovery_committed:
                raise ShortcutMutationError(
                    "could not reserve a shortcut recovery file"
                )
        finally:
            if recovery_name and not recovery_committed:
                try:
                    os.unlink(recovery_name, dir_fd=recovery_descriptor)
                    os.fsync(recovery_descriptor)
                except OSError:
                    pass
            os.close(recovery_descriptor)

        try:
            os.unlink(temporary_name, dir_fd=directory_descriptor)
            os.fsync(directory_descriptor)
        except OSError:
            # The recovery copy is already durable. The ignored .tmp source may
            # remain, but it is outside Omarchy's *.lua module match.
            pass
        return str(recovery_directory / recovery_name)

    def _publish_state(
        self,
        previous_state: ManagedShortcutState,
        candidate_state: ManagedShortcutState,
        expected: _FileSnapshot | None,
        commit_companion: Callable[[], None] | None = None,
    ) -> tuple[list[bindings.Binding], list[bindings.RuntimeBinding], str]:
        candidate_bytes = candidate_state.to_bytes()
        directory_descriptor = self._open_directory(self.path.parent, create=True)
        temporary_name = ""
        published = False
        preserve_temporary = False
        try:
            observed = self._snapshot_name(directory_descriptor, self.path.name)
            if not self._same_file(observed, expected):
                raise ShortcutMutationError("managed shortcut module changed concurrently")
            temporary_name, candidate = self._create_candidate(
                directory_descriptor, candidate_bytes
            )
            if observed is None:
                try:
                    os.link(
                        temporary_name,
                        self.path.name,
                        src_dir_fd=directory_descriptor,
                        dst_dir_fd=directory_descriptor,
                        follow_symlinks=False,
                    )
                except FileExistsError as error:
                    raise ShortcutMutationError(
                        "managed shortcut module appeared concurrently"
                    ) from error
            else:
                self._exchange_names(
                    directory_descriptor, temporary_name, self.path.name
                )
                displaced = self._snapshot_name(directory_descriptor, temporary_name)
                if not self._same_file(displaced, observed):
                    self._exchange_names(
                        directory_descriptor, temporary_name, self.path.name
                    )
                    raise ShortcutMutationError(
                        "managed shortcut module changed concurrently"
                    )
            published = True
            try:
                os.fsync(directory_descriptor)
                live = self._snapshot_name(directory_descriptor, self.path.name)
                if not self._same_file(live, candidate):
                    raise ShortcutMutationError(
                        "published shortcut module changed before reload"
                    )
                self._reload_and_validate()
                confirmed_active, confirmed_runtime, discovery_error = (
                    self._load_catalog_snapshot()
                )
                self._assert_runtime_transition(
                    previous_state,
                    candidate_state,
                    confirmed_runtime,
                    confirmed_active,
                )
                final = self._snapshot_name(directory_descriptor, self.path.name)
                if not self._same_file(final, candidate):
                    raise ShortcutMutationError(
                        "published shortcut module changed externally after reload"
                    )
                if commit_companion is not None:
                    commit_companion()
            except Exception as error:
                live = self._snapshot_name(directory_descriptor, self.path.name)
                if not self._same_file(live, candidate):
                    try:
                        recovery_name = self._preserve_recovery(
                            directory_descriptor,
                            temporary_name,
                        )
                        temporary_name = ""
                    except Exception as recovery_error:
                        preserve_temporary = True
                        raise ShortcutMutationError(
                            f"{error}; managed shortcut module changed externally; "
                            f"recovery copy remains at {temporary_name}: {recovery_error}"
                        ) from recovery_error
                    raise ShortcutMutationError(
                        f"{error}; managed shortcut module changed externally; "
                        f"recovery copy preserved at {recovery_name}"
                    ) from error
                try:
                    self._rollback_publication(
                        directory_descriptor,
                        temporary_name,
                        candidate,
                        observed,
                        previous_state,
                        candidate_state,
                    )
                except Exception as rollback_error:
                    try:
                        recovery_name = self._preserve_recovery(
                            directory_descriptor,
                            temporary_name,
                        )
                        temporary_name = ""
                        recovery_detail = f"; recovery copy preserved at {recovery_name}"
                    except Exception as recovery_error:
                        preserve_temporary = True
                        recovery_detail = (
                            f"; recovery copy remains at {temporary_name}: {recovery_error}"
                        )
                    raise ShortcutMutationError(
                        f"{error}; rollback failed: {rollback_error}{recovery_detail}"
                    ) from rollback_error
                raise ShortcutMutationError(f"{error}; change was rolled back") from error
            try:
                os.unlink(temporary_name, dir_fd=directory_descriptor)
                temporary_name = ""
                os.fsync(directory_descriptor)
            except OSError:
                # The live candidate was already synced and reload-validated. A
                # failed cleanup sync can at worst resurrect an ignored temp name.
                pass
            return confirmed_active, confirmed_runtime, discovery_error
        finally:
            if temporary_name and not preserve_temporary:
                try:
                    temporary = self._snapshot_name(directory_descriptor, temporary_name)
                    live = self._snapshot_name(directory_descriptor, self.path.name)
                    if not published or not self._same_file(temporary, live):
                        os.unlink(temporary_name, dir_fd=directory_descriptor)
                        os.fsync(directory_descriptor)
                except (FileNotFoundError, ShortcutValidationError, OSError):
                    pass
            os.close(directory_descriptor)

    @staticmethod
    def _request_object(value: object, keys: set[str]) -> dict[str, Any]:
        if not isinstance(value, dict) or set(value) != keys:
            raise ShortcutValidationError("shortcut request keys do not match operation")
        return value

    @staticmethod
    def _request_action(
        value: dict[str, Any], *, description: str, action_kind: str, action_argument: str
    ) -> ShortcutAction:
        raw_modifiers = value["modifiers"]
        if not isinstance(raw_modifiers, list) or not all(
            isinstance(modifier, str) for modifier in raw_modifiers
        ):
            raise ShortcutValidationError("shortcut modifiers must be a list of strings")
        raw_key = value["key"]
        if not isinstance(raw_key, str):
            raise ShortcutValidationError("shortcut key must be a string")
        key = bindings.canonical_key(raw_key)
        return ShortcutAction(
            modifiers=tuple(modifier.upper() for modifier in raw_modifiers),
            key=key,
            description=description,
            action_kind=action_kind,
            action_argument=action_argument,
        )

    @classmethod
    def _request_source_action(cls, value: object) -> ShortcutAction:
        source = cls._request_object(
            value,
            {"modifiers", "key", "description", "dispatcher", "command"},
        )
        description = source["description"]
        dispatcher = source["dispatcher"]
        command = source["command"]
        if (
            not isinstance(description, str)
            or dispatcher != "exec"
            or not isinstance(command, str)
        ):
            raise ShortcutValidationError("shortcut source is not an editable exec binding")
        return cls._request_action(
            source,
            description=description,
            action_kind="exec",
            action_argument=command,
        )

    @staticmethod
    def _binding_action(binding: bindings.Binding) -> ShortcutAction:
        if (
            not binding.editable
            or binding.action_kind not in {"exec", "lua"}
            or binding.action_argument is None
        ):
            raise ShortcutConflictError("source binding is not safely editable")
        return ShortcutAction(
            modifiers=binding.modifiers,
            key=bindings.canonical_key(binding.key),
            description=binding.description,
            action_kind=binding.action_kind,
            action_argument=binding.action_argument,
        )

    @staticmethod
    def _keycode_from_physical_key(key: str) -> int | None:
        if not key.startswith("code:"):
            return None
        try:
            return int(key.split(":", 1)[1])
        except ValueError as error:
            raise ShortcutConflictError(
                f"cannot resolve runtime physical key {key}"
            ) from error

    def _keyboard_option(self, name: str) -> str:
        try:
            raw = self.runner(("hyprctl", "getoption", f"input:{name}", "-j"))
            document = json.loads(raw, object_pairs_hook=_json_object)
        except (
            OSError,
            subprocess.SubprocessError,
            UnicodeError,
            ValueError,
            json.JSONDecodeError,
        ) as error:
            raise ShortcutConflictError(
                f"cannot read Hyprland keyboard option {name}"
            ) from error
        value = document.get("str") if isinstance(document, dict) else None
        if (
            not isinstance(value, str)
            or len(value) > 1024
            or _has_control(value)
        ):
            raise ShortcutConflictError(
                f"Hyprland keyboard option {name} is invalid"
            )
        return value.strip()

    def _load_keycode_symbols(self) -> dict[int, str | None]:
        rules = self._keyboard_option("kb_rules")
        model = self._keyboard_option("kb_model")
        layouts = self._keyboard_option("kb_layout")
        variants = self._keyboard_option("kb_variant")
        options = self._keyboard_option("kb_options")
        layout = layouts.split(",", 1)[0].strip()
        variant = variants.split(",", 1)[0].strip()
        if not layout:
            raise ShortcutConflictError("Hyprland keyboard layout is empty")

        command = ["xkbcli", "compile-keymap"]
        for flag, value in (
            ("--rules", rules),
            ("--model", model),
            ("--layout", layout),
            ("--variant", variant),
            ("--options", options),
        ):
            if value:
                command.extend((flag, value))
        try:
            keymap = self.runner(tuple(command))
            return _xkb_keycode_symbols(keymap)
        except (OSError, subprocess.SubprocessError, UnicodeError, ValueError) as error:
            raise ShortcutConflictError(
                "cannot compile the configured XKB keyboard layout"
            ) from error

    def _resolved_keycode_symbols(self) -> dict[int, str | None]:
        if self._keycode_symbols is None:
            self._keycode_symbols = self._load_keycode_symbols()
        return self._keycode_symbols

    def _refresh_keycode_symbols(self) -> None:
        if not self._keycode_symbols_injected:
            self._keycode_symbols = None

    def _load_runtime_bindings(self) -> list[bindings.RuntimeBinding]:
        self._refresh_keycode_symbols()
        return bindings.load_runtime_bindings(self.runner)

    def _load_active_bindings(self) -> tuple[list[bindings.Binding], str]:
        discovery_error = ""

        def capture_discovery(command: tuple[str, ...]) -> str:
            nonlocal discovery_error
            try:
                return self.runner(command)
            except (OSError, subprocess.SubprocessError) as error:
                if command == _SOURCE_RECORD_COMMAND:
                    discovery_error = f"Shortcut action discovery failed: {error}"
                raise

        return bindings.load_active_bindings(capture_discovery), discovery_error

    def _load_binding_snapshot(
        self,
    ) -> tuple[list[bindings.Binding], list[bindings.RuntimeBinding]]:
        self._refresh_keycode_symbols()
        active, _ = self._load_active_bindings()
        return (
            active,
            bindings.load_runtime_bindings(self.runner),
        )

    def _load_catalog_snapshot(
        self,
    ) -> tuple[list[bindings.Binding], list[bindings.RuntimeBinding], str]:
        self._refresh_keycode_symbols()
        menu_text = self.runner(("omarchy", "menu", "keybindings", "--print"))
        before_text = self.runner(("hyprctl", "binds"))
        discovery_error = ""
        try:
            source_records_text = self.runner(_SOURCE_RECORD_COMMAND)
        except (OSError, subprocess.SubprocessError) as error:
            discovery_error = f"Shortcut action discovery failed: {error}"
            source_records_text = ""
        active = bindings.parse(menu_text, before_text, source_records_text)
        before_runtime = bindings.parse_runtime_bindings(before_text)
        after_runtime = self._load_runtime_bindings()
        if before_runtime != after_runtime:
            raise ShortcutConflictError(
                "shortcut runtime changed during discovery; selection is stale"
            )
        return active, after_runtime, discovery_error

    def _resolved_runtime_key(self, runtime: bindings.RuntimeBinding) -> str:
        keycode = self._keycode_from_physical_key(runtime.key)
        if keycode is None:
            return runtime.key
        symbols = self._resolved_keycode_symbols()
        if keycode not in symbols:
            label = runtime.description or "undescribed binding"
            raise ShortcutConflictError(
                f"cannot resolve runtime physical key {runtime.key} for {label}"
            )
        symbol = symbols[keycode]
        if symbol is None:
            return runtime.key
        if not isinstance(symbol, str) or not symbol:
            label = runtime.description or "undescribed binding"
            raise ShortcutConflictError(
                f"cannot resolve runtime physical key {runtime.key} for {label}"
            )
        resolved = bindings.canonical_key(symbol)
        if resolved not in _SUPPORTED_KEYS:
            label = runtime.description or "undescribed binding"
            raise ShortcutConflictError(
                f"cannot resolve runtime physical key {runtime.key} for {label}: "
                f"{symbol} is not a supported shortcut key"
            )
        return resolved

    def _runtime_chord(
        self, runtime: bindings.RuntimeBinding
    ) -> tuple[tuple[str, ...], str]:
        return runtime.modifiers, self._resolved_runtime_key(runtime)

    def _runtime_collision_message(
        self, runtime: bindings.RuntimeBinding, resolved_key: str
    ) -> str:
        label = runtime.description or "undescribed binding"
        if runtime.key == resolved_key:
            return f"target shortcut is already active: {label} occupies {resolved_key}"
        return (
            "target shortcut is already active: "
            f"{label} occupies {runtime.key} resolved as {resolved_key}"
        )

    def _occupant(
        self,
        runtime: list[bindings.RuntimeBinding],
        chord: tuple[tuple[str, ...], str],
    ) -> bindings.RuntimeBinding | None:
        for item in runtime:
            if self._runtime_chord(item) == chord:
                return item
        return None

    def _assert_unoccupied(
        self,
        runtime: list[bindings.RuntimeBinding],
        chord: tuple[tuple[str, ...], str],
    ) -> None:
        occupant = self._occupant(runtime, chord)
        if occupant is not None:
            raise ShortcutConflictError(
                self._runtime_collision_message(occupant, chord[1])
            )

    def _runtime_on_chord(
        self,
        runtime: list[bindings.RuntimeBinding],
        chord: tuple[tuple[str, ...], str],
    ) -> list[bindings.RuntimeBinding]:
        return [item for item in runtime if self._runtime_chord(item) == chord]

    def _assert_action_active(
        self,
        active: list[bindings.Binding],
        runtime: list[bindings.RuntimeBinding],
        action: ShortcutAction,
        message: str,
    ) -> None:
        occupants = self._runtime_on_chord(runtime, action.chord)
        if len(occupants) != 1:
            raise ShortcutConflictError(message)
        occupant = occupants[0]
        if (
            not self._runtime_action_matches(occupant, action)
            or not self._normalized_action_matches(active, action)
        ):
            raise ShortcutConflictError(message)

    @staticmethod
    def _runtime_action_matches(
        runtime: bindings.RuntimeBinding, action: ShortcutAction
    ) -> bool:
        if runtime.description != action.description:
            return False
        if action.action_kind == "exec":
            if runtime.dispatcher == "exec":
                return runtime.argument == action.action_argument
            return runtime.dispatcher == "__lua"
        return runtime.dispatcher == "__lua"

    def _normalized_action_matches(
        self,
        active: list[bindings.Binding],
        action: ShortcutAction,
    ) -> bool:
        matches = []
        for item in active:
            chord = item.modifiers, bindings.canonical_key(item.key)
            if chord != action.chord or not item.editable:
                continue
            try:
                matches.append(self._binding_action(item))
            except (ShortcutConflictError, ShortcutValidationError):
                continue
        return matches == [action]

    def _assert_runtime_transition(
        self,
        previous: ManagedShortcutState,
        candidate: ManagedShortcutState,
        runtime: list[bindings.RuntimeBinding],
        active: list[bindings.Binding],
    ) -> None:
        desired = {entry.current.chord: entry.current for entry in candidate.entries}
        for action in desired.values():
            occupants = self._runtime_on_chord(runtime, action.chord)
            if len(occupants) != 1:
                raise ShortcutMutationError(
                    "runtime confirmation found a missing or duplicate managed shortcut"
                )
            occupant = occupants[0]
            if not self._runtime_action_matches(occupant, action):
                raise ShortcutMutationError(
                    "runtime confirmation found different shortcut metadata"
                )
            if not self._normalized_action_matches(active, action):
                raise ShortcutMutationError(
                    "source confirmation found different shortcut metadata"
                )

        candidate_suppressed = self._suppressed_sources(candidate)
        for chord in candidate_suppressed:
            if chord in desired:
                continue
            if self._runtime_on_chord(runtime, chord):
                raise ShortcutMutationError(
                    "runtime confirmation found an original shortcut still active"
                )

        candidate_by_id = {entry.id: entry for entry in candidate.entries}
        released: set[tuple[tuple[str, ...], str]] = set()
        for entry in previous.entries:
            replacement = candidate_by_id.get(entry.id)
            if replacement is not None:
                if replacement.current.chord != entry.current.chord:
                    released.add(entry.current.chord)
                continue
            released.add(entry.current.chord)

        previous_suppressed = self._suppressed_sources(previous)
        candidate_source_ids = {
            record[0] for record in candidate_suppressed.values()
        }
        restored = {
            chord: record
            for chord, record in previous_suppressed.items()
            if record[0] not in candidate_source_ids
        }
        for chord, record in restored.items():
            if chord in desired:
                continue
            source_binding_id, description, original, dispatcher, argument = record
            occupants = self._runtime_on_chord(runtime, chord)
            if len(occupants) != 1:
                raise ShortcutMutationError(
                    "runtime confirmation did not restore the original shortcut"
                )
            occupant = occupants[0]
            active_on_chord = [
                item
                for item in active
                if (item.modifiers, bindings.canonical_key(item.key)) == chord
            ]
            if original is not None:
                restored_exactly = (
                    self._runtime_action_matches(occupant, original)
                    and self._normalized_action_matches(active, original)
                )
            else:
                restored_exactly = (
                    occupant.description == description
                    and occupant.dispatcher == dispatcher
                    and occupant.argument == argument
                    and len(active_on_chord) == 1
                    and active_on_chord[0].id == source_binding_id
                    and active_on_chord[0].description == description
                    and active_on_chord[0].dispatcher == dispatcher
                    and active_on_chord[0].argument == argument
                )
            if not restored_exactly:
                raise ShortcutMutationError(
                    "runtime confirmation restored different shortcut metadata"
                )

        for chord in released:
            if chord in desired or chord in restored:
                continue
            if self._runtime_on_chord(runtime, chord):
                raise ShortcutMutationError(
                    "runtime confirmation found a released shortcut still active"
                )

    @staticmethod
    def _suppressed_sources(
        state: ManagedShortcutState,
    ) -> dict[
        tuple[tuple[str, ...], str],
        tuple[str, str, ShortcutAction | None, str | None, str | None],
    ]:
        result = {
            item.chord: (
                item.source_binding_id,
                item.description,
                item.original,
                item.dispatcher,
                item.argument,
            )
            for item in state.suppressed
        }
        for entry in state.entries:
            if entry.kind != "override" or entry.original is None:
                continue
            result[entry.original.chord] = (
                entry.source_binding_id or "",
                entry.original.description,
                entry.original,
                None,
                None,
            )
        return result

    @staticmethod
    def _entry_for_current(
        state: ManagedShortcutState, action: ShortcutAction
    ) -> ManagedShortcutEntry | None:
        matches = [entry for entry in state.entries if entry.current == action]
        if len(matches) > 1:
            raise ShortcutValidationError("multiple managed entries match one live action")
        return matches[0] if matches else None

    @staticmethod
    def _entry_id(prefix: str, payload: str) -> str:
        return prefix + "-" + hashlib.sha256(payload.encode("utf-8")).hexdigest()[:32]

    @staticmethod
    def _default_action_id(action: ShortcutAction) -> str:
        payload = json.dumps(
            [
                list(action.modifiers),
                action.key,
                action.description,
                action.action_kind,
                action.action_argument,
            ],
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        return "action-" + hashlib.sha256(payload).hexdigest()

    def _catalog_actions(
        self,
        state: ManagedShortcutState,
        active: list[bindings.Binding],
        runtime: list[bindings.RuntimeBinding],
    ) -> list[_CatalogAction]:
        runtime_by_chord: dict[
            tuple[tuple[str, ...], str], list[bindings.RuntimeBinding]
        ] = {}
        for item in runtime:
            chord = self._runtime_chord(item)
            runtime_by_chord.setdefault(chord, []).append(item)
        active_counts: dict[tuple[tuple[str, ...], str], int] = {}
        for item in active:
            chord = item.modifiers, bindings.canonical_key(item.key)
            active_counts[chord] = active_counts.get(chord, 0) + 1

        managed_by_action = {entry.current: entry for entry in state.entries}
        catalog = []
        for item in active:
            chord = item.modifiers, bindings.canonical_key(item.key)
            if (
                len(runtime_by_chord.get(chord, ())) != 1
                or active_counts.get(chord) != 1
                or not item.editable
            ):
                continue
            try:
                action = self._binding_action(item)
            except (ShortcutConflictError, ShortcutValidationError):
                continue
            if not self._runtime_action_matches(runtime_by_chord[chord][0], action):
                continue
            entry = managed_by_action.get(action)
            catalog.append(
                _CatalogAction(
                    id=(entry.id if entry is not None else self._default_action_id(action)),
                    binding=item,
                    action=action,
                    entry=entry,
                )
            )
        return catalog

    def _presentation_bindings(
        self,
        state: ManagedShortcutState,
        active: list[bindings.Binding],
    ) -> list[bindings.Binding]:
        """Attach stable presentation IDs without changing fresh auth identities."""
        managed_by_action = {entry.current: entry for entry in state.entries}
        managed_by_chord = {
            (entry.current.modifiers, bindings.canonical_key(entry.current.key)): entry
            for entry in state.entries
        }
        presented = []
        for item in active:
            presentation_id = item.presentation_id or item.id
            presentation_entry = None
            entry = managed_by_chord.get(
                (item.modifiers, bindings.canonical_key(item.key))
            )
            if entry is not None:
                presentation_entry = entry
                presentation_id = entry.source_binding_id or entry.id
            elif item.editable:
                try:
                    entry = managed_by_action.get(self._binding_action(item))
                except (ShortcutConflictError, ShortcutValidationError):
                    entry = None
                if entry is not None:
                    presentation_entry = entry
                    presentation_id = entry.source_binding_id or entry.id
            if presentation_entry is None:
                selection_kind = ""
                selection_id = ""
                label_key = action_label_key(item.description)
                title_override = ""
            else:
                selection_kind = presentation_entry.selection_kind
                selection_id = presentation_entry.selection_id
                label_key = presentation_entry.label_key
                title_override = presentation_entry.title_override
            presented.append(
                replace(
                    item,
                    presentation_id=presentation_id,
                    selection_kind=selection_kind,
                    selection_id=selection_id,
                    label_key=label_key,
                    title_override=title_override,
                )
            )
        return presented

    def _preflight_config(self) -> None:
        errors = self._config_errors()
        if errors:
            raise ShortcutMutationError(
                f"existing Hyprland configuration errors must be fixed first: {errors}"
            )

    def _status_for(
        self,
        state: ManagedShortcutState,
        runtime: list[bindings.RuntimeBinding],
        active: list[bindings.Binding] | None = None,
        discovery_error: str | None = None,
    ) -> dict[str, Any]:
        if active is None or discovery_error is None:
            active, discovered_error = self._load_active_bindings()
            if discovery_error is None:
                discovery_error = discovered_error
        active = self._presentation_bindings(state, active)

        runtime_by_chord: dict[
            tuple[tuple[str, ...], str], list[bindings.RuntimeBinding]
        ] = {}
        for item in runtime:
            runtime_by_chord.setdefault(self._runtime_chord(item), []).append(item)

        active_by_chord: dict[
            tuple[tuple[str, ...], str], list[bindings.Binding]
        ] = {}
        for item in active:
            chord = item.modifiers, bindings.canonical_key(item.key)
            active_by_chord.setdefault(chord, []).append(item)

        catalog = self._catalog_actions(state, active, runtime)
        catalog_by_chord = {item.action.chord: item for item in catalog}
        applications_by_id, applications_by_executable = (
            self.catalog_discovery.application_index("en")
        )
        default_agent_name = self._default_agent_name()
        default_browser_name, default_browser_target_id = (
            self._default_browser_details(applications_by_id)
            if any(self._is_browser_action(item.action) for item in catalog)
            else ("", "")
        )
        default_editor_name, default_editor_target_id, default_editor_display_kind = (
            self._default_editor_details(applications_by_executable)
            if any(self._is_editor_action(item.action) for item in catalog)
            else ("", "", "")
        )
        def status_action(item: _CatalogAction) -> dict[str, Any]:
            selection_kind = (
                item.entry.selection_kind
                if item.entry is not None and item.entry.selection_kind
                else "action"
            )
            selection_id = (
                item.entry.selection_id
                if item.entry is not None and item.entry.selection_id
                else item.id
            )
            is_agent = bool(default_agent_name and self._is_agent_action(item.action))
            is_browser = bool(
                default_browser_name and self._is_browser_action(item.action)
            )
            is_editor = bool(
                default_editor_name and self._is_editor_action(item.action)
            )
            launch_kind = action_launch_kind(item.action)
            application = None
            if selection_kind == "application" and selection_id:
                application = applications_by_id.get(selection_id)
            if application is None and not launch_kind:
                application = self._application_for_action(
                    item.action, applications_by_executable
                )
            resolved_launch_kind = (
                launch_kind
                or (application.launch_kind if application is not None else "")
            )
            if is_agent:
                display_kind, role_kind, target_name = "cmd", "agent", default_agent_name
            elif is_browser:
                display_kind, role_kind, target_name = (
                    "desktopApp",
                    "browser",
                    default_browser_name
                    if self._is_plain_browser_action(item.action) else "",
                )
            elif is_editor:
                display_kind, role_kind, target_name = (
                    default_editor_display_kind,
                    "editor",
                    default_editor_name
                    if self._is_plain_editor_action(item.action) else "",
                )
            elif launch_kind == "webapp":
                display_kind, role_kind, target_name = "webapp", "", ""
            elif application is not None:
                display_kind, role_kind, target_name = (
                    application.launch_kind,
                    "",
                    application.title,
                )
            elif selection_kind == "command":
                display_kind, role_kind, target_name = "action", "", ""
            elif self._opens_terminal(item.action):
                display_kind, role_kind, target_name = "cmd", "", ""
            elif self._opens_system_ui(item.action):
                display_kind, role_kind, target_name = "systemUi", "", ""
            else:
                display_kind, role_kind, target_name = "action", "", ""
            return {
                "id": item.id,
                "presentationId": item.binding.presentation_id,
                "title": item.action.description,
                "labelKey": (
                    item.entry.label_key
                    if item.entry is not None
                    else action_label_key(item.action.description)
                ),
                "selectionKind": selection_kind,
                "selectionId": selection_id,
                "titleOverride": (
                    item.entry.title_override if item.entry is not None else ""
                ),
                "actionKind": item.action.action_kind,
                "launchKind": resolved_launch_kind,
                "displayKind": display_kind,
                "roleKind": role_kind,
                "targetName": target_name,
                "targetId": self._action_target_id(
                    item,
                    selection_kind,
                    selection_id,
                    default_agent_name,
                    default_browser_target_id,
                    default_editor_target_id,
                    application.target_id if application is not None else "",
                ),
                **(
                    {"agentName": default_agent_name}
                    if default_agent_name and self._is_agent_action(item.action)
                    else {}
                ),
                **(
                    {"browserName": default_browser_name}
                    if default_browser_name and self._is_browser_action(item.action)
                    else {}
                ),
                "modifiers": list(item.action.modifiers),
                "key": item.action.key,
            }

        actions = [status_action(item) for item in catalog]

        key_options: dict[str, list[dict[str, Any]]] = {}
        for group in SUPER_GROUPS:
            modifiers = tuple(group.split("+"))
            options = []
            for key in SUPPORTED_KEYS:
                chord = modifiers, key
                runtime_occupants = runtime_by_chord.get(chord, ())
                if not runtime_occupants:
                    options.append(
                        {
                            "key": key,
                            "state": "free",
                            "title": "",
                            "bindingId": "",
                            "presentationId": "",
                            "actionId": "",
                            "editable": True,
                            "editReason": "",
                            "removable": False,
                            "removeReason": "No shortcut assigned",
                        }
                    )
                    continue

                displayed = active_by_chord.get(chord, ())
                binding = displayed[0] if displayed else None
                catalog_item = catalog_by_chord.get(chord)
                if catalog_item is not None:
                    binding_id = catalog_item.binding.id
                    presentation_id = catalog_item.binding.presentation_id
                    title = catalog_item.action.description
                    editable = True
                    edit_reason = ""
                    action_id = catalog_item.id
                else:
                    binding_id = binding.id if binding is not None else ""
                    presentation_id = (
                        binding.presentation_id if binding is not None else ""
                    )
                    title = (
                        binding.description
                        if binding is not None and binding.description
                        else runtime_occupants[0].description or "Undescribed binding"
                    )
                    editable = False
                    if len(runtime_occupants) != 1 or len(displayed) > 1:
                        edit_reason = "Duplicate chord"
                    elif binding is not None and binding.edit_reason:
                        edit_reason = binding.edit_reason
                    else:
                        edit_reason = "Action cannot be reconstructed"
                    action_id = ""
                if len(runtime_occupants) != 1 or len(displayed) != 1:
                    removable = False
                    remove_reason = "Duplicate chord"
                elif binding is None or not binding.id:
                    removable = False
                    remove_reason = "Binding identity is unavailable"
                elif binding.mouse:
                    removable = False
                    remove_reason = "Mouse shortcuts cannot be removed here"
                elif (
                    self._keycode_from_physical_key(runtime_occupants[0].key)
                    is not None
                ):
                    removable = False
                    remove_reason = "Physical key aliases cannot be removed here"
                elif runtime_occupants[0].description != binding.description:
                    removable = False
                    remove_reason = "Binding metadata is inconsistent"
                elif (
                    not binding.editable
                    and (
                        runtime_occupants[0].dispatcher is None
                        or runtime_occupants[0].argument is None
                    )
                ):
                    removable = False
                    remove_reason = "Binding cannot be restored safely"
                else:
                    removable = True
                    remove_reason = ""
                options.append(
                    {
                        "key": key,
                        "state": "assigned",
                        "title": title,
                        "bindingId": binding_id,
                        "presentationId": presentation_id,
                        "actionId": action_id,
                        "editable": editable,
                        "editReason": edit_reason,
                        "removable": removable,
                        "removeReason": remove_reason,
                    }
                )
            key_options[group] = options

        return {
            "version": 3,
            "managedCount": len(state.entries) + len(state.suppressed),
            "managedBindingIds": [
                bindings.stable_id(
                    entry.current.modifiers,
                    entry.current.key,
                    entry.current.description,
                )
                for entry in state.entries
            ],
            "keyOptionsByGroup": key_options,
            "actions": actions,
            "discoveryError": discovery_error,
        }

    @staticmethod
    def _custom_command(executable: str, arguments: str) -> str:
        if (
            not executable
            or not os.path.isabs(executable)
            or len(executable) > 4096
            or _has_control(executable)
        ):
            raise ShortcutValidationError(
                "custom executable must be an absolute executable path"
            )
        flags = getattr(os, "O_PATH", os.O_RDONLY) | os.O_CLOEXEC | os.O_NOFOLLOW
        try:
            descriptor = os.open(executable, flags)
        except OSError as error:
            raise ShortcutValidationError(
                "custom executable path is not a safe executable"
            ) from error
        try:
            info = os.fstat(descriptor)
            if os.geteuid() == 0:
                executable_by_user = bool(info.st_mode & 0o111)
            elif info.st_uid == os.geteuid():
                executable_by_user = bool(info.st_mode & stat.S_IXUSR)
            elif info.st_gid == os.getegid() or info.st_gid in os.getgroups():
                executable_by_user = bool(info.st_mode & stat.S_IXGRP)
            else:
                executable_by_user = bool(info.st_mode & stat.S_IXOTH)
            if not stat.S_ISREG(info.st_mode) or not executable_by_user:
                raise ShortcutValidationError(
                    "custom executable must be a regular executable file"
                )
        finally:
            os.close(descriptor)

        if len(arguments) > 4096 or _has_control(arguments):
            raise ShortcutValidationError("custom arguments are invalid")
        try:
            argument_values = shlex.split(arguments, posix=True)
        except ValueError as error:
            raise ShortcutValidationError("custom arguments are invalid") from error
        return shlex.join([executable, *argument_values])

    @staticmethod
    def _occupied_assignment_message(
        occupants: list[bindings.RuntimeBinding],
    ) -> str:
        if len(occupants) != 1:
            return "target shortcut is occupied by duplicate actions"
        return (
            "target shortcut is occupied by "
            + (occupants[0].description or "an undescribed binding")
        )

    @classmethod
    def _occupied_assignment_error(
        cls, occupants: list[bindings.RuntimeBinding]
    ) -> ShortcutConflictError:
        title = (
            occupants[0].description or "an undescribed binding"
            if len(occupants) == 1
            else ""
        )
        return ShortcutConflictError(
            cls._occupied_assignment_message(occupants),
            code="shortcut.target_occupied",
            context={"title": title},
        )

    def _assignment_candidate(
        self,
        values: dict[str, Any],
        state: ManagedShortcutState,
        active: list[bindings.Binding],
        runtime: list[bindings.RuntimeBinding],
        custom_command: str | None,
    ) -> ManagedShortcutState:
        catalog = self._catalog_actions(state, active, runtime)
        catalog_by_chord = {item.action.chord: item for item in catalog}
        action_id = values["actionId"]
        target_binding_id = values["targetBindingId"]

        if action_id:
            matches = [item for item in catalog if item.id == action_id]
            if len(matches) != 1:
                raise ShortcutConflictError(
                    "selected action is stale or unavailable",
                    code="catalog.selection_stale",
                    context={"kind": "action"},
                )
            selected = matches[0]
            if values["newContract"]:
                title_override = values["titleOverride"]
                presentation = {
                    "selection_kind": "action",
                    "selection_id": selected.id,
                    "label_key": (
                        selected.entry.label_key
                        if selected.entry is not None and selected.entry.label_key
                        else action_label_key(selected.action.description)
                    ),
                    "title_override": title_override,
                }
                description = title_override or selected.action.description
            else:
                description = values["title"]
                presentation = {
                    "selection_kind": (
                        selected.entry.selection_kind
                        if selected.entry is not None and selected.entry.selection_kind
                        else "action"
                    ),
                    "selection_id": (
                        selected.entry.selection_id
                        if selected.entry is not None and selected.entry.selection_id
                        else selected.id
                    ),
                    "label_key": (
                        selected.entry.label_key
                        if selected.entry is not None and selected.entry.label_key
                        else action_label_key(selected.action.description)
                    ),
                    "title_override": (
                        values["title"]
                        if values["title"] != selected.action.description
                        else (
                            selected.entry.title_override
                            if selected.entry is not None
                            else ""
                        )
                    ),
                }
            target = self._request_action(
                {
                    "modifiers": values["targetModifiers"],
                    "key": values["targetKey"],
                },
                description=description,
                action_kind=selected.action.action_kind,
                action_argument=selected.action.action_argument,
            )
            occupants = self._runtime_on_chord(runtime, target.chord)
            if target.chord != selected.action.chord:
                if occupants:
                    raise self._occupied_assignment_error(occupants)
                if target_binding_id:
                    raise ShortcutConflictError(
                        "target binding identity is stale",
                        code="shortcut.target_stale",
                    )
            elif (
                target_binding_id
                and target_binding_id != selected.binding.id
            ):
                raise ShortcutConflictError(
                    "target binding identity is stale",
                    code="shortcut.target_stale",
                )

            if target == selected.action:
                if selected.entry is None:
                    return state
                updated = replace(selected.entry, **presentation)
                if updated == selected.entry:
                    return state
                return replace(
                    state,
                    entries=tuple(
                        updated if entry is selected.entry else entry
                        for entry in state.entries
                    )
                )
            entries = [
                entry for entry in state.entries if entry is not selected.entry
            ]
            if selected.entry is None:
                entries.append(
                    ManagedShortcutEntry(
                        id=selected.id,
                        kind="override",
                        source_binding_id=selected.binding.id,
                        original=selected.action,
                        current=target,
                        **presentation,
                    )
                )
            elif selected.entry.kind == "new":
                entries.append(
                    ManagedShortcutEntry(
                        id=selected.entry.id,
                        kind="new",
                        source_binding_id=None,
                        original=None,
                        current=target,
                        **presentation,
                    )
                )
            elif (
                selected.entry.original is not None
                and target == selected.entry.original
            ):
                pass
            else:
                entries.append(
                    ManagedShortcutEntry(
                        id=selected.entry.id,
                        kind="override",
                        source_binding_id=selected.entry.source_binding_id,
                        original=selected.entry.original,
                        current=target,
                        **presentation,
                    )
                )
            return replace(state, entries=tuple(entries))

        assert custom_command is not None
        target = self._request_action(
            {
                "modifiers": values["targetModifiers"],
                "key": values["targetKey"],
            },
            description=values["title"],
            action_kind="exec",
            action_argument=custom_command,
        )
        presentation = {
            "selection_kind": values["selectionKind"],
            "selection_id": values["selectionId"],
            "label_key": "",
            "title_override": (
                values["titleOverride"]
                if values["newContract"]
                else values["title"]
            ),
        }
        occupants = self._runtime_on_chord(runtime, target.chord)
        custom_id = self._default_action_id(target)
        if not occupants:
            if target_binding_id:
                raise ShortcutConflictError(
                    "target binding identity is stale",
                    code="shortcut.target_stale",
                )
            if any(entry.current.chord == target.chord for entry in state.entries):
                raise ShortcutConflictError(
                    "managed target shortcut is not active"
                )
            return replace(
                state,
                entries=(
                    *state.entries,
                    ManagedShortcutEntry(
                        id=custom_id,
                        kind="new",
                        source_binding_id=None,
                        original=None,
                        current=target,
                        **presentation,
                    ),
                )
            )

        if len(occupants) != 1:
            raise self._occupied_assignment_error(occupants)
        active_on_target = [
            item
            for item in active
            if (item.modifiers, bindings.canonical_key(item.key)) == target.chord
        ]
        fresh_binding_id = (
            active_on_target[0].id if len(active_on_target) == 1 else ""
        )
        if not target_binding_id or target_binding_id != fresh_binding_id:
            raise ShortcutConflictError(
                "target binding identity is stale",
                code="shortcut.target_stale",
            )
        if values["confirmReplace"] is not True:
            raise ShortcutConflictError(
                "custom replacement requires explicit confirmation",
                code="shortcut.replacement_confirmation_required",
                context={
                    "title": occupants[0].description or "an undescribed binding"
                },
            )
        replaced = catalog_by_chord.get(target.chord)
        if replaced is None:
            reason = (
                active_on_target[0].edit_reason
                if len(active_on_target) == 1
                and active_on_target[0].edit_reason
                else "Action cannot be reconstructed"
            )
            raise ShortcutConflictError(
                f"target binding is unavailable: {reason}"
            )

        entries = [entry for entry in state.entries if entry is not replaced.entry]
        if replaced.entry is None:
            replacement = ManagedShortcutEntry(
                id=custom_id,
                kind="override",
                source_binding_id=replaced.binding.id,
                original=replaced.action,
                current=target,
                **presentation,
            )
        elif replaced.entry.kind == "new":
            replacement = ManagedShortcutEntry(
                id=replaced.entry.id,
                kind="new",
                source_binding_id=None,
                original=None,
                current=target,
                **presentation,
            )
        else:
            replacement = ManagedShortcutEntry(
                id=replaced.entry.id,
                kind="override",
                source_binding_id=replaced.entry.source_binding_id,
                original=replaced.entry.original,
                current=target,
                **presentation,
            )
        entries.append(replacement)
        return replace(state, entries=tuple(entries))

    def _reconciled_application_state(
        self, state: ManagedShortcutState
    ) -> ManagedShortcutState:
        entries: list[ManagedShortcutEntry] = []
        for entry in state.entries:
            current = entry.current
            try:
                command = shlex.split(current.action_argument, posix=True)
            except ValueError:
                command = []
            if (
                entry.selection_kind != "application"
                or current.action_kind != "exec"
                or len(command) < 2
                or Path(command[0]).name != "omarchy-launch-or-focus"
                or command[1] != "omarchy"
            ):
                entries.append(entry)
                continue
            try:
                resolved = self.catalog_discovery.resolve(
                    "application", entry.selection_id
                )
                replacement = self._custom_command(
                    resolved.executable, resolved.arguments
                )
            except (catalog.CatalogError, ShortcutValidationError):
                entries.append(entry)
                continue
            entries.append(
                replace(
                    entry,
                    current=replace(current, action_argument=replacement),
                )
            )
        return replace(state, entries=tuple(entries))

    def reconcile_applications(self) -> dict[str, Any]:
        """Repair legacy shared-router focus patterns without guessing identity."""
        with self._locked():
            state, snapshot = self._read_state()
            candidate = self._reconciled_application_state(state)
            active, runtime, discovery_error = self._load_catalog_snapshot()
            if candidate == state:
                return self._status_for(
                    state, runtime, active, discovery_error
                )

            changed_ids = {
                previous.id
                for previous, updated in zip(state.entries, candidate.entries)
                if previous != updated
            }
            for entry in state.entries:
                if entry.id in changed_ids:
                    self._assert_action_active(
                        active,
                        runtime,
                        entry.current,
                        "managed application shortcut changed before repair",
                    )
            self._preflight_config()

            latest_state, latest_snapshot = self._read_state()
            if not self._same_file(snapshot, latest_snapshot):
                raise ShortcutMutationError(
                    "managed shortcut module changed concurrently"
                )
            latest_active, latest_runtime, _ = self._load_catalog_snapshot()
            for entry in latest_state.entries:
                if entry.id in changed_ids:
                    self._assert_action_active(
                        latest_active,
                        latest_runtime,
                        entry.current,
                        "managed application shortcut changed before repair",
                    )
            latest_candidate = self._reconciled_application_state(latest_state)
            if latest_candidate != candidate:
                raise ShortcutConflictError(
                    "application catalog changed before shortcut repair",
                    code="catalog.selection_changed",
                    context={"kind": "application"},
                )
            confirmed_active, confirmed_runtime, confirmed_error = (
                self._publish_state(
                    latest_state,
                    latest_candidate,
                    latest_snapshot,
                )
            )
            return self._status_for(
                latest_candidate,
                confirmed_runtime,
                confirmed_active,
                confirmed_error,
            )

    def status(self) -> dict[str, Any]:
        with self._locked():
            state, _ = self._read_state()
            active, runtime, discovery_error = self._load_catalog_snapshot()
            return self._status_for(state, runtime, active, discovery_error)

    def bindings(self) -> list[bindings.Binding]:
        """Return active bindings with authenticated stable presentation IDs."""
        with self._locked():
            state, _ = self._read_state()
            active, _, _ = self._load_catalog_snapshot()
            return self._presentation_bindings(state, active)

    @staticmethod
    def _validated_remove_request(request: object) -> dict[str, Any]:
        expected = {
            "targetModifiers",
            "targetKey",
            "targetBindingId",
            "title",
            "dispatcher",
            "argument",
            "confirmRemove",
        }
        if not isinstance(request, dict) or set(request) != expected:
            raise ShortcutValidationError(
                "shortcut request keys do not match remove operation"
            )
        values = dict(request)
        if not isinstance(values["targetModifiers"], list) or not all(
            isinstance(modifier, str) for modifier in values["targetModifiers"]
        ):
            raise ShortcutValidationError(
                "target modifiers must be a list of strings"
            )
        if not all(
            isinstance(values[name], str)
            for name in (
                "targetKey",
                "targetBindingId",
                "title",
                "dispatcher",
                "argument",
            )
        ):
            raise ShortcutValidationError("shortcut remove fields are invalid")
        modifiers = tuple(values["targetModifiers"])
        if modifiers not in _SUPER_MODIFIER_TUPLES:
            raise ShortcutValidationError(
                "target modifiers must be one supported Super group"
            )
        if values["targetKey"] not in _SUPPORTED_KEYS:
            raise ShortcutValidationError("target shortcut key is not supported")
        if (
            not values["targetBindingId"]
            or len(values["targetBindingId"]) > 200
            or _has_control(values["targetBindingId"])
        ):
            raise ShortcutValidationError("target binding identity is invalid")
        if (
            not values["title"].strip()
            or len(values["title"]) > 120
            or _has_control(values["title"])
            or len(values["dispatcher"]) > 120
            or _has_control(values["dispatcher"])
            or len(values["argument"]) > 4096
            or _has_control(values["argument"])
        ):
            raise ShortcutValidationError("shortcut remove metadata is invalid")
        if type(values["confirmRemove"]) is not bool:
            raise ShortcutValidationError(
                "remove confirmation must be a boolean"
            )
        if values["confirmRemove"] is not True:
            raise ShortcutConflictError(
                "shortcut removal requires explicit confirmation",
                code="shortcut.remove_confirmation_required",
            )
        return values

    def _removal_candidate(
        self,
        values: dict[str, Any],
        state: ManagedShortcutState,
        active: list[bindings.Binding],
        runtime: list[bindings.RuntimeBinding],
    ) -> ManagedShortcutState:
        chord = tuple(values["targetModifiers"]), values["targetKey"]
        runtime_occupants = self._runtime_on_chord(runtime, chord)
        displayed = [
            item
            for item in active
            if (item.modifiers, bindings.canonical_key(item.key)) == chord
        ]
        if len(runtime_occupants) != 1 or len(displayed) != 1:
            raise ShortcutConflictError(
                "shortcut is no longer uniquely removable",
                code="shortcut.remove_stale",
            )
        occupant = runtime_occupants[0]
        binding = displayed[0]
        if (
            binding.mouse
            or self._keycode_from_physical_key(occupant.key) is not None
        ):
            raise ShortcutConflictError(
                "shortcut uses an unsupported physical or mouse key",
                code="shortcut.remove_unavailable",
            )
        if (
            binding.id != values["targetBindingId"]
            or binding.description != values["title"]
            or (binding.dispatcher or "") != values["dispatcher"]
            or (binding.argument or "") != values["argument"]
            or occupant.description != binding.description
        ):
            raise ShortcutConflictError(
                "shortcut changed after the editor opened",
                code="shortcut.remove_stale",
            )

        entries = [entry for entry in state.entries if entry.current.chord != chord]
        managed = [entry for entry in state.entries if entry.current.chord == chord]
        if len(managed) > 1:
            raise ShortcutValidationError(
                "multiple managed entries occupy the removal target"
            )
        if managed:
            entry = managed[0]
            if entry.kind == "new":
                return replace(state, entries=tuple(entries))
            if entry.original is None or entry.source_binding_id is None:
                raise ShortcutValidationError(
                    "managed override is missing original provenance"
                )
            tombstone = SuppressedShortcut(
                id=self._entry_id("suppressed", entry.source_binding_id),
                source_binding_id=entry.source_binding_id,
                modifiers=entry.original.modifiers,
                key=entry.original.key,
                description=entry.original.description,
                dispatcher=None,
                argument=None,
                original=entry.original,
            )
            return replace(
                state,
                entries=tuple(entries),
                suppressed=(*state.suppressed, tombstone),
            )

        if any(item.chord == chord for item in state.suppressed):
            raise ShortcutConflictError(
                "shortcut suppression changed after the editor opened",
                code="shortcut.remove_stale",
            )
        original: ShortcutAction | None = None
        if binding.editable:
            try:
                candidate_original = self._binding_action(binding)
            except (ShortcutConflictError, ShortcutValidationError):
                candidate_original = None
            if (
                candidate_original is not None
                and self._runtime_action_matches(occupant, candidate_original)
            ):
                original = candidate_original
        if original is None and (
            occupant.dispatcher is None or occupant.argument is None
        ):
            raise ShortcutConflictError(
                "shortcut runtime identity cannot be restored safely",
                code="shortcut.remove_unavailable",
            )
        tombstone = SuppressedShortcut(
            id=self._entry_id("suppressed", binding.id),
            source_binding_id=binding.id,
            modifiers=chord[0],
            key=chord[1],
            description=binding.description,
            dispatcher=occupant.dispatcher,
            argument=occupant.argument,
            original=original,
        )
        return replace(state, suppressed=(*state.suppressed, tombstone))

    def remove(
        self, request: object
    ) -> tuple[dict[str, Any], list[bindings.Binding]]:
        values = self._validated_remove_request(request)
        with self._locked():
            state, snapshot = self._read_state()
            active, runtime, _ = self._load_catalog_snapshot()
            candidate = self._removal_candidate(values, state, active, runtime)
            self._preflight_config()
            latest_state, latest_snapshot = self._read_state()
            if not self._same_file(snapshot, latest_snapshot):
                raise ShortcutMutationError(
                    "managed shortcut module changed concurrently"
                )
            latest_active, latest_runtime, _ = self._load_catalog_snapshot()
            latest_candidate = self._removal_candidate(
                values,
                latest_state,
                latest_active,
                latest_runtime,
            )
            if latest_candidate != candidate:
                raise ShortcutConflictError(
                    "shortcut changed before removal",
                    code="shortcut.remove_stale",
                )
            confirmed_active, confirmed_runtime, confirmed_error = (
                self._publish_state(
                    latest_state,
                    latest_candidate,
                    latest_snapshot,
                )
            )
            return (
                self._status_for(
                    latest_candidate,
                    confirmed_runtime,
                    confirmed_active,
                    confirmed_error,
                ),
                self._presentation_bindings(latest_candidate, confirmed_active),
            )

    def _validated_assignment_request(self, request: object) -> dict[str, Any]:
        legacy_keys = {
            "targetModifiers",
            "targetKey",
            "title",
            "actionId",
            "customExecutable",
            "customArguments",
            "targetBindingId",
            "confirmReplace",
        }
        selection_keys = {
            "targetModifiers",
            "targetKey",
            "selectionKind",
            "selectionId",
            "titleOverride",
            "customArguments",
            "targetBindingId",
            "confirmReplace",
        }
        if not isinstance(request, dict):
            raise ShortcutValidationError("shortcut request keys do not match operation")
        keys = set(request)
        if keys == legacy_keys:
            new_contract = False
        elif keys == selection_keys:
            new_contract = True
        else:
            raise ShortcutValidationError("shortcut request keys do not match operation")
        values = dict(request)
        string_fields = (
            (
                "targetKey",
                "selectionKind",
                "selectionId",
                "titleOverride",
                "customArguments",
                "targetBindingId",
            )
            if new_contract
            else (
                "targetKey",
                "title",
                "actionId",
                "customExecutable",
                "customArguments",
                "targetBindingId",
            )
        )
        if not all(isinstance(values[name], str) for name in string_fields):
            raise ShortcutValidationError(
                "shortcut assignment string fields are invalid"
            )
        if not isinstance(values["targetModifiers"], list) or not all(
            isinstance(modifier, str) for modifier in values["targetModifiers"]
        ):
            raise ShortcutValidationError(
                "target modifiers must be a list of strings"
            )
        if type(values["confirmReplace"]) is not bool:
            raise ShortcutValidationError(
                "replacement confirmation must be a boolean"
            )
        if (
            len(values["targetBindingId"]) > 200
            or _has_control(values["targetBindingId"])
        ):
            raise ShortcutValidationError("target binding identity is invalid")

        if new_contract:
            selection_kind = values["selectionKind"]
            selection_id = values["selectionId"]
            if selection_kind not in {"action", "application", "command"}:
                raise ShortcutValidationError("selected catalog kind is invalid")
            if selection_kind == "action":
                identity_valid = _ID_PATTERN.fullmatch(selection_id) is not None
            else:
                identity_valid = catalog.is_valid_identity(
                    selection_kind, selection_id
                )
            if not identity_valid:
                raise ShortcutValidationError("selected catalog identity is invalid")
            title_override = values["titleOverride"]
            if (
                len(title_override) > 120
                or _has_control(title_override)
                or (title_override and not title_override.strip())
            ):
                raise ShortcutValidationError("shortcut title override is invalid")
            arguments = values["customArguments"]
            if selection_kind != "command" and arguments:
                raise ShortcutValidationError(
                    "custom arguments require a command selection"
                )
            if len(arguments) > 4096 or _has_control(arguments):
                raise ShortcutValidationError("custom arguments are invalid")
            try:
                shlex.split(arguments, posix=True)
            except ValueError as error:
                raise ShortcutValidationError("custom arguments are invalid") from error
            return {
                **values,
                "newContract": True,
                "title": "",
                "actionId": selection_id if selection_kind == "action" else "",
                "customExecutable": "",
            }

        action_id = values["actionId"]
        executable = values["customExecutable"]
        if bool(action_id) == bool(executable):
            raise ShortcutValidationError(
                "exactly one existing or custom action is required"
            )
        if action_id and _ID_PATTERN.fullmatch(action_id) is None:
            raise ShortcutValidationError("selected action identity is invalid")
        if action_id and values["customArguments"]:
            raise ShortcutValidationError(
                "custom arguments require a custom executable"
            )
        return {
            **values,
            "newContract": False,
            "selectionKind": "",
            "selectionId": "",
            "titleOverride": "",
        }

    def _resolve_catalog_selection(
        self, values: dict[str, Any]
    ) -> catalog.ResolvedSelection | None:
        kind = values["selectionKind"]
        if not values["newContract"] or kind == "action":
            return None
        try:
            resolved = self.catalog_discovery.resolve(kind, values["selectionId"])
        except catalog.CatalogError as error:
            raise ShortcutConflictError(
                f"selected {kind} is stale or unavailable",
                code="catalog.selection_stale",
                context={"kind": kind},
            ) from error
        if resolved.kind != kind or resolved.id != values["selectionId"]:
            raise ShortcutConflictError(
                f"selected {kind} is stale or unavailable",
                code="catalog.selection_stale",
                context={"kind": kind},
            )
        return resolved

    def _prepared_assignment(
        self,
        values: dict[str, Any],
        resolved: catalog.ResolvedSelection | None,
    ) -> tuple[dict[str, Any], str | None]:
        prepared = dict(values)
        if resolved is not None:
            prepared["title"] = values["titleOverride"] or resolved.default_title
            arguments = (
                resolved.arguments
                if resolved.kind == "application"
                else values["customArguments"]
            )
            try:
                command = self._custom_command(resolved.executable, arguments)
            except ShortcutValidationError as error:
                raise ShortcutConflictError(
                    f"selected {resolved.kind} is stale or unavailable",
                    code="catalog.selection_stale",
                    context={"kind": resolved.kind},
                ) from error
            return prepared, command
        if values["newContract"]:
            return prepared, None
        executable = values["customExecutable"]
        return (
            prepared,
            self._custom_command(executable, values["customArguments"])
            if executable
            else None,
        )

    def assign(
        self, request: object
    ) -> tuple[dict[str, Any], list[bindings.Binding]]:
        values = self._validated_assignment_request(request)

        with self._locked():
            state, snapshot = self._read_state()
            active, runtime, discovery_error = self._load_catalog_snapshot()
            resolved = self._resolve_catalog_selection(values)
            prepared, custom_command = self._prepared_assignment(values, resolved)
            candidate = self._assignment_candidate(
                prepared,
                state,
                active,
                runtime,
                custom_command,
            )
            if candidate == state:
                return (
                    self._status_for(
                        state,
                        runtime,
                        active,
                        discovery_error,
                    ),
                    self._presentation_bindings(state, active),
                )

            self._preflight_config()
            latest_state, latest_snapshot = self._read_state()
            if not self._same_file(snapshot, latest_snapshot):
                raise ShortcutMutationError(
                    "managed shortcut module changed concurrently"
                )
            latest_active, latest_runtime, _ = self._load_catalog_snapshot()
            latest_resolved = self._resolve_catalog_selection(values)
            if latest_resolved != resolved:
                raise ShortcutConflictError(
                    "selected catalog identity changed before publication",
                    code="catalog.selection_changed",
                )
            latest_prepared, latest_custom_command = self._prepared_assignment(
                values, latest_resolved
            )
            latest_candidate = self._assignment_candidate(
                latest_prepared,
                latest_state,
                latest_active,
                latest_runtime,
                latest_custom_command,
            )
            if latest_candidate != candidate:
                raise ShortcutConflictError(
                    "shortcut catalog changed before publication",
                    code="catalog.selection_changed",
                )
            confirmed_active, confirmed_runtime, confirmed_error = (
                self._publish_state(
                    latest_state,
                    latest_candidate,
                    latest_snapshot,
                )
            )
            return (
                self._status_for(
                    latest_candidate,
                    confirmed_runtime,
                    confirmed_active,
                    confirmed_error,
                ),
                self._presentation_bindings(latest_candidate, confirmed_active),
            )

    def add(self, request: object) -> dict[str, Any]:
        values = self._request_object(
            request, {"modifiers", "key", "description", "command"}
        )
        description = values["description"]
        command = values["command"]
        if not isinstance(description, str) or not isinstance(command, str):
            raise ShortcutValidationError("shortcut description and command must be strings")
        action = self._request_action(
            values,
            description=description,
            action_kind="exec",
            action_argument=command,
        )
        with self._locked():
            state, snapshot = self._read_state()
            _, runtime = self._load_binding_snapshot()
            self._assert_unoccupied(runtime, action.chord)
            if any(entry.current.chord == action.chord for entry in state.entries):
                raise ShortcutConflictError("target shortcut is already active")
            entry = ManagedShortcutEntry(
                id=self._entry_id(
                    "new",
                    json.dumps(action.as_dict(), sort_keys=True, ensure_ascii=False),
                ),
                kind="new",
                source_binding_id=None,
                original=None,
                current=action,
            )
            candidate = replace(state, entries=(*state.entries, entry))
            self._preflight_config()
            latest_runtime = self._load_runtime_bindings()
            self._assert_unoccupied(latest_runtime, action.chord)
            confirmed_active, confirmed_runtime, discovery_error = self._publish_state(
                state, candidate, snapshot
            )
            return self._status_for(
                candidate,
                confirmed_runtime,
                confirmed_active,
                discovery_error,
            )

    def move(self, request: object) -> dict[str, Any]:
        values = self._request_object(
            request, {"bindingId", "source", "modifiers", "key"}
        )
        binding_id = values["bindingId"]
        if not isinstance(binding_id, str) or not binding_id:
            raise ShortcutValidationError("source binding id must be a string")
        inspected_source = self._request_source_action(values["source"])
        with self._locked():
            state, snapshot = self._read_state()
            active, runtime = self._load_binding_snapshot()
            matches = [binding for binding in active if binding.id == binding_id]
            if len(matches) != 1:
                raise ShortcutConflictError("source binding is no longer active")
            try:
                source = self._binding_action(matches[0])
            except ShortcutConflictError as error:
                raise ShortcutConflictError("source binding changed or is no longer editable") from error
            if source != inspected_source:
                raise ShortcutConflictError("source binding changed after the editor opened")
            target = self._request_action(
                values,
                description=source.description,
                action_kind=source.action_kind,
                action_argument=source.action_argument,
            )
            if target.chord != source.chord:
                self._assert_unoccupied(runtime, target.chord)
            existing = self._entry_for_current(state, source)
            if target == source:
                return self._status_for(state, runtime)
            entries = [entry for entry in state.entries if entry is not existing]
            if existing is None:
                entry_id = self._entry_id("override", binding_id)
                updated = ManagedShortcutEntry(
                    id=entry_id,
                    kind="override",
                    source_binding_id=binding_id,
                    original=source,
                    current=target,
                    selection_kind="action",
                    selection_id=entry_id,
                    label_key=action_label_key(source.description),
                    title_override="",
                )
                entries.append(updated)
            elif existing.kind == "new":
                entries.append(
                    ManagedShortcutEntry(
                        id=existing.id,
                        kind="new",
                        source_binding_id=None,
                        original=None,
                        current=target,
                        selection_kind=existing.selection_kind,
                        selection_id=existing.selection_id,
                        label_key=existing.label_key,
                        title_override=existing.title_override,
                    )
                )
            elif existing.original is not None and target == existing.original:
                pass
            else:
                entries.append(
                    ManagedShortcutEntry(
                        id=existing.id,
                        kind="override",
                        source_binding_id=existing.source_binding_id,
                        original=existing.original,
                        current=target,
                        selection_kind=existing.selection_kind,
                        selection_id=existing.selection_id,
                        label_key=existing.label_key,
                        title_override=existing.title_override,
                    )
                )
            candidate = replace(state, entries=tuple(entries))
            self._preflight_config()
            latest_active, latest_runtime, _ = self._load_catalog_snapshot()
            self._assert_action_active(
                latest_active,
                latest_runtime,
                source,
                "source binding changed before publication",
            )
            if target.chord != source.chord:
                self._assert_unoccupied(latest_runtime, target.chord)
            confirmed_active, confirmed_runtime, discovery_error = self._publish_state(
                state, candidate, snapshot
            )
            return self._status_for(
                candidate,
                confirmed_runtime,
                confirmed_active,
                discovery_error,
            )

    def reset(
        self,
        *,
        commit_companion: Callable[[], None] | None = None,
        finalize_companion: Callable[[], None] | None = None,
        prepare_companion: Callable[[_FileSnapshot | None], None] | None = None,
    ) -> dict[str, Any]:
        with self._locked():
            state, snapshot = self._read_state()
            _, runtime = self._load_binding_snapshot()
            if prepare_companion is not None:
                prepare_companion(snapshot)
            if not state.entries and not state.suppressed:
                if commit_companion is not None:
                    commit_companion()
                if finalize_companion is not None:
                    finalize_companion()
                return self._status_for(state, runtime)
            self._preflight_config()
            latest_active, latest_runtime, _ = self._load_catalog_snapshot()
            for entry in state.entries:
                self._assert_action_active(
                    latest_active,
                    latest_runtime,
                    entry.current,
                    "managed shortcut changed before reset",
                )
            active_chords = {entry.current.chord for entry in state.entries}
            for chord in self._suppressed_sources(state):
                if chord in active_chords:
                    continue
                if self._runtime_on_chord(latest_runtime, chord):
                    raise ShortcutConflictError(
                        "suppressed shortcut changed before reset"
                    )
            empty = ManagedShortcutState.empty()
            confirmed_active, confirmed_runtime, discovery_error = self._publish_state(
                state,
                empty,
                snapshot,
                commit_companion,
            )
            if finalize_companion is not None:
                finalize_companion()
            return self._status_for(
                empty,
                confirmed_runtime,
                confirmed_active,
                discovery_error,
            )
