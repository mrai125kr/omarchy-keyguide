#!/usr/bin/env python3
"""Coordinate deterministic FileView/save races using real atomic settings I/O."""

from __future__ import annotations

import json
from pathlib import Path
import sys
import time

from keyguide_backend.settings import Settings


def wait_for(path: Path) -> None:
    deadline = time.monotonic() + 3.0
    while not path.exists():
        if time.monotonic() >= deadline:
            raise RuntimeError(f"timed out waiting for {path.name}")
        time.sleep(0.01)


def main() -> int:
    operation, *arguments = sys.argv[1:]

    if operation == "read":
        settings_arg, captured_arg, release_arg = arguments
        settings_path = Path(settings_arg)
        captured = Path(captured_arg)
        release = Path(release_arg)
        snapshot = settings_path.read_bytes()
        captured.write_text("captured\n", encoding="utf-8")
        wait_for(release)
        sys.stdout.buffer.write(snapshot)
        return 0

    if operation == "patch":
        settings_arg, patch_arg = arguments
        settings_path = Path(settings_arg)
        patch = json.loads(patch_arg)
        updated = Settings.load(settings_path).update(patch)
        updated.save_atomic(settings_path)
        print(json.dumps(updated.as_dict(), sort_keys=True))
        return 0

    if operation == "external-patch":
        settings_arg, captured_arg, patch_arg = arguments
        settings_path = Path(settings_arg)
        captured = Path(captured_arg)
        patch = json.loads(patch_arg)
        Settings.load(settings_path).update(patch).save_atomic(settings_path)
        wait_for(captured)
        return 0

    if operation == "hold-patch":
        settings_arg, written_arg, release_arg, patch_arg = arguments
        settings_path = Path(settings_arg)
        written = Path(written_arg)
        release = Path(release_arg)
        patch = json.loads(patch_arg)
        updated = Settings.load(settings_path).update(patch)
        updated.save_atomic(settings_path)
        written.write_text("written\n", encoding="utf-8")
        wait_for(release)
        print(json.dumps(updated.as_dict(), sort_keys=True))
        return 0

    if operation == "release":
        (release_arg,) = arguments
        Path(release_arg).write_text("release\n", encoding="utf-8")
        return 0

    raise RuntimeError(f"unknown operation: {operation}")


if __name__ == "__main__":
    raise SystemExit(main())
