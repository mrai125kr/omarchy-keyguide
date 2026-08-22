#!/usr/bin/env python3
"""Small deterministic process fixture for the QML catalog lifecycle harness."""

from __future__ import annotations

import json
import sys
import time


def main() -> int:
    operation = sys.argv[1]
    if operation == "fingerprint":
        fingerprint = sys.argv[2]
        delay = float(sys.argv[3]) if len(sys.argv) > 3 else 0
        time.sleep(delay)
        print(json.dumps({"version": 1, "fingerprint": fingerprint}))
        return 0
    if operation == "list":
        payload = sys.argv[2]
        delay = float(sys.argv[3])
        language = sys.argv[4]
        time.sleep(delay)
        print(payload.replace("__LANG__", language))
        return 0
    if operation == "malformed":
        print("{not-json")
        return 0
    if operation == "fail":
        print("catalog fixture failed", file=sys.stderr)
        return 2
    raise ValueError(f"unknown operation: {operation}")


if __name__ == "__main__":
    raise SystemExit(main())
