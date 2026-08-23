"""Bounded discovery of installed applications and executable commands."""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import stat
from typing import Iterable, Mapping
import unicodedata
from urllib.parse import urlsplit, urlunsplit

from .settings import SUPPORTED_LANGUAGES


CATALOG_VERSION = 1
DEFAULT_LAUNCHER = Path("/usr/bin/gtk-launch")
DEFAULT_FOCUS_LAUNCHER = Path("/usr/bin/omarchy-launch-or-focus")
DEFAULT_SESSION_LAUNCHER = Path("/usr/bin/uwsm-app")
MAX_DESKTOP_BYTES = 256 * 1024
MAX_FIELD_CHARACTERS = 512
MAX_KEYWORDS = 64
MAX_APPLICATIONS = 4096
MAX_COMMANDS = 8192
MAX_DIRECTORY_ENTRIES = 32768

_KEY = re.compile(r"^[A-Za-z][A-Za-z0-9-]*(?:\[[A-Za-z0-9_.@-]+\])?$")


class CatalogError(ValueError):
    """Base class for catalog input and discovery failures."""

    default_code = "catalog.invalid"

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


class CatalogResolutionError(CatalogError):
    """Raised when a selected catalog identity is no longer authoritative."""

    default_code = "catalog.selection_stale"


def _valid_desktop_id(value: str) -> bool:
    """Accept safe freedesktop IDs without rejecting human-readable filenames."""
    return bool(
        value
        and len(value) <= MAX_FIELD_CHARACTERS
        and value.endswith(".desktop")
        and not value.startswith(".")
        and ".." not in value
        and "/" not in value
        and not _has_control_characters(value)
    )


def is_valid_identity(kind: str, identity: str) -> bool:
    """Validate a stable identity without consulting mutable filesystem state."""
    if not isinstance(identity, str):
        return False
    if kind == "application":
        prefix = "application:"
        if not identity.startswith(prefix):
            return False
        desktop_id = identity[len(prefix):]
        return _valid_desktop_id(desktop_id)
    if kind == "command":
        return re.fullmatch(r"command:[0-9a-f]{64}", identity) is not None
    return False


@dataclass(frozen=True)
class CatalogItem:
    kind: str
    id: str
    title: str
    english_title: str
    summary: str
    icon: str
    path: str
    keywords: tuple[str, ...]
    target_id: str
    launch_kind: str


@dataclass(frozen=True)
class CatalogSnapshot:
    fingerprint: str
    items: tuple[CatalogItem, ...]
    warnings: tuple[str, ...]


@dataclass(frozen=True)
class ResolvedSelection:
    kind: str
    id: str
    default_title: str
    executable: str
    arguments: str


class _InvalidDesktopEntry(ValueError):
    pass


def _is_regular_executable(path: Path) -> bool:
    try:
        info = path.stat(follow_symlinks=False)
    except OSError:
        return False
    return (
        stat.S_ISREG(info.st_mode)
        and not path.is_symlink()
        and bool(info.st_mode & (stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH))
    )


def _has_control_characters(value: str) -> bool:
    return any(unicodedata.category(character) == "Cc" for character in value)


def _bounded_text(value: str, field: str, *, allow_empty: bool = True) -> str:
    result = value.strip()
    if not allow_empty and not result:
        raise _InvalidDesktopEntry(f"{field} is empty")
    if len(result) > MAX_FIELD_CHARACTERS:
        raise _InvalidDesktopEntry(f"{field} is too long")
    if _has_control_characters(result):
        raise _InvalidDesktopEntry(f"{field} contains a control character")
    return result


def _unescape(value: str) -> str:
    replacements = {
        "s": " ",
        "n": "\n",
        "t": "\t",
        "r": "\r",
        "\\": "\\",
    }
    result: list[str] = []
    index = 0
    while index < len(value):
        if value[index] == "\\" and index + 1 < len(value):
            escaped = value[index + 1]
            result.append(replacements.get(escaped, escaped))
            index += 2
            continue
        result.append(value[index])
        index += 1
    return "".join(result)


