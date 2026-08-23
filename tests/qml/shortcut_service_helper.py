"""Deterministic process boundary used by the shortcut QML service harness."""

from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import time


GROUPS = (
    "SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT",
    "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT", "SUPER+SHIFT+ALT",
    "SUPER+CTRL+SHIFT+ALT",
)
COMMAND_ID = "command:" + "a" * 64


def option(key: str, *, state: str = "free", title: str = "", binding_id: str = "", action_id: str = "") -> dict[str, object]:
    return {"key": key, "state": state, "title": title, "bindingId": binding_id,
            "actionId": action_id,
            "presentationId": "presentation-notes" if binding_id else "",
            "editable": True, "editReason": "",
            "removable": bool(binding_id),
            "removeReason": "" if binding_id else "No shortcut assigned"}


def status(count: int) -> dict[str, object]:
    key_options = {group: [] for group in GROUPS}
    key_options["SUPER"] = [option("N", state="assigned", title="Notes",
        binding_id="binding-notes", action_id="action-notes") if count else option("N")]
    return {
        "version": 3, "managedCount": count,
        "managedBindingIds": ["binding-notes"] if count else [],
        "keyOptionsByGroup": key_options,
        "actions": [{"id": "action-notes", "title": "Notes",
                     "presentationId": "presentation-notes",
                     "labelKey": "", "selectionKind": "command",
                     "selectionId": COMMAND_ID, "titleOverride": "My Notes",
                     "actionKind": "exec", "launchKind": "webapp",
                     "targetId": "webapp:https://notes.example/",
                     "modifiers": ["SUPER"],
                     "key": "N"}] if count else [],
        "discoveryError": "",
    }


def bindings_for(count: int) -> list[dict[str, object]]:
    if not count:
        return []
    return [
        {"id": "binding-notes", "presentation_id": "presentation-notes",
         "modifiers": ["SUPER"], "key": "N",
         "description": "Notes", "dispatcher": "exec", "argument": "/usr/bin/true",
         "mouse": False, "editable": True, "action_kind": "exec",
         "action_argument": "/usr/bin/true", "edit_reason": "",
         "selection_kind": "command", "selection_id": COMMAND_ID,
         "label_key": "", "title_override": "My Notes"},
        {"id": "binding-ctrl", "presentation_id": "presentation-ctrl",
         "modifiers": ["CTRL"], "key": "C",
         "description": "Copy", "dispatcher": "exec", "argument": "copy",
         "mouse": False, "editable": True, "action_kind": "exec",
         "action_argument": "copy", "edit_reason": "", "selection_kind": "",
         "selection_id": "", "label_key": "", "title_override": ""},
        {"id": "binding-alt", "presentation_id": "presentation-alt",
         "modifiers": ["ALT"], "key": "TAB",
         "description": "Switch", "dispatcher": "exec", "argument": "switch",
         "mouse": False, "editable": True, "action_kind": "exec",
         "action_argument": "switch", "edit_reason": "", "selection_kind": "",
         "selection_id": "", "label_key": "", "title_override": ""},
        {"id": "binding-plain", "presentation_id": "presentation-plain",
         "modifiers": [], "key": "F1",
         "description": "Help", "dispatcher": "exec", "argument": "help",
         "mouse": False, "editable": True, "action_kind": "exec",
         "action_argument": "help", "edit_reason": "", "selection_kind": "",
         "selection_id": "", "label_key": "", "title_override": ""},
    ]


def main() -> int:
    arguments = sys.argv[1:]
    log = Path(os.environ["KEYGUIDE_TEST_SHORTCUT_LOG"])
    state_path = log.with_suffix(".state")
    with log.open("a", encoding="utf-8") as output:
        output.write(json.dumps(arguments) + "\n")
    if arguments and arguments[0] == "fail":
        print(json.dumps({
            "version": 1,
            "code": "shortcut.mutation_failed",
            "message": "simulated shortcut mutation failure",
            "context": {},
        }), file=sys.stderr)
        return 9
    mode = ""
    if arguments and arguments[0] in {"malformed-options", "duplicate-actions"}:
        mode = arguments.pop(0)
    operation = arguments[0]
    if operation == "status":
        count = int(state_path.read_text()) if state_path.exists() else 0
        result: object = status(count)
    elif operation == "bindings":
        count = int(state_path.read_text()) if state_path.exists() else 0
        result = bindings_for(count)
    elif operation in {"add", "move"}:
        if len(arguments) != 2:
            raise RuntimeError("mutation request missing")
        json.loads(arguments[1])
        time.sleep(0.12)
        state_path.write_text("1", encoding="utf-8")
        result = status(1)
    elif operation == "assign":
        if len(arguments) != 2:
            raise RuntimeError("assignment request missing")
        request = json.loads(arguments[1])
        expected_request = {
            "targetModifiers": ["SUPER"],
            "targetKey": "N",
            "selectionKind": "command",
            "selectionId": COMMAND_ID,
            "titleOverride": "My Notes",
            "customArguments": "",
            "targetBindingId": "",
            "confirmReplace": False,
        }
        if request != expected_request:
            raise RuntimeError(f"unexpected assignment request: {request!r}")
        time.sleep(0.12)
        state_path.write_text("1", encoding="utf-8")
        result = {"shortcuts": status(1), "bindings": bindings_for(1)}
        if mode == "malformed-options":
            result["shortcuts"]["keyOptionsByGroup"]["SUPER"].append(option("N"))
        elif mode == "duplicate-actions":
            result["shortcuts"]["actions"].append({
                "id": "action-notes", "title": "Duplicate",
                "actionKind": "exec",
                "modifiers": ["SUPER"], "key": "N",
            })
    elif operation == "reset-all":
        state_path.write_text("0", encoding="utf-8")
        result = {
            "shortcuts": status(0),
            "settings": {
                "version": 2,
                "enabled": True,
                "position": "center",
                "scale": 1.0,
                "opacity": 0.94,
                "groups": [
                    "SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT",
                    "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT",
                    "SUPER+SHIFT+ALT", "SUPER+CTRL+SHIFT+ALT",
                ],
                "hiddenBindingIds": [],
                "followTheme": True,
                "language": "en",
            },
        }
    else:
        raise RuntimeError(f"unsupported operation: {operation}")
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
