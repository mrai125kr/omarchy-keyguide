"""Read-only compatibility checks for the supported Omarchy environment."""

from __future__ import annotations

from dataclasses import dataclass
import fcntl
import glob
import os
import re
import subprocess


EV_KEY = 0x01
KEY_A = 30
KEY_LEFTMETA = 125
KEY_RIGHTMETA = 126
KEY_MAX = 0x2FF
_IOC_READ = 2
_IOC_TYPE = ord("E")
_IOC_NR_BASE = 0x20


def _eviocgbit(event_type: int, length: int) -> int:
    """Build Linux's EVIOCGBIT request for an event capability bitmap."""
    return (_IOC_READ << 30) | (length << 16) | (_IOC_TYPE << 8) | (
        _IOC_NR_BASE + event_type
    )


def _bit_is_set(bitmap: bytes, code: int) -> bool:
    return bool(bitmap[code // 8] & (1 << (code % 8)))


def _version_from(text: str) -> str:
    match = re.search(r"\b\d+\.\d+\.\d+(?:-\d+)?\b", text)
    return match.group(0) if match else "unavailable"


@dataclass(frozen=True)
class Probe:
    """The system facts needed to decide whether Keyguide can run safely."""

    omarchy_version: str
    hyprland_text: str
    input_readable: bool

    @property
    def omarchy_major(self) -> int | None:
        match = re.match(r"(\d+)", self.omarchy_version)
        return int(match.group(1)) if match else None

    @property
    def hyprland_version(self) -> tuple[int, int, int]:
        match = re.search(r"(\d+)\.(\d+)\.(\d+)", self.hyprland_text)
        return tuple(map(int, match.groups())) if match else (0, 0, 0)

    def as_json(self) -> dict[str, object]:
        return {
            "omarchy_version": self.omarchy_version,
            "hyprland_version": self.hyprland_text,
            "input_readable": self.input_readable,
        }


def check(probe: Probe) -> dict[str, object]:
    """Return the compatibility result for already-collected system facts."""
    errors = []
    if probe.omarchy_major != 4:
        errors.append(f"unsupported Omarchy major: {probe.omarchy_version}")
    if probe.hyprland_version < (0, 56, 2):
        errors.append(f"unsupported Hyprland: {probe.hyprland_text}")
    if not probe.input_readable:
        errors.append("no readable keyboard event device")
    return {"ok": not errors, **probe.as_json(), "errors": errors}


def _command_version(command: list[str]) -> str:
    try:
        completed = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
        )
    except OSError:
        return "unavailable"
    return _version_from(completed.stdout)


def _readable_keyboard_device(path: str) -> bool:
    """Return whether *path* can expose ordinary and Meta keyboard keys."""
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
    except OSError:
        return False
    try:
        bitmap = bytearray((KEY_MAX + 8) // 8)
        fcntl.ioctl(fd, _eviocgbit(EV_KEY, len(bitmap)), bitmap, True)
        return _bit_is_set(bitmap, KEY_A) and (
            _bit_is_set(bitmap, KEY_LEFTMETA) or _bit_is_set(bitmap, KEY_RIGHTMETA)
        )
    except OSError:
        return False
    finally:
        os.close(fd)


def probe_system() -> Probe:
    """Collect compatibility facts without modifying input, Hyprland, or Omarchy."""
    return Probe(
        omarchy_version=_command_version(["omarchy", "version"]),
        hyprland_text=_command_version(["hyprctl", "version"]),
        input_readable=any(
            _readable_keyboard_device(path) for path in glob.glob("/dev/input/event*")
        ),
    )