def _parse_desktop_entry(path: Path) -> dict[str, str]:
    try:
        info = path.stat(follow_symlinks=False)
    except OSError as error:
        raise _InvalidDesktopEntry("cannot inspect file") from error
    if path.is_symlink() or not stat.S_ISREG(info.st_mode):
        raise _InvalidDesktopEntry("not a regular file")
    if info.st_size > MAX_DESKTOP_BYTES:
        raise _InvalidDesktopEntry("file is too large")
    try:
        data = path.read_bytes()
    except OSError as error:
        raise _InvalidDesktopEntry("cannot read file") from error
    if len(data) > MAX_DESKTOP_BYTES:
        raise _InvalidDesktopEntry("file is too large")
    try:
        source = data.decode("utf-8")
    except UnicodeDecodeError as error:
        raise _InvalidDesktopEntry("file is not UTF-8") from error

    values: dict[str, str] = {}
    in_desktop_group = False
    desktop_group_seen = False
    for raw_line in source.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            group = line[1:-1]
            if group == "Desktop Entry":
                if desktop_group_seen:
                    raise _InvalidDesktopEntry("duplicate Desktop Entry group")
                desktop_group_seen = True
                in_desktop_group = True
            else:
                in_desktop_group = False
            continue
        if not in_desktop_group:
            continue
        if "=" not in raw_line:
            raise _InvalidDesktopEntry("malformed field")
        key, value = raw_line.split("=", 1)
        key = key.strip()
        if not _KEY.fullmatch(key):
            raise _InvalidDesktopEntry("invalid field name")
        if key in values:
            raise _InvalidDesktopEntry("duplicate field")
        values[key] = _unescape(value)
    if not desktop_group_seen:
        raise _InvalidDesktopEntry("missing Desktop Entry group")
    return values


def _locale_candidates(language: str) -> tuple[str | None, ...]:
    values: list[str | None] = [language]
    base = language.split("_", 1)[0]
    if base != language:
        values.append(base)
    if "en" not in values:
        values.append("en")
    values.append(None)
    return tuple(values)


def _localized(values: Mapping[str, str], field: str, language: str) -> str:
    for locale in _locale_candidates(language):
        key = field if locale is None else f"{field}[{locale}]"
        if key in values and values[key].strip():
            return values[key]
    return ""


def _localized_summary(values: Mapping[str, str], language: str) -> str:
    """Prefer the user's locale before falling back to a richer field."""
    for locale in _locale_candidates(language):
        for field in ("Comment", "GenericName"):
            key = field if locale is None else f"{field}[{locale}]"
            if key in values and values[key].strip():
                return values[key]
    return ""


def _desktop_list(value: str) -> tuple[str, ...]:
    return tuple(item for item in value.split(";") if item)


def _truthy(value: str) -> bool:
    return value.strip().lower() == "true"


def _exec_focus_candidate(value: str) -> str:
    """Return a likely window class from a desktop Exec command."""
    try:
        tokens = shlex.split(value, posix=True)
    except ValueError:
        return ""
    if not tokens:
        return ""
    index = 0
    if Path(tokens[0]).name == "env":
        index = 1
        while index < len(tokens):
            token = tokens[index]
            if token == "--":
                index += 1
                break
            if token.startswith("-") or re.fullmatch(
                r"[A-Za-z_][A-Za-z0-9_]*=.*", token
            ):
                index += 1
                continue
            break
    while index < len(tokens) and re.fullmatch(
        r"[A-Za-z_][A-Za-z0-9_]*=.*", tokens[index]
    ):
        index += 1
    if index >= len(tokens) or tokens[index].startswith("%"):
        return ""
    candidate = Path(tokens[index]).name
    if candidate in {
        "env",
        "flatpak",
        "gtk-launch",
        "omarchy",
        "uwsm-app",
        "sh",
        "bash",
    }:
        return ""
    return candidate


