"""Validated, versioned persistence for Keyguide presentation settings."""

from __future__ import annotations

from dataclasses import dataclass
import json
import math
import os
from pathlib import Path
import stat
import tempfile
from typing import Any

from .groups import SUPER_GROUPS


DEFAULTS = {
    "version": 2,
    "enabled": True,
    "position": "center",
    "scale": 1.0,
    "opacity": 0.94,
    "groups": list(SUPER_GROUPS),
    "hiddenBindingIds": [],
    "followTheme": True,
    "language": "en",
}

_POSITIONS = frozenset({"top", "center", "bottom", "left", "right"})
_GROUPS = frozenset(SUPER_GROUPS)
DEFAULT_LANGUAGE = "en"
SUPPORTED_LANGUAGES = frozenset({"en", "ko", "ja", "zh_CN", "es"})
_VERSION_ONE_KEYS = frozenset(
    {
        "version",
        "enabled",
        "position",
        "scale",
        "opacity",
        "groups",
        "hiddenBindingIds",
        "followTheme",
    }
)


class SettingsValidationError(ValueError):
    """Raised when a settings document cannot safely drive the HUD."""

    default_code = "settings.invalid"

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


@dataclass(frozen=True)
class SettingsFileSnapshot:
    """Exact preimage used to recover a multi-resource settings transaction."""

    data: bytes | None
    mode: int | None


def default_path() -> Path:
    """Return Keyguide's private XDG data-file location."""
    data_home = Path(
        os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share"
    )
    return data_home / "omarchy-keyguide" / "settings.json"


def snapshot_file(path: str | Path) -> SettingsFileSnapshot:
    """Capture the exact regular-file bytes at ``path``, including absence."""
    settings_path = Path(path)
    try:
        info = settings_path.stat(follow_symlinks=False)
    except FileNotFoundError:
        return SettingsFileSnapshot(None, None)
    if not stat.S_ISREG(info.st_mode):
        raise SettingsValidationError("settings path is not a regular file")
    try:
        return SettingsFileSnapshot(
            settings_path.read_bytes(),
            stat.S_IMODE(info.st_mode),
        )
    except OSError as error:
        raise SettingsValidationError(f"cannot snapshot settings: {error}") from error


def _sync_parent(path: Path) -> None:
    descriptor = os.open(
        path.parent,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC,
    )
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def _replace_bytes_atomic(path: Path, data: bytes, mode: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=path.parent,
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as temporary_file:
            temporary_file.write(data)
            temporary_file.flush()
            os.fchmod(temporary_file.fileno(), mode)
            os.fsync(temporary_file.fileno())
        os.replace(temporary_path, path)
        _sync_parent(path)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def restore_file_snapshot(path: str | Path, snapshot: SettingsFileSnapshot) -> None:
    """Restore a previously captured settings preimage and sync its directory."""
    settings_path = Path(path)
    if snapshot.data is None:
        try:
            settings_path.unlink()
        except FileNotFoundError:
            return
        _sync_parent(settings_path)
        return
    _replace_bytes_atomic(settings_path, snapshot.data, snapshot.mode or 0o600)


def _is_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _migrate(values: object) -> dict[str, Any]:
    if not isinstance(values, dict):
        raise SettingsValidationError("settings must be a JSON object")
    if type(values.get("version")) is not int or values["version"] != 1:
        return dict(values)
    keys = frozenset(values)
    if keys not in {_VERSION_ONE_KEYS, _VERSION_ONE_KEYS | {"showHiddenFiles"}}:
        raise SettingsValidationError("version 1 settings keys do not match schema")
    return {
        key: value
        for key, value in values.items()
        if key not in {"version", "showHiddenFiles"}
    } | {"version": 2, "language": DEFAULT_LANGUAGE}


def _validate(values: object) -> dict[str, Any]:
    values = _migrate(values)
    if frozenset(values) != frozenset(DEFAULTS):
        raise SettingsValidationError("settings keys do not match schema version 2")

    version = values["version"]
    if type(version) is not int or version != 2:
        raise SettingsValidationError("unsupported settings version")

    enabled = values["enabled"]
    follow_theme = values["followTheme"]
    if not isinstance(enabled, bool) or not isinstance(follow_theme, bool):
        raise SettingsValidationError(
            "enabled and followTheme must be booleans"
        )

    language = values["language"]
    if not isinstance(language, str) or language not in SUPPORTED_LANGUAGES:
        raise SettingsValidationError(
            "language is not supported",
            code="settings.language_invalid",
            context={"language": str(language)},
        )

    position = values["position"]
    if not isinstance(position, str) or position not in _POSITIONS:
        raise SettingsValidationError("position must be top, center, bottom, left, or right")

    scale = values["scale"]
    if not _is_number(scale) or not math.isfinite(scale) or not 0.75 <= scale <= 1.5:
        raise SettingsValidationError("scale must be between 0.75 and 1.5")

    opacity = values["opacity"]
    if not _is_number(opacity) or not math.isfinite(opacity) or not 0.2 <= opacity <= 1.0:
        raise SettingsValidationError("opacity must be between 0.2 and 1.0")

    groups = values["groups"]
    if not isinstance(groups, list) or not all(isinstance(group, str) for group in groups):
        raise SettingsValidationError("groups must be a list of modifier group names")
    if any(group not in _GROUPS for group in groups):
        raise SettingsValidationError("groups contains an unknown modifier group")

    hidden_ids = values["hiddenBindingIds"]
    if not isinstance(hidden_ids, list) or not all(
        isinstance(binding_id, str) for binding_id in hidden_ids
    ):
        raise SettingsValidationError("hiddenBindingIds must contain only strings")

    return {
        "version": 2,
        "enabled": enabled,
        "position": position,
        "scale": float(scale),
        "opacity": float(opacity),
        "groups": list(groups),
        "hiddenBindingIds": list(hidden_ids),
        "followTheme": follow_theme,
        "language": language,
    }


@dataclass(frozen=True)
class Settings:
    """An immutable, schema-validated settings document."""

    _values: dict[str, Any]

    @classmethod
    def defaults(cls) -> "Settings":
        """Return a fresh copy of the complete version 2 settings document."""
        return cls(_validate(DEFAULTS))

    @classmethod
    def load(cls, path: str | Path) -> "Settings":
        """Load a valid document, or defaults when it has not been created yet."""
        settings_path = Path(path)
        if not settings_path.exists():
            return cls.defaults()
        try:
            document = json.loads(settings_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise SettingsValidationError(f"cannot load settings: {error}") from error
        return cls(_validate(document))

    def as_dict(self) -> dict[str, Any]:
        """Return a JSON-ready copy that callers may safely modify."""
        return _validate(self._values)

    def update(self, patch: dict[str, Any]) -> "Settings":
        """Return a new document after applying one validated partial update."""
        if not isinstance(patch, dict):
            raise SettingsValidationError("settings patch must be a JSON object")
        if any(key not in DEFAULTS for key in patch):
            raise SettingsValidationError("settings patch contains an unknown key")
        updated = self.as_dict()
        updated.update(patch)
        return type(self)(_validate(updated))

    def save_atomic(self, path: str | Path) -> None:
        """Durably replace ``path`` only after a complete temp-file write."""
        settings_path = Path(path)
        document = json.dumps(
            self.as_dict(),
            indent=2,
            sort_keys=True,
        ).encode("utf-8") + b"\n"
        _replace_bytes_atomic(settings_path, document, 0o600)
