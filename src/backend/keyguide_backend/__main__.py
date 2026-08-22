"""Command-line entrypoints for Omarchy Keyguide."""

from __future__ import annotations

import argparse
from dataclasses import asdict
import json
import sys

from . import bindings, catalog, compat, layout, settings, shortcuts


def main() -> int:
    parser = argparse.ArgumentParser(prog="keyguide_backend")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("compat")
    bindings_parser = commands.add_parser("bindings")
    bindings_parser.add_argument("--json", action="store_true", required=True)
    settings_parser = commands.add_parser("settings")
    settings_parser.add_argument("--path")
    settings_commands = settings_parser.add_subparsers(
        dest="settings_command", required=True
    )
    settings_commands.add_parser("get")
    settings_patch_parser = settings_commands.add_parser("patch")
    settings_patch_parser.add_argument("patch")
    shortcuts_parser = commands.add_parser("shortcuts")
    shortcut_commands = shortcuts_parser.add_subparsers(
        dest="shortcuts_command", required=True
    )
    shortcut_commands.add_parser("status")
    shortcut_commands.add_parser("reconcile")
    for operation in ("add", "move", "assign", "remove"):
        operation_parser = shortcut_commands.add_parser(operation)
        operation_parser.add_argument("request")
    shortcut_commands.add_parser("reset-all")
    catalog_parser = commands.add_parser("catalog")
    catalog_commands = catalog_parser.add_subparsers(
        dest="catalog_command", required=True
    )
    catalog_list = catalog_commands.add_parser("list")
    catalog_list.add_argument(
        "--language",
        choices=sorted(settings.SUPPORTED_LANGUAGES),
        required=True,
    )
    catalog_commands.add_parser("fingerprint")
    layout_parser = commands.add_parser("layout")
    layout_parser.add_argument("request")
    arguments = parser.parse_args()

    if arguments.command == "compat":
        result = compat.check(compat.probe_system())
        print(json.dumps(result, sort_keys=True))
        return 0 if result["ok"] else 1
    if arguments.command == "bindings":
        manager = shortcuts.ShortcutManager()
        manager.recover_reset_transaction(settings.default_path())
        result = [asdict(binding) for binding in manager.bindings()]
        print(json.dumps(result, ensure_ascii=False))
        return 0
    if arguments.command == "settings":
        default_settings_path = settings.default_path()
        shortcuts.ShortcutManager().recover_reset_transaction(
            default_settings_path
        )
        path = arguments.path or default_settings_path
        current = settings.Settings.load(path)
        if arguments.settings_command == "patch":
            try:
                patch = json.loads(arguments.patch)
            except json.JSONDecodeError as error:
                raise settings.SettingsValidationError(
                    f"settings patch is not valid JSON: {error}"
                ) from error
            current = current.update(patch)
            current.save_atomic(path)
        print(json.dumps(current.as_dict(), sort_keys=True))
        return 0
    if arguments.command == "shortcuts":
        manager = shortcuts.ShortcutManager()
        settings_path = settings.default_path()
        manager.recover_reset_transaction(settings_path)
        if arguments.shortcuts_command == "status":
            result = manager.status()
        elif arguments.shortcuts_command == "reconcile":
            result = manager.reconcile_applications()
        elif arguments.shortcuts_command in {"add", "move", "assign", "remove"}:
            try:
                request = json.loads(arguments.request)
            except json.JSONDecodeError as error:
                raise shortcuts.ShortcutValidationError(
                    f"shortcut request is not valid JSON: {error}"
                ) from error
            if not isinstance(request, dict):
                raise shortcuts.ShortcutValidationError(
                    "shortcut request must be a JSON object"
                )
            operation = getattr(manager, arguments.shortcuts_command)
            result = operation(request)
            if arguments.shortcuts_command in {"assign", "remove"}:
                shortcut_status, confirmed_bindings = result
                result = {
                    "shortcuts": shortcut_status,
                    "bindings": [
                        asdict(binding) for binding in confirmed_bindings
                    ],
                }
        else:
            settings_preimage = settings.snapshot_file(settings_path)
            reset_settings = settings.Settings.defaults()

            def commit_settings() -> None:
                try:
                    reset_settings.save_atomic(settings_path)
                except BaseException as error:
                    try:
                        settings.restore_file_snapshot(
                            settings_path,
                            settings_preimage,
                        )
                    except BaseException as restore_error:
                        raise shortcuts.ShortcutMutationError(
                            f"{error}; settings rollback failed: {restore_error}"
                        ) from restore_error
                    raise

            def prepare_reset(shortcut_snapshot: object) -> None:
                manager._write_reset_journal(  # noqa: SLF001 - shared transaction
                    shortcut_snapshot,
                    settings_path,
                    settings_preimage,
                )

            shortcut_status = manager.reset(
                commit_companion=commit_settings,
                finalize_companion=manager._discard_reset_journal,  # noqa: SLF001
                prepare_companion=prepare_reset,
            )
            result = {
                "shortcuts": shortcut_status,
                "settings": reset_settings.as_dict(),
            }
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return 0
    if arguments.command == "catalog":
        discovery = catalog.CatalogDiscovery(
            launcher_path=catalog.DEFAULT_LAUNCHER
        )
        if arguments.catalog_command == "fingerprint":
            result = {
                "version": catalog.CATALOG_VERSION,
                "fingerprint": discovery.fingerprint(),
            }
        else:
            snapshot = discovery.snapshot(arguments.language)
            result = {
                "version": catalog.CATALOG_VERSION,
                "fingerprint": snapshot.fingerprint,
                "items": [
                    {
                        "kind": item.kind,
                        "id": item.id,
                        "title": item.title,
                        "englishTitle": item.english_title,
                        "summary": item.summary,
                        "icon": item.icon,
                        "path": item.path,
                        "keywords": list(item.keywords),
                    }
                    for item in snapshot.items
                ],
                "warnings": list(snapshot.warnings),
            }
        print(json.dumps(result, ensure_ascii=False, sort_keys=True))
        return 0
    if arguments.command == "layout":
        try:
            request = json.loads(arguments.request)
        except json.JSONDecodeError as error:
            raise ValueError(f"layout request is not valid JSON: {error}") from error
        if not isinstance(request, dict):
            raise ValueError("layout request must be a JSON object")
        result = layout.layout_columns(
            request["itemCount"],
            available_height=request["availableHeight"],
            row_height=request.get("rowHeight", 48),
            max_width=request.get("maxWidth", 1800),
            column_width=request.get("columnWidth", 300),
        )
        print(json.dumps(asdict(result), sort_keys=True))
        return 0
    return 2


def entrypoint() -> int:
    try:
        return main()
    except (
        settings.SettingsValidationError,
        catalog.CatalogError,
        shortcuts.ShortcutMutationError,
        shortcuts.ShortcutValidationError,
    ) as error:
        parts = [" ".join(line.split()) for line in str(error).splitlines() if line.strip()]
        message = " | ".join(parts) or "operation failed"
        print(
            json.dumps(
                {
                    "version": 1,
                    "code": error.code,
                    "message": message,
                    "context": error.context,
                },
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2


if __name__ == "__main__":
    raise SystemExit(entrypoint())