def webapp_target_id(value: str) -> str:
    """Return a canonical presentation identity for a webapp Exec command."""
    try:
        tokens = shlex.split(value, posix=True)
    except ValueError:
        return ""
    if not tokens:
        return ""
    launcher = Path(tokens[0]).name
    if launcher == "omarchy-launch-webapp" and len(tokens) >= 2:
        url = tokens[1]
    elif launcher == "omarchy-launch-or-focus-webapp" and len(tokens) >= 3:
        url = tokens[2]
    else:
        return ""
    if len(url) > MAX_FIELD_CHARACTERS or _has_control_characters(url):
        return ""
    try:
        parsed = urlsplit(url)
        port = parsed.port
    except ValueError:
        return ""
    scheme = parsed.scheme.lower()
    hostname = (parsed.hostname or "").lower()
    if (
        scheme not in {"http", "https"}
        or not hostname
        or parsed.username is not None
        or parsed.password is not None
    ):
        return ""
    default_port = (scheme == "http" and port == 80) or (
        scheme == "https" and port == 443
    )
    normalized_host = f"[{hostname}]" if ":" in hostname else hostname
    netloc = (
        normalized_host
        if port is None or default_port
        else f"{normalized_host}:{port}"
    )
    normalized = urlunsplit(
        (scheme, netloc, parsed.path or "/", parsed.query, "")
    )
    return f"webapp:{normalized}"


def _focus_pattern(values: Mapping[str, str], desktop_id: str) -> str:
    candidate = _bounded_text(values.get("StartupWMClass", ""), "StartupWMClass")
    if not candidate:
        candidate = _exec_focus_candidate(values.get("Exec", ""))
    if not candidate:
        candidate = desktop_id.removesuffix(".desktop")
    if not any(character.isalnum() for character in candidate):
        raise _InvalidDesktopEntry("window class is invalid")
    return re.escape(candidate)


class CatalogDiscovery:
    """Discover a fresh bounded catalog from an explicit process environment."""

    def __init__(
        self,
        environ: Mapping[str, str] | None = None,
        launcher_path: str | Path = DEFAULT_LAUNCHER,
        focus_launcher_path: str | Path = DEFAULT_FOCUS_LAUNCHER,
        session_launcher_path: str | Path = DEFAULT_SESSION_LAUNCHER,
    ) -> None:
        self._environ = dict(os.environ if environ is None else environ)
        self._launcher = Path(launcher_path)
        self._focus_launcher = Path(focus_launcher_path)
        self._session_launcher = Path(session_launcher_path)

    def _application_directories(self) -> tuple[Path, ...]:
        home = Path(self._environ.get("HOME") or Path.home())
        data_home = self._environ.get("XDG_DATA_HOME")
        first = Path(data_home) if data_home else home / ".local" / "share"
        data_dirs_value = self._environ.get("XDG_DATA_DIRS")
        data_dirs = (
            data_dirs_value.split(os.pathsep)
            if data_dirs_value
            else ["/usr/local/share", "/usr/share"]
        )
        result = [first / "applications"]
        result.extend(Path(value) / "applications" for value in data_dirs if value)
        return tuple(result)

    def _path_directories(self) -> tuple[Path, ...]:
        result: list[Path] = []
        seen: set[str] = set()
        for value in self._environ.get("PATH", "").split(os.pathsep):
            if not value:
                continue
            path = Path(value)
            identity = os.path.abspath(path)
            if identity not in seen:
                seen.add(identity)
                result.append(Path(identity))
        return tuple(result)

    @staticmethod
    def _desktop_files(directory: Path) -> tuple[tuple[str, Path], ...]:
        if not directory.is_dir():
            return ()
        found: list[tuple[str, Path]] = []
        pending: list[tuple[Path, tuple[str, ...]]] = [(directory, ())]
        inspected = 0
        while pending and inspected < MAX_DIRECTORY_ENTRIES:
            current, relative_parts = pending.pop()
            try:
                entries = sorted(os.scandir(current), key=lambda item: item.name)
            except OSError:
                continue
            for entry in entries:
                inspected += 1
                if inspected > MAX_DIRECTORY_ENTRIES:
                    break
                parts = relative_parts + (entry.name,)
                try:
                    if entry.is_dir(follow_symlinks=False):
                        pending.append((Path(entry.path), parts))
                    elif entry.name.endswith(".desktop"):
                        desktop_id = "-".join(parts)
                        found.append((desktop_id, Path(entry.path)))
                except OSError:
                    continue
        return tuple(sorted(found, key=lambda pair: (pair[0], str(pair[1]))))

    def _try_exec_available(self, value: str) -> bool:
        candidate = value.strip()
        if not candidate or _has_control_characters(candidate):
            return False
        if os.path.isabs(candidate):
            return _is_regular_executable(Path(candidate))
        if "/" in candidate:
            return False
        for directory in self._path_directories():
            if _is_regular_executable(directory / candidate):
                return True
        return False

    def _visible_on_current_desktop(self, values: Mapping[str, str]) -> bool:
        current = {
            value for value in self._environ.get("XDG_CURRENT_DESKTOP", "").split(":")
            if value
        }
        only = set(_desktop_list(values.get("OnlyShowIn", "")))
        blocked = set(_desktop_list(values.get("NotShowIn", "")))
        if only and not current.intersection(only):
            return False
        return not current.intersection(blocked)

    def _item_from_desktop(
        self,
        desktop_id: str,
        values: Mapping[str, str],
        language: str,
    ) -> CatalogItem | None:
        if values.get("Type", "") != "Application":
            return None
        if _truthy(values.get("Hidden", "")) or _truthy(values.get("NoDisplay", "")):
            return None
        if not self._visible_on_current_desktop(values):
            return None
        if not values.get("Exec", "").strip():
            return None
        _focus_pattern(values, desktop_id)
        try_exec = values.get("TryExec", "").strip()
        if try_exec and not self._try_exec_available(try_exec):
            return None

        title = _bounded_text(
            _localized(values, "Name", language), "Name", allow_empty=False
        )
        english_title = _bounded_text(
            _localized(values, "Name", "en"), "Name", allow_empty=False
        )
        summary_source = _localized_summary(values, language)
        summary = _bounded_text(summary_source, "summary")
        icon = _bounded_text(values.get("Icon", ""), "Icon")

        keyword_values: list[str] = []
        keyword_fields = (
            key for key in sorted(values)
            if key == "Name" or key.startswith("Name[")
            or key == "GenericName" or key.startswith("GenericName[")
            or key == "Keywords" or key.startswith("Keywords[")
        )
        for key in keyword_fields:
            raw_values = (
                _desktop_list(values[key]) if key.startswith("Keywords")
                else (values[key],)
            )
            for raw_value in raw_values:
                value = _bounded_text(raw_value, key)
                if value and value not in keyword_values:
                    keyword_values.append(value)
                if len(keyword_values) >= MAX_KEYWORDS:
                    break
            if len(keyword_values) >= MAX_KEYWORDS:
                break
        application_id = f"application:{desktop_id}"
        webapp_id = webapp_target_id(values.get("Exec", ""))
        return CatalogItem(
            kind="application",
            id=application_id,
            title=title,
            english_title=english_title,
            summary=summary,
            icon=icon,
            path="",
            keywords=tuple(keyword_values),
            target_id=webapp_id or application_id,
            launch_kind=(
                "webapp" if webapp_id
                else "cmd" if _truthy(values.get("Terminal", ""))
                else "desktopApp"
            ),
        )

    def application_for_executable(
        self, executable: str, language: str = "en"
    ) -> CatalogItem | None:
        """Find a visible desktop entry whose declared executable matches exactly."""
        wanted = Path(str(executable or "").strip()).name
        if not wanted:
            return None
        _by_id, by_executable = self.application_index(language)
        return by_executable.get(wanted)

    def application_index(
        self, language: str = "en"
    ) -> tuple[dict[str, CatalogItem], dict[str, CatalogItem]]:
        """Index visible applications by stable ID and declared executable."""
        applications, _warnings, by_executable = self._application_inventory(language)
        return {item.id: item for item in applications}, by_executable

    def _applications(self, language: str) -> tuple[list[CatalogItem], list[str]]:
        applications, warnings, _by_executable = self._application_inventory(language)
        return applications, warnings

    def _application_inventory(
        self, language: str
    ) -> tuple[list[CatalogItem], list[str], dict[str, CatalogItem]]:
        warnings: list[str] = []
        if not all(
            _is_regular_executable(path)
            for path in (
                self._launcher,
                self._focus_launcher,
                self._session_launcher,
            )
        ):
            return [], ["application launcher is unavailable"], {}
        claimed: set[str] = set()
        items: list[CatalogItem] = []
        by_executable: dict[str, CatalogItem] = {}
        ambiguous_executables: set[str] = set()
        for directory in self._application_directories():
            for desktop_id, path in self._desktop_files(directory):
                if desktop_id in claimed:
                    continue
                claimed.add(desktop_id)
                if not _valid_desktop_id(desktop_id):
                    warnings.append(f"invalid desktop identity: {desktop_id[:80]}")
                    continue
                try:
                    values = _parse_desktop_entry(path)
                    item = self._item_from_desktop(desktop_id, values, language)
                except _InvalidDesktopEntry as error:
                    warnings.append(
                        f"invalid desktop entry {desktop_id[:80]}: {error}"
                    )
                    continue
                if item is not None:
                    items.append(item)
                    candidates = (
                        Path(values.get("TryExec", "").strip()).name,
                        _exec_focus_candidate(values.get("Exec", "")),
                    )
                    for candidate in candidates:
                        if not candidate or candidate in ambiguous_executables:
                            continue
                        existing = by_executable.get(candidate)
                        if existing is None:
                            by_executable[candidate] = item
                        elif existing.id != item.id:
                            by_executable.pop(candidate, None)
                            ambiguous_executables.add(candidate)
                    if len(items) >= MAX_APPLICATIONS:
                        warnings.append("application result limit reached")
                        break
            if len(items) >= MAX_APPLICATIONS:
                break
        items.sort(key=lambda item: (item.title.casefold(), item.id))
        return items, warnings, by_executable

    def _application_command_names(
        self, applications: Iterable[CatalogItem]
    ) -> set[str]:
        desktop_ids = {
            item.id.removeprefix("application:")
            for item in applications
            if item.kind == "application"
        }
        names: set[str] = set()
        claimed: set[str] = set()
        for directory in self._application_directories():
            for desktop_id, path in self._desktop_files(directory):
                if desktop_id in claimed:
                    continue
                claimed.add(desktop_id)
                if desktop_id not in desktop_ids:
                    continue
                try:
                    values = _parse_desktop_entry(path)
                    name = _exec_focus_candidate(values.get("Exec", ""))
                except _InvalidDesktopEntry:
                    continue
                if name:
                    names.add(name)
        return names

    def _commands(self, excluded_names: Iterable[str] = ()) -> list[CatalogItem]:
        items: list[CatalogItem] = []
        claimed_names: set[str] = set()
        excluded = set(excluded_names)
        for directory in self._path_directories():
            try:
                entries = sorted(os.scandir(directory), key=lambda item: item.name)
            except OSError:
                continue
            for entry in entries[:MAX_DIRECTORY_ENTRIES]:
                name = entry.name
                if name in claimed_names:
                    continue
                if name in excluded or re.fullmatch(r"omarchy-install(?:-.*)?", name):
                    continue
                path = Path(entry.path)
                if not _is_regular_executable(path):
                    continue
                try:
                    title = _bounded_text(name, "command name", allow_empty=False)
                except _InvalidDesktopEntry:
                    continue
                claimed_names.add(name)
                absolute = str(path.absolute())
                identity = hashlib.sha256(absolute.encode("utf-8")).hexdigest()
                command_id = f"command:{identity}"
                items.append(
                    CatalogItem(
                        kind="command",
                        id=command_id,
                        title=title,
                        english_title=title,
                        summary="",
                        icon="",
                        path=absolute,
                        keywords=(title,),
                        target_id=command_id,
                        launch_kind="command",
                    )
                )
                if len(items) >= MAX_COMMANDS:
                    break
            if len(items) >= MAX_COMMANDS:
                break
        items.sort(key=lambda item: (item.title.casefold(), item.path))
        return items

    @staticmethod
    def _metadata(path: Path) -> tuple[int, int, int, int, int] | None:
        try:
            info = path.stat(follow_symlinks=False)
        except OSError:
            return None
        return (
            info.st_dev,
            info.st_ino,
            info.st_mtime_ns,
            info.st_size,
            info.st_mode,
        )

    def _fingerprint_records(self) -> Iterable[object]:
        yield ("environment", self._environ.get("XDG_CURRENT_DESKTOP", ""))
        yield ("launcher", str(self._launcher), self._metadata(self._launcher))
        yield (
            "focus-launcher",
            str(self._focus_launcher),
            self._metadata(self._focus_launcher),
        )
        yield (
            "session-launcher",
            str(self._session_launcher),
            self._metadata(self._session_launcher),
        )
        for directory in self._application_directories():
            yield ("application-directory", str(directory), self._metadata(directory))
            for desktop_id, path in self._desktop_files(directory):
                yield ("desktop", desktop_id, str(path), self._metadata(path))
        for directory in self._path_directories():
            yield ("path-directory", str(directory), self._metadata(directory))
            try:
                entries = sorted(os.scandir(directory), key=lambda item: item.name)
            except OSError:
                continue
            for entry in entries[:MAX_DIRECTORY_ENTRIES]:
                path = Path(entry.path)
                yield ("path-entry", entry.name, str(path), self._metadata(path))

    def fingerprint(self) -> str:
        digest = hashlib.sha256()
        for record in self._fingerprint_records():
            digest.update(
                json.dumps(record, ensure_ascii=False, separators=(",", ":"))
                .encode("utf-8")
            )
            digest.update(b"\0")
        return digest.hexdigest()

    def snapshot(self, language: str) -> CatalogSnapshot:
        if language not in SUPPORTED_LANGUAGES:
            raise CatalogError("catalog language is not supported")
        applications, warnings = self._applications(language)
        commands = self._commands(self._application_command_names(applications))
        return CatalogSnapshot(
            fingerprint=self.fingerprint(),
            items=tuple(applications + commands),
            warnings=tuple(warnings),
        )

    def resolve(self, kind: str, identity: str) -> ResolvedSelection:
        if kind == "application":
            prefix = "application:"
            if not is_valid_identity(kind, identity):
                raise CatalogResolutionError("application identity is invalid")
            desktop_id = identity[len(prefix):]
            applications, _warnings = self._applications("en")
            item = next((item for item in applications if item.id == identity), None)
            if item is None:
                raise CatalogResolutionError("application is no longer available")
            values: dict[str, str] | None = None
            for directory in self._application_directories():
                match = next(
                    (
                        path
                        for found_id, path in self._desktop_files(directory)
                        if found_id == desktop_id
                    ),
                    None,
                )
                if match is not None:
                    try:
                        values = _parse_desktop_entry(match)
                    except _InvalidDesktopEntry as error:
                        raise CatalogResolutionError(
                            "application is no longer available"
                        ) from error
                    break
            if values is None:
                raise CatalogResolutionError("application is no longer available")
            launch_command = shlex.join(
                [
                    str(self._session_launcher),
                    "--",
                    str(self._launcher),
                    desktop_id,
                ]
            )
            try:
                focus_pattern = _focus_pattern(values, desktop_id)
            except _InvalidDesktopEntry as error:
                raise CatalogResolutionError(
                    "application is no longer available"
                ) from error
            arguments = shlex.join([focus_pattern, launch_command])
            return ResolvedSelection(
                kind="application",
                id=identity,
                default_title=item.title,
                executable=str(self._focus_launcher),
                arguments=arguments,
            )
        if kind == "command":
            if not is_valid_identity(kind, identity):
                raise CatalogResolutionError("command identity is invalid")
            applications, _warnings = self._applications("en")
            item = next(
                (
                    item
                    for item in self._commands(
                        self._application_command_names(applications)
                    )
                    if item.id == identity
                ),
                None,
            )
            if item is None:
                raise CatalogResolutionError("command is no longer available")
            return ResolvedSelection(
                kind="command",
                id=identity,
                default_title=item.title,
                executable=item.path,
                arguments="",
            )
        raise CatalogResolutionError("catalog selection kind is invalid")
