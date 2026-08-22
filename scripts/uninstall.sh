#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "uninstall: $*" >&2
  exit 1
}

project_root=$(realpath -m -- "$(dirname -- "${BASH_SOURCE[0]}")/..")
source "$project_root/scripts/live-session-safety.sh"

[[ ${HOME:-} == /* && $HOME != / ]] || fail "HOME must be an absolute user directory"

prefix_root=${PREFIX_ROOT:-}
remove_preferences=${REMOVE_PREFERENCES:-0}
preserve_upgrade=${KEYGUIDE_PRESERVE_UPGRADE:-0}
expected_plugin_was_enabled=${KEYGUIDE_EXPECTED_PLUGIN_WAS_ENABLED:-}
expected_upgrade_handoff_token=${KEYGUIDE_UPGRADE_HANDOFF_TOKEN:-}
validate_only=${KEYGUIDE_VALIDATE_ONLY:-0}
[[ $remove_preferences == 0 || $remove_preferences == 1 ]] ||
  fail "REMOVE_PREFERENCES must be 0 or 1"
[[ $preserve_upgrade == 0 || $preserve_upgrade == 1 ]] ||
  fail "KEYGUIDE_PRESERVE_UPGRADE must be 0 or 1"
[[ $validate_only == 0 || $validate_only == 1 ]] ||
  fail "KEYGUIDE_VALIDATE_ONLY must be 0 or 1"
[[ -z $expected_plugin_was_enabled || $expected_plugin_was_enabled == true || $expected_plugin_was_enabled == false ]] ||
  fail "KEYGUIDE_EXPECTED_PLUGIN_WAS_ENABLED must be true or false"
[[ -z $expected_upgrade_handoff_token || $expected_upgrade_handoff_token =~ ^[0-9a-f]{64}$ ]] ||
  fail "KEYGUIDE_UPGRADE_HANDOFF_TOKEN must be a SHA-256 token"
if [[ -n $prefix_root ]]; then
  [[ $prefix_root == /* && $prefix_root != / ]] ||
    fail "PREFIX_ROOT must be an absolute directory other than /"
  prefix_root=$(realpath -m -- "$prefix_root")
  target_home=$(realpath -m -- "${prefix_root}${HOME}")
  [[ $target_home == "$prefix_root"/* ]] || fail "target home escapes PREFIX_ROOT"
else
  target_home=$(realpath -m -- "$HOME")
fi

lib_dir="$target_home/.local/lib/omarchy-keyguide"
plugin_dir="$target_home/.config/omarchy/plugins/mrai.keyguide"
apps_dir="$target_home/.local/share/applications"
xdg_data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
[[ $xdg_data_home == /* && $xdg_data_home != / ]] ||
  fail "XDG_DATA_HOME must be an absolute user directory"
if [[ -n $prefix_root ]]; then
  data_dir=$(realpath -m -- "${prefix_root}${xdg_data_home}")
else
  data_dir=$(realpath -m -- "$xdg_data_home")
fi
[[ $data_dir == "$target_home"/* ]] || fail "XDG_DATA_HOME escapes target home"
icon_dir="$data_dir/icons/hicolor/scalable/apps"
state_dir="$target_home/.local/state/omarchy-keyguide"
manifest_path="$state_dir/install-manifest.json"
shell_config="$target_home/.config/omarchy/shell.json"

owned_files=(
  "$lib_dir/bin/keyguide-observer"
  "$lib_dir/keyguide_backend/__init__.py"
  "$lib_dir/keyguide_backend/__main__.py"
  "$lib_dir/keyguide_backend/bindings.py"
  "$lib_dir/keyguide_backend/catalog.py"
  "$lib_dir/keyguide_backend/compat.py"
  "$lib_dir/keyguide_backend/groups.py"
  "$lib_dir/keyguide_backend/layout.py"
  "$lib_dir/keyguide_backend/presentation.py"
  "$lib_dir/keyguide_backend/settings.py"
  "$lib_dir/keyguide_backend/shortcuts.py"
  "$plugin_dir/manifest.json"
  "$plugin_dir/ActionSearchModel.js"
  "$plugin_dir/BarWidget.qml"
  "$plugin_dir/Hud.qml"
  "$plugin_dir/HudModel.js"
  "$plugin_dir/I18n.js"
  "$plugin_dir/Service.qml"
  "$plugin_dir/Settings.qml"
  "$plugin_dir/VisibilityModel.js"
  "$plugin_dir/components/BindingRow.qml"
  "$plugin_dir/components/ActionSearch.qml"
  "$plugin_dir/components/ExecutablePicker.qml"
  "$plugin_dir/components/HudPreview.qml"
  "$plugin_dir/components/ShortcutEditRow.qml"
  "$icon_dir/omarchy-keyguide.svg"
  "$apps_dir/omarchy-keyguide-settings.desktop"
)

resolved_manifest=$(realpath -m -- "$manifest_path")
[[ $resolved_manifest == "$target_home"/* ]] ||
  fail "manifest path escapes target home: $manifest_path"

if [[ ! -f $manifest_path ]]; then
  echo "Omarchy Keyguide is not installed: $manifest_path"
  exit 0
fi

manifest_validation=$(python3 - \
  "$manifest_path" \
  "$prefix_root" \
  "$target_home" \
  "$preserve_upgrade" \
  "$expected_plugin_was_enabled" \
  "$expected_upgrade_handoff_token" \
  "${owned_files[@]}" \
  -- \
  "$@" <<'PY'
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

arguments = sys.argv[1:]
try:
    separator = arguments.index("--")
except ValueError as error:
    raise SystemExit("invalid validator invocation: missing separator") from error

(
    manifest_arg,
    prefix_root,
    target_home_arg,
    preserve_upgrade_arg,
    expected_plugin_was_enabled,
    expected_upgrade_handoff_token,
    *expected_files,
) = arguments[:separator]
expected_upgrade_reservations = arguments[separator + 1:]
manifest = Path(manifest_arg)
target_home = Path(target_home_arg)
preserve_upgrade = preserve_upgrade_arg == "1"

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate manifest key: {key}")
        result[key] = value
    return result

def json_equal(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(
            json_equal(left[key], right[key]) for key in left
        )
    if isinstance(left, list):
        return len(left) == len(right) and all(
            json_equal(left_item, right_item)
            for left_item, right_item in zip(left, right)
        )
    return left == right

try:
    manifest_bytes = manifest.read_bytes()
    document = json.loads(
        manifest_bytes.decode("utf-8"), object_pairs_hook=unique_object
    )
except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
    raise SystemExit(f"invalid install manifest: {error}")

if not isinstance(document, dict):
    raise SystemExit("invalid install manifest: document must be an object")
if type(document.get("schema_version")) is not int or document["schema_version"] != 1:
    raise SystemExit("invalid install manifest: unsupported schema")
if document.get("plugin_id") != "mrai.keyguide":
    raise SystemExit("invalid install manifest: wrong plugin id")
if document.get("prefix_root") != prefix_root:
    raise SystemExit("invalid install manifest: PREFIX_ROOT mismatch")
if document.get("target_home") != target_home_arg:
    raise SystemExit("invalid install manifest: target home mismatch")
if type(document.get("plugin_was_enabled")) is not bool:
    raise SystemExit("invalid install manifest: plugin_was_enabled must be boolean")
if expected_plugin_was_enabled and document["plugin_was_enabled"] != (
    expected_plugin_was_enabled == "true"
):
    raise SystemExit("invalid install manifest: prior plugin state changed during upgrade")
if type(document.get("plugin_enabled_by_installer")) is not bool:
    raise SystemExit(
        "invalid install manifest: plugin_enabled_by_installer must be boolean"
    )
if document["plugin_was_enabled"] and document["plugin_enabled_by_installer"]:
    raise SystemExit("invalid install manifest: contradictory plugin state")
shell_config_state = document.get("shell_config")
legacy_shell_keys = {
    "preexisting", "backup_path", "post_enable_sha256", "post_enable_present", "pre_mode"
}
placement_shell_keys = legacy_shell_keys | {"bar_placement_owned_by_installer"}
current_shell_keys = placement_shell_keys | {"pre_sha256", "restore_state"}
latest_shell_keys = current_shell_keys | {"bar_placement_state"}
staged_shell_fields = {"bar_staging_path", "bar_staging_sha256", "bar_staging_mode"}
staged_latest_shell_keys = latest_shell_keys | staged_shell_fields
owned_placement_shell_keys = placement_shell_keys | {"pre_uid", "pre_gid"}
owned_current_shell_keys = current_shell_keys | {"pre_uid", "pre_gid"}
owned_shell_keys = latest_shell_keys | {"pre_uid", "pre_gid"}
owned_staged_shell_keys = owned_shell_keys | staged_shell_fields
if not isinstance(shell_config_state, dict) or set(shell_config_state) not in (
    legacy_shell_keys,
    placement_shell_keys,
    current_shell_keys,
    latest_shell_keys,
    staged_latest_shell_keys,
    owned_placement_shell_keys,
    owned_current_shell_keys,
    owned_shell_keys,
    owned_staged_shell_keys,
):
    raise SystemExit("invalid install manifest: malformed shell config ownership")
if type(shell_config_state["preexisting"]) is not bool:
    raise SystemExit("invalid install manifest: shell preexisting must be boolean")
expected_backup = str(target_home / ".local/state/omarchy-keyguide/shell.json.pre-keyguide")
if shell_config_state["backup_path"] not in {"", expected_backup}:
    raise SystemExit("invalid install manifest: shell backup path mismatch")
if shell_config_state["preexisting"] != bool(shell_config_state["backup_path"]):
    raise SystemExit("invalid install manifest: inconsistent shell pre-image metadata")
if not isinstance(shell_config_state["post_enable_sha256"], str) or (
    shell_config_state["post_enable_sha256"]
    and not re.fullmatch(r"[0-9a-f]{64}", shell_config_state["post_enable_sha256"])
):
    raise SystemExit("invalid install manifest: malformed shell post-image hash")
if type(shell_config_state["post_enable_present"]) is not bool:
    raise SystemExit("invalid install manifest: shell post-image presence must be boolean")
if shell_config_state["post_enable_present"] != bool(shell_config_state["post_enable_sha256"]):
    raise SystemExit("invalid install manifest: inconsistent shell post-image state")
if not isinstance(shell_config_state["pre_mode"], str) or (
    shell_config_state["pre_mode"] and not re.fullmatch(r"[0-7]{3,4}", shell_config_state["pre_mode"])
):
    raise SystemExit("invalid install manifest: malformed shell pre-image mode")
shell_pre_sha256 = shell_config_state.get("pre_sha256", "")
if not isinstance(shell_pre_sha256, str) or (
    shell_pre_sha256 and not re.fullmatch(r"[0-9a-f]{64}", shell_pre_sha256)
):
    raise SystemExit("invalid install manifest: malformed shell pre-image hash")
shell_pre_uid = shell_config_state.get("pre_uid")
shell_pre_gid = shell_config_state.get("pre_gid")
if shell_pre_uid is not None and (
    type(shell_pre_uid) is not int or shell_pre_uid < 0
):
    raise SystemExit("invalid install manifest: malformed shell pre-image owner")
if shell_pre_gid is not None and (
    type(shell_pre_gid) is not int or shell_pre_gid < 0
):
    raise SystemExit("invalid install manifest: malformed shell pre-image owner")
if shell_config_state["preexisting"] != (shell_pre_uid is not None):
    if shell_pre_uid is not None or shell_pre_gid is not None:
        raise SystemExit("invalid install manifest: inconsistent shell pre-image owner")
if (shell_pre_uid is None) != (shell_pre_gid is None):
    raise SystemExit("invalid install manifest: inconsistent shell pre-image owner")
if set(shell_config_state) in (
    current_shell_keys,
    latest_shell_keys,
    staged_latest_shell_keys,
    owned_current_shell_keys,
    owned_shell_keys,
    owned_staged_shell_keys,
):
    if shell_config_state["preexisting"] != bool(shell_config_state["pre_mode"]) or (
        shell_config_state["preexisting"] != bool(shell_pre_sha256)
    ):
        raise SystemExit("invalid install manifest: inconsistent shell pre-image metadata")
elif shell_config_state["preexisting"] != bool(shell_config_state["pre_mode"]):
    raise SystemExit("invalid install manifest: inconsistent shell pre-image metadata")
shell_restore_state = shell_config_state.get("restore_state", "not_started")
if shell_restore_state not in {"not_started", "restoring", "restored"}:
    raise SystemExit("invalid install manifest: unknown shell restore state")
if shell_config_state["preexisting"] and shell_pre_uid is not None:
    backup_owner_path = Path(shell_config_state["backup_path"])
    try:
        backup_owner_info = backup_owner_path.stat()
    except OSError as error:
        if (
            isinstance(error, FileNotFoundError)
            and document.get("install_state") == "installing"
            and document.get("owned_files") == []
        ):
            backup_owner_info = None
        else:
            raise SystemExit(
                f"invalid install manifest: could not authenticate shell pre-image owner: {error}"
            ) from error
    if backup_owner_info is not None and (
        backup_owner_info.st_uid != shell_pre_uid
        or backup_owner_info.st_gid != shell_pre_gid
    ):
        raise SystemExit(
            "invalid install manifest: shell pre-image owner does not match backup"
        )
    shell_owner_path = target_home / ".config/omarchy/shell.json"
    if shell_owner_path.exists():
        try:
            shell_owner_info = shell_owner_path.stat()
        except OSError as error:
            raise SystemExit(
                f"invalid install manifest: could not authenticate live shell owner: {error}"
            ) from error
        if (
            shell_owner_info.st_uid != shell_pre_uid
            or shell_owner_info.st_gid != shell_pre_gid
        ):
            raise SystemExit(
                "invalid install manifest: shell pre-image owner does not match live shell"
            )
bar_placement_owned_by_installer = shell_config_state.get(
    "bar_placement_owned_by_installer", False
)
if type(bar_placement_owned_by_installer) is not bool:
    raise SystemExit("invalid install manifest: bar placement ownership must be boolean")
bar_placement_state = shell_config_state.get(
    "bar_placement_state",
    "placed" if bar_placement_owned_by_installer else "not_started",
)
if bar_placement_state not in {
    "not_started", "preexisting", "placing", "placed", "restored"
}:
    raise SystemExit("invalid install manifest: unknown bar placement state")
if bar_placement_owned_by_installer != (bar_placement_state == "placed"):
    raise SystemExit("invalid install manifest: inconsistent bar placement state")
if bar_placement_owned_by_installer and not shell_config_state["post_enable_present"]:
    raise SystemExit("invalid install manifest: owned bar placement lacks a post-image")
bar_staging_path = shell_config_state.get("bar_staging_path", "")
bar_staging_sha256 = shell_config_state.get("bar_staging_sha256", "")
bar_staging_mode = shell_config_state.get("bar_staging_mode", "")
if not all(
    isinstance(value, str)
    for value in (bar_staging_path, bar_staging_sha256, bar_staging_mode)
):
    raise SystemExit("invalid install manifest: malformed staged bar output")
if bool(bar_staging_path) != bool(bar_staging_sha256) or bool(bar_staging_path) != bool(bar_staging_mode):
    raise SystemExit("invalid install manifest: inconsistent staged bar output")
if bar_staging_path:
    expected_staging = (
        target_home
        / ".local/state/omarchy-keyguide/bar-placement-home/.config/omarchy/shell.json"
    )
    if Path(bar_staging_path) != expected_staging:
        raise SystemExit("invalid install manifest: staged bar path mismatch")
    if not re.fullmatch(r"[0-9a-f]{64}", bar_staging_sha256) or not re.fullmatch(
        r"[0-7]{3,4}", bar_staging_mode
    ):
        raise SystemExit("invalid install manifest: malformed staged bar output")
    if not (bar_placement_state in {"placing", "placed"}):
        raise SystemExit("invalid install manifest: staged bar output is not active")
placing_recovery = "none"
placing_post_sha256 = ""
if bar_placement_state == "placing":
    if prefix_root:
        raise SystemExit("invalid install manifest: prefixed install has a placing bar intent")
    shell_path = target_home / ".config/omarchy/shell.json"
    backup_path = Path(expected_backup)
    try:
        shell_info = shell_path.lstat()
    except FileNotFoundError:
        shell_info = None
    exact_preimage = False
    if shell_config_state["preexisting"]:
        if shell_info is not None and stat.S_ISREG(shell_info.st_mode):
            try:
                live_bytes = shell_path.read_bytes()
            except OSError as error:
                raise SystemExit(
                    f"invalid install manifest: could not read placing shell state: {error}"
                ) from error
            exact_preimage = (
                hashlib.sha256(live_bytes).hexdigest() == shell_pre_sha256
                and stat.S_IMODE(shell_info.st_mode)
                == int(shell_config_state["pre_mode"], 8)
            )
    else:
        exact_preimage = shell_info is None

    if exact_preimage:
        placing_recovery = "preimage"
    elif not shell_config_state["preexisting"] and bar_staging_path:
        staging_path = Path(bar_staging_path)
        try:
            staging_info = staging_path.lstat()
            if shell_info is None:
                raise FileNotFoundError(shell_path)
        except FileNotFoundError as error:
            raise SystemExit(
                "invalid install manifest: staged placing bar output is unavailable"
            ) from error
        if not stat.S_ISREG(shell_info.st_mode) or not stat.S_ISREG(staging_info.st_mode):
            raise SystemExit(
                "invalid install manifest: staged placing bar output requires regular files"
            )
        if (shell_info.st_dev, shell_info.st_ino) != (
            staging_info.st_dev,
            staging_info.st_ino,
        ):
            raise SystemExit(
                "invalid install manifest: staged placing bar output was not published"
            )
        if stat.S_IMODE(shell_info.st_mode) != int(bar_staging_mode, 8):
            raise SystemExit(
                "invalid install manifest: staged placing bar output changed mode"
            )
        try:
            live_bytes = shell_path.read_bytes()
            staging_bytes = staging_path.read_bytes()
        except OSError as error:
            raise SystemExit(
                f"invalid install manifest: could not read staged placing bar output: {error}"
            ) from error
        if live_bytes != staging_bytes:
            raise SystemExit(
                "invalid install manifest: staged placing bar output changed bytes"
            )
        if hashlib.sha256(live_bytes).hexdigest() != bar_staging_sha256:
            raise SystemExit(
                "invalid install manifest: staged placing bar output is unauthenticated"
            )
        placing_recovery = "insertion"
        placing_post_sha256 = bar_staging_sha256
    elif shell_config_state["preexisting"]:
        try:
            backup_info = backup_path.lstat()
            if shell_info is None:
                raise FileNotFoundError(shell_path)
        except FileNotFoundError as error:
            raise SystemExit(
                "invalid install manifest: placing bar transform state is unavailable"
            ) from error
        if not stat.S_ISREG(shell_info.st_mode) or not stat.S_ISREG(backup_info.st_mode):
            raise SystemExit(
                "invalid install manifest: placing bar transform requires regular files"
            )
        if stat.S_IMODE(shell_info.st_mode) != int(
            shell_config_state["pre_mode"], 8
        ):
            raise SystemExit(
                "invalid install manifest: placing bar transform changed shell mode"
            )
        try:
            live_bytes = shell_path.read_bytes()
            backup_bytes = backup_path.read_bytes()
        except OSError as error:
            raise SystemExit(
                f"invalid install manifest: could not read placing bar transform: {error}"
            ) from error
        if hashlib.sha256(backup_bytes).hexdigest() != shell_pre_sha256:
            raise SystemExit(
                "invalid install manifest: placing bar transform backup is unauthenticated"
            )
        try:
            live_document = json.loads(
                live_bytes.decode("utf-8"), object_pairs_hook=unique_object
            )
            backup_document = json.loads(
                backup_bytes.decode("utf-8"), object_pairs_hook=unique_object
            )
        except (UnicodeError, ValueError, json.JSONDecodeError) as error:
            raise SystemExit(
                f"invalid install manifest: malformed placing bar transform: {error}"
            ) from error
        if not isinstance(live_document, dict) or not isinstance(backup_document, dict):
            raise SystemExit(
                "invalid install manifest: placing bar transform must contain objects"
            )
        candidate = copy.deepcopy(live_document)
        bar = candidate.get("bar")
        layout = bar.get("layout") if isinstance(bar, dict) else None
        if not isinstance(layout, dict):
            raise SystemExit(
                "invalid install manifest: placing bar transform lacks a layout"
            )
        locations = []
        for section in ("left", "center", "right"):
            entries = layout.get(section)
            if not isinstance(entries, list):
                raise SystemExit(
                    "invalid install manifest: placing bar transform has a malformed section"
                )
            for index, entry in enumerate(entries):
                entry_id = entry.get("id") if isinstance(entry, dict) else entry
                if entry_id == "mrai.keyguide":
                    locations.append((index, entries, entry))
        if len(locations) != 1:
            raise SystemExit(
                "invalid install manifest: placing bar transform is not a unique insertion"
            )
        index, entries, entry = locations[0]
        predecessor = entries[index - 1] if index > 0 else None
        predecessor_id = (
            predecessor.get("id") if isinstance(predecessor, dict) else predecessor
        )
        canonical_insertion = (
            entry == {"id": "mrai.keyguide"}
            and predecessor_id == "omarchy.agents"
        )
        enable_inserted = (
            entry == {"id": "mrai.keyguide"}
            and document.get("plugin_enable_state") == "enabling"
        )
        if not canonical_insertion and not enable_inserted:
            raise SystemExit(
                "invalid install manifest: placing bar transform is not canonical and anchored"
            )
        del entries[index]
        if not json_equal(candidate, backup_document):
            raise SystemExit(
                "invalid install manifest: placing bar transform changed unrelated state"
            )
        placing_recovery = "insertion"
        placing_post_sha256 = hashlib.sha256(live_bytes).hexdigest()
    else:
        raise SystemExit(
            "invalid install manifest: placing bar transform cannot reconstruct an absent pre-image"
        )
shell_owned = (
    document["plugin_enabled_by_installer"]
    or bar_placement_owned_by_installer
    or bar_placement_state == "placing"
)
legacy_preimage_migration = False
if (
    shell_config_state["preexisting"]
    and shell_owned
    and not shell_pre_sha256
    and not preserve_upgrade
):
    if prefix_root:
        raise SystemExit("invalid install manifest: prefixed shell pre-image is unauthenticated")
    shell_path = target_home / ".config/omarchy/shell.json"
    backup_path = Path(expected_backup)
    try:
        shell_info = shell_path.lstat()
        backup_info = backup_path.lstat()
    except FileNotFoundError as error:
        raise SystemExit(
            "invalid install manifest: legacy shell migration state is unavailable"
        ) from error
    if not stat.S_ISREG(shell_info.st_mode) or not stat.S_ISREG(backup_info.st_mode):
        raise SystemExit(
            "invalid install manifest: legacy shell migration requires regular files"
        )
    try:
        live_bytes = shell_path.read_bytes()
        backup_bytes = backup_path.read_bytes()
    except OSError as error:
        raise SystemExit(
            f"invalid install manifest: could not read legacy shell state: {error}"
        ) from error
    if shell_config_state["post_enable_sha256"] != hashlib.sha256(live_bytes).hexdigest():
        raise SystemExit(
            "invalid install manifest: legacy live shell does not match authenticated post-image"
        )
    try:
        live_document = json.loads(
            live_bytes.decode("utf-8"), object_pairs_hook=unique_object
        )
        backup_document = json.loads(
            backup_bytes.decode("utf-8"), object_pairs_hook=unique_object
        )
    except (UnicodeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(
            f"invalid install manifest: malformed legacy shell document: {error}"
        ) from error
    if not isinstance(live_document, dict) or not isinstance(backup_document, dict):
        raise SystemExit(
            "invalid install manifest: legacy shell documents must be objects"
        )
    candidate = copy.deepcopy(live_document)
    owned_difference = False
    if document["plugin_enabled_by_installer"]:
        plugins = candidate.get("plugins")
        if not isinstance(plugins, list):
            raise SystemExit(
                "invalid install manifest: legacy shell plugins must be an array"
            )
        plugin_indexes = [index for index, plugin in enumerate(plugins) if (
            plugin == "mrai.keyguide" or (
                isinstance(plugin, dict) and plugin.get("id") == "mrai.keyguide"
            )
        )]
        if plugin_indexes:
            raise SystemExit(
                "invalid install manifest: unexpected legacy Keyguide plugin entry"
            )
    if bar_placement_owned_by_installer:
        bar = candidate.get("bar")
        layout = bar.get("layout") if isinstance(bar, dict) else None
        if not isinstance(layout, dict):
            raise SystemExit(
                "invalid install manifest: legacy shell bar layout is unavailable"
            )
        locations = []
        for section in ("left", "center", "right"):
            entries = layout.get(section)
            if not isinstance(entries, list):
                raise SystemExit(
                    "invalid install manifest: legacy shell bar section is not an array"
                )
            for index, entry in enumerate(entries):
                entry_id = entry.get("id") if isinstance(entry, dict) else entry
                if entry_id == "mrai.keyguide":
                    locations.append((section, index, entries))
        if len(locations) != 1:
            raise SystemExit(
                "invalid install manifest: legacy shell requires one owned bar placement"
            )
        section, index, entries = locations[0]
        predecessor = entries[index - 1] if index > 0 else None
        predecessor_id = (
            predecessor.get("id") if isinstance(predecessor, dict) else predecessor
        )
        if predecessor_id != "omarchy.agents":
            raise SystemExit(
                "invalid install manifest: legacy owned bar placement is not after Agents"
            )
        del entries[index]
        owned_difference = True
    # The deployed placement-era installer moved the canonical third-party
    # entry from plugins[] to bar.layout.  Reconstruct every possible original
    # list position and authenticate only an exact endpoint; never infer a hash
    # from a looser subset or field comparison.  A later installer can own only
    # the bar insertion, so the bar-restored candidate is also valid.
    candidates = [(candidate, owned_difference)]
    if document["plugin_enabled_by_installer"]:
        plugins = candidate["plugins"]
        for index in range(len(plugins) + 1):
            plugin_candidate = copy.deepcopy(candidate)
            plugin_candidate["plugins"].insert(index, {"id": "mrai.keyguide"})
            candidates.append((plugin_candidate, True))
    matches = [
        candidate_document
        for candidate_document, has_owned_difference in candidates
        if has_owned_difference and json_equal(
            candidate_document, backup_document
        )
    ]
    if len(matches) != 1:
        raise SystemExit(
            "invalid install manifest: legacy shell pre-image is not structurally derived"
        )
    shell_pre_sha256 = hashlib.sha256(backup_bytes).hexdigest()
    shell_restore_state = "not_started"
    shell_config_state["bar_placement_owned_by_installer"] = (
        bar_placement_owned_by_installer
    )
    shell_config_state["pre_sha256"] = shell_pre_sha256
    shell_config_state["restore_state"] = shell_restore_state
    legacy_preimage_migration = True
if shell_restore_state == "restoring" and not shell_owned:
    raise SystemExit("invalid install manifest: restoring shell state is not owned")
if shell_restore_state == "restored" and shell_owned:
    raise SystemExit("invalid install manifest: restored shell state is still owned")
install_state = document.get("install_state")
allowed_install_states = {
    "installing", "installed", "restart_pending", "upgrade_ready"
}
if preserve_upgrade:
    allowed_install_states.add("rebasing")
if install_state not in allowed_install_states:
    raise SystemExit("invalid install manifest: unknown install state")
plugin_enable_state = document.get("plugin_enable_state")
if plugin_enable_state not in {
    "skipped",
    "preexisting",
    "not_started",
    "enabling",
    "enable_failed",
    "enabled",
    "disabled",
}:
    raise SystemExit("invalid install manifest: unknown plugin enable state")
if document["plugin_enabled_by_installer"] != (plugin_enable_state == "enabled"):
    raise SystemExit("invalid install manifest: inconsistent plugin ownership")
if document["plugin_was_enabled"] != (plugin_enable_state == "preexisting"):
    raise SystemExit("invalid install manifest: inconsistent prior plugin state")
if prefix_root and plugin_enable_state != "skipped":
    raise SystemExit("invalid install manifest: prefixed install has live plugin state")
if prefix_root and bar_placement_owned_by_installer:
    raise SystemExit("invalid install manifest: prefixed install owns a live bar placement")
if install_state in {"restart_pending", "upgrade_ready"} and (
    document["plugin_enabled_by_installer"]
    or bar_placement_owned_by_installer
    or bar_placement_state == "placing"
):
    raise SystemExit("invalid install manifest: restart-pending shell state is still owned")

owned_files = document.get("owned_files")
if not isinstance(owned_files, list):
    raise SystemExit("invalid install manifest: owned files must be a list")

def without_current_suffixes(*suffixes):
    return [
        path
        for path in expected_files
        if not any(path.endswith(suffix) for suffix in suffixes)
    ]


localized_search_suffixes = (
    "/keyguide_backend/catalog.py",
    "/mrai.keyguide/ActionSearchModel.js",
    "/mrai.keyguide/I18n.js",
    "/mrai.keyguide/components/ActionSearch.qml",
)


pre_localized_search_files = without_current_suffixes(
    *localized_search_suffixes,
)

pre_executable_picker_files = without_current_suffixes(
    *localized_search_suffixes,
    "/mrai.keyguide/components/ExecutablePicker.qml",
)
pre_shortcut_editor_files = without_current_suffixes(
    *localized_search_suffixes,
    "/keyguide_backend/shortcuts.py",
    "/mrai.keyguide/components/ShortcutEditRow.qml",
    "/mrai.keyguide/components/ExecutablePicker.qml",
)
pre_visibility_model_files = without_current_suffixes(
    *localized_search_suffixes,
    "/keyguide_backend/shortcuts.py",
    "/mrai.keyguide/components/ShortcutEditRow.qml",
    "/mrai.keyguide/VisibilityModel.js",
    "/mrai.keyguide/components/ExecutablePicker.qml",
)
pre_icon_files = without_current_suffixes(
    *localized_search_suffixes,
    "/keyguide_backend/shortcuts.py",
    "/mrai.keyguide/components/ShortcutEditRow.qml",
    "/mrai.keyguide/VisibilityModel.js",
    "/icons/hicolor/scalable/apps/omarchy-keyguide.svg",
    "/mrai.keyguide/components/ExecutablePicker.qml",
)
pre_dependency_files = without_current_suffixes(
    *localized_search_suffixes,
    "/keyguide_backend/shortcuts.py",
    "/mrai.keyguide/components/ShortcutEditRow.qml",
    "/keyguide_backend/groups.py",
    "/keyguide_backend/presentation.py",
    "/mrai.keyguide/VisibilityModel.js",
    "/icons/hicolor/scalable/apps/omarchy-keyguide.svg",
    "/mrai.keyguide/components/ExecutablePicker.qml",
)
pre_complete_hud_files = without_current_suffixes(
    *localized_search_suffixes,
    "/keyguide_backend/shortcuts.py",
    "/mrai.keyguide/components/ShortcutEditRow.qml",
    "/keyguide_backend/groups.py",
    "/keyguide_backend/presentation.py",
    "/mrai.keyguide/BarWidget.qml",
    "/mrai.keyguide/VisibilityModel.js",
    "/icons/hicolor/scalable/apps/omarchy-keyguide.svg",
    "/mrai.keyguide/components/ExecutablePicker.qml",
)
expected_plans = (
    expected_files,
    pre_localized_search_files,
    pre_executable_picker_files,
    pre_shortcut_editor_files,
    pre_visibility_model_files,
    pre_icon_files,
    pre_dependency_files,
    pre_complete_hud_files,
)
trusted_upgrade_reservation_plans = []
for plan in expected_plans:
    sequence = [path for path in expected_files if path not in plan]
    if sequence not in trusted_upgrade_reservation_plans:
        trusted_upgrade_reservation_plans.append(sequence)
retained_visibility_sequence = [
    path for path in expected_files if path.endswith("/mrai.keyguide/VisibilityModel.js")
]
if (
    retained_visibility_sequence
    and retained_visibility_sequence not in trusted_upgrade_reservation_plans
):
    trusted_upgrade_reservation_plans.append(retained_visibility_sequence)
if install_state == "installed":
    if not any(owned_files == plan for plan in expected_plans):
        raise SystemExit("invalid install manifest: installed file list mismatch")
elif install_state in {"restart_pending", "upgrade_ready"}:
    if owned_files:
        raise SystemExit(
            "invalid install manifest: completed removal file list is not empty"
        )
elif not any(owned_files == plan[: len(owned_files)] for plan in expected_plans):
    raise SystemExit("invalid install manifest: install journal is not an exact prefix")

pending = document.get("pending_reservation")
pending_uses_upgrade_temporary = False
if pending is not None:
    if document["install_state"] != "installing":
        raise SystemExit("invalid install manifest: installed state has a reservation")
    legacy_pending_keys = {"path", "token", "temporary_path"}
    payload_pending_keys = legacy_pending_keys | {
        "payload_sha256", "payload_mode"
    }
    if not isinstance(pending, dict) or frozenset(pending) not in {
        frozenset(legacy_pending_keys), frozenset(payload_pending_keys)
    }:
        raise SystemExit("invalid install manifest: malformed pending reservation")
    matching_plans = [
        plan for plan in expected_plans if owned_files == plan[: len(owned_files)]
    ]
    if not matching_plans or all(len(owned_files) >= len(plan) for plan in matching_plans):
        raise SystemExit("invalid install manifest: reservation exceeds planned files")
    if not any(
        len(owned_files) < len(plan)
        and pending["path"] == plan[len(owned_files)]
        for plan in matching_plans
    ):
        raise SystemExit("invalid install manifest: reservation is not the next path")
    if not isinstance(pending["token"], str) or not re.fullmatch(
        r"[0-9a-f]{64}", pending["token"]
    ):
        raise SystemExit("invalid install manifest: malformed reservation token")
    pending_path = Path(pending["path"])
    expected_temporary = pending_path.with_name(
        f".{pending_path.name}.keyguide-reservation-{pending['token']}.tmp"
    )
    pending_uses_upgrade_temporary = (
        pending["temporary_path"] != str(expected_temporary)
    )
    if "payload_sha256" in pending:
        expected_payload_mode = 0o755 if pending["path"] == expected_files[0] else 0o644
        if (
            not isinstance(pending["payload_sha256"], str)
            or not re.fullmatch(r"[0-9a-f]{64}", pending["payload_sha256"])
            or type(pending["payload_mode"]) is not int
            or pending["payload_mode"] != expected_payload_mode
        ):
            raise SystemExit(
                "invalid install manifest: malformed reservation payload"
            )

file_removal = document.get("file_removal")
if file_removal is not None:
    if not isinstance(file_removal, dict) or set(file_removal) != {
        "token", "targets"
    }:
        raise SystemExit("invalid install manifest: malformed file removal journal")
    if not isinstance(file_removal["token"], str) or not re.fullmatch(
        r"[0-9a-f]{64}", file_removal["token"]
    ):
        raise SystemExit("invalid install manifest: malformed file removal token")
    if install_state == "restart_pending":
        raise SystemExit(
            "invalid install manifest: restart-pending state retains file removal"
        )
    allowed_removal_paths = list(owned_files)
    if pending is not None:
        allowed_removal_paths.extend((pending["path"], pending["temporary_path"]))
    targets = file_removal["targets"]
    if not isinstance(targets, list):
        raise SystemExit("invalid install manifest: malformed file removal targets")
    observed_paths = []
    for target in targets:
        if not isinstance(target, dict) or set(target) != {
            "path",
            "sha256",
            "mode",
            "device",
            "inode",
            "size",
            "mtime_ns",
        }:
            raise SystemExit(
                "invalid install manifest: malformed file removal target"
            )
        if target["path"] not in allowed_removal_paths:
            raise SystemExit(
                "invalid install manifest: unexpected file removal target"
            )
        if target["path"] in observed_paths:
            raise SystemExit(
                "invalid install manifest: duplicate file removal target"
            )
        observed_paths.append(target["path"])
        if not isinstance(target["sha256"], str) or not re.fullmatch(
            r"[0-9a-f]{64}", target["sha256"]
        ):
            raise SystemExit(
                "invalid install manifest: malformed file removal hash"
            )
        for key in ("mode", "device", "inode", "size", "mtime_ns"):
            if type(target[key]) is not int or target[key] < 0:
                raise SystemExit(
                    "invalid install manifest: malformed file removal identity"
                )
    expected_order = [
        path for path in allowed_removal_paths if path in observed_paths
    ]
    if observed_paths != expected_order:
        raise SystemExit(
            "invalid install manifest: reordered file removal targets"
        )

upgrade_handoff = document.get("upgrade_handoff")
if upgrade_handoff is not None:
    if not isinstance(upgrade_handoff, dict) or set(upgrade_handoff) != {
        "schema_version", "token", "reservations"
    }:
        raise SystemExit("invalid install manifest: malformed upgrade handoff")
    if (
        type(upgrade_handoff["schema_version"]) is not int
        or upgrade_handoff["schema_version"] != 1
        or not isinstance(upgrade_handoff["token"], str)
        or not re.fullmatch(r"[0-9a-f]{64}", upgrade_handoff["token"])
        or not isinstance(upgrade_handoff["reservations"], list)
    ):
        raise SystemExit("invalid install manifest: malformed upgrade handoff")
    reservation_paths = []
    for reservation in upgrade_handoff["reservations"]:
        if not isinstance(reservation, dict) or set(reservation) != {
            "path", "token", "temporary_path"
        }:
            raise SystemExit(
                "invalid install manifest: malformed upgrade reservation"
            )
        path = reservation["path"]
        token = reservation["token"]
        if (
            path not in expected_files
            or path in reservation_paths
            or not isinstance(token, str)
            or not re.fullmatch(r"[0-9a-f]{64}", token)
        ):
            raise SystemExit(
                "invalid install manifest: invalid upgrade reservation"
            )
        reservation_paths.append(path)
        expected_temporary = str(
            Path(path).with_name(
                f".{Path(path).name}.keyguide-upgrade-{token}.tmp"
            )
        )
        if reservation["temporary_path"] != expected_temporary:
            raise SystemExit(
                "invalid install manifest: malformed upgrade reservation staging path"
            )
    if preserve_upgrade and reservation_paths not in trusted_upgrade_reservation_plans:
        raise SystemExit(
            "invalid install manifest: unsupported upgrade reservation plan"
        )
    if preserve_upgrade and reservation_paths != expected_upgrade_reservations:
        raise SystemExit(
            "invalid install manifest: upgrade reservation paths changed during retry"
        )
    if not preserve_upgrade and not expected_upgrade_handoff_token:
        raise SystemExit(
            "invalid install manifest: upgrade handoff requires preserve mode"
        )
    if (
        expected_upgrade_handoff_token
        and upgrade_handoff["token"] != expected_upgrade_handoff_token
    ):
        raise SystemExit("invalid install manifest: upgrade handoff token changed")
elif expected_upgrade_handoff_token:
    raise SystemExit("invalid install manifest: expected upgrade handoff is absent")
if pending_uses_upgrade_temporary:
    if upgrade_handoff is None or not any(
        reservation == {
            "path": pending["path"],
            "token": pending["token"],
            "temporary_path": pending["temporary_path"],
        }
        for reservation in upgrade_handoff["reservations"]
    ):
        raise SystemExit("invalid install manifest: malformed reservation staging path")

paths_to_validate = list(owned_files)
if pending is not None:
    paths_to_validate.append(pending["path"])
    paths_to_validate.append(pending["temporary_path"])
for expected in paths_to_validate:
    expected_path = Path(expected)
    if not expected_path.is_absolute():
        raise SystemExit("invalid install manifest: owned path is not absolute")
    try:
        relative = expected_path.relative_to(target_home)
    except ValueError as error:
        raise SystemExit("invalid install manifest: owned path escapes target home") from error
    cursor = target_home
    for component in relative.parts[:-1]:
        cursor /= component
        if cursor.is_symlink():
            raise SystemExit(
                f"invalid install manifest: symlinked path component: {cursor}"
            )
        if not cursor.exists():
            break

if legacy_preimage_migration:
    try:
        if manifest.read_bytes() != manifest_bytes:
            raise RuntimeError("manifest changed during legacy migration")
        migrated_manifest_bytes = (
            json.dumps(document, indent=2) + "\n"
        ).encode("utf-8")
        descriptor, temporary_arg = tempfile.mkstemp(
            prefix=f".{manifest.name}.", suffix=".tmp", dir=manifest.parent
        )
        temporary = Path(temporary_arg)
        try:
            os.fchmod(descriptor, 0o600)
            with os.fdopen(descriptor, "wb") as stream:
                descriptor = -1
                stream.write(migrated_manifest_bytes)
                stream.flush()
                os.fsync(stream.fileno())
            current = os.lstat(manifest)
            if not stat.S_ISREG(current.st_mode):
                raise RuntimeError("manifest is no longer a regular file")
            os.replace(temporary, manifest)
            directory_descriptor = os.open(
                manifest.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC
            )
            try:
                os.fsync(directory_descriptor)
            finally:
                os.close(directory_descriptor)
            manifest_bytes = migrated_manifest_bytes
        finally:
            if descriptor >= 0:
                os.close(descriptor)
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass
    except (OSError, RuntimeError) as error:
        raise SystemExit(
            f"invalid install manifest: could not migrate legacy shell state: {error}"
        ) from error

print("true" if document["plugin_enabled_by_installer"] else "false")
print(install_state)
print(plugin_enable_state)
print(pending["path"] if pending is not None else "-")
print(pending["token"] if pending is not None else "-")
print(pending["temporary_path"] if pending is not None else "-")
print("true" if shell_config_state["preexisting"] else "false")
print(shell_config_state["backup_path"] or "-")
print(shell_config_state["post_enable_sha256"] or "-")
print("true" if shell_config_state["post_enable_present"] else "false")
print(shell_config_state["pre_mode"] or "-")
print(shell_pre_sha256 or "-")
print(str(shell_pre_uid) if shell_pre_uid is not None else "-")
print(str(shell_pre_gid) if shell_pre_gid is not None else "-")
print(shell_restore_state)
print("true" if bar_placement_owned_by_installer else "false")
print(bar_placement_state)
print(placing_recovery)
print(placing_post_sha256 or "-")
print(bar_staging_path or "-")
print(bar_staging_sha256 or "-")
print(bar_staging_mode or "-")
print(file_removal["token"] if file_removal is not None else "-")
print(upgrade_handoff["token"] if upgrade_handoff is not None else "-")
# keyguide-preserve-manifest-validation-complete
print(hashlib.sha256(manifest_bytes).hexdigest())
for owned_file in owned_files:
    print(owned_file)
PY
) || fail "manifest validation failed"

mapfile -t manifest_values <<<"$manifest_validation"
plugin_enabled_by_installer=${manifest_values[0]}
install_state=${manifest_values[1]}
plugin_enable_state=${manifest_values[2]}
pending_reservation_path=${manifest_values[3]}
pending_reservation_token=${manifest_values[4]}
pending_reservation_temporary_path=${manifest_values[5]}
shell_preexisting=${manifest_values[6]}
shell_backup=${manifest_values[7]}
shell_post_enable_sha256=${manifest_values[8]}
shell_post_enable_present=${manifest_values[9]}
shell_pre_mode=${manifest_values[10]}
shell_pre_sha256=${manifest_values[11]}
shell_pre_uid=${manifest_values[12]}
[[ $shell_pre_uid != - ]] || shell_pre_uid=
shell_pre_gid=${manifest_values[13]}
[[ $shell_pre_gid != - ]] || shell_pre_gid=
shell_restore_state=${manifest_values[14]}
bar_placement_owned_by_installer=${manifest_values[15]}
bar_placement_state=${manifest_values[16]}
placing_recovery=${manifest_values[17]}
placing_post_sha256=${manifest_values[18]}
bar_staging_path=${manifest_values[19]}
[[ $bar_staging_path != - ]] || bar_staging_path=
bar_staging_sha256=${manifest_values[20]}
[[ $bar_staging_sha256 != - ]] || bar_staging_sha256=
bar_staging_mode=${manifest_values[21]}
[[ $bar_staging_mode != - ]] || bar_staging_mode=
file_removal_token=${manifest_values[22]}
upgrade_handoff_token=${manifest_values[23]}
validated_manifest_sha256=${manifest_values[24]}
if [[ $pending_reservation_path == - ]]; then
  pending_reservation_path=
  pending_reservation_token=
  pending_reservation_temporary_path=
fi
if [[ $file_removal_token == - ]]; then
  file_removal_token=
fi
if [[ $upgrade_handoff_token == - ]]; then
  upgrade_handoff_token=
fi
manifest_owned_files=("${manifest_values[@]:25}")

if [[ $validate_only == 1 ]]; then
  exit 0
fi

keyguide_require_live_session_unlocked uninstall

managed_shortcut_module="$target_home/.local/state/omarchy/toggles/hypr/omarchy-keyguide.lua"
if [[ $remove_preferences == 1 && -z $prefix_root &&
  ( -e $managed_shortcut_module || -L $managed_shortcut_module ) ]]; then
  [[ -f $lib_dir/keyguide_backend/shortcuts.py &&
    ! -L $lib_dir/keyguide_backend/shortcuts.py ]] ||
    fail "installed shortcut reset backend is unavailable"
  HOME="$target_home" \
    XDG_STATE_HOME="$target_home/.local/state" \
    PYTHONPATH="$lib_dir" \
    PYTHONDONTWRITEBYTECODE=1 \
    python3 -m keyguide_backend shortcuts reset-all >/dev/null ||
    fail "could not reset managed shortcuts before preference removal"
fi

rebase_shell_for_upgrade() {
  python3 - \
    "$manifest_path" \
    "$validated_manifest_sha256" \
    "$target_home" \
    "$shell_config" \
    "$target_home/.local/state/omarchy-keyguide/shell.json.pre-keyguide" \
    "$@" <<'PY'
import copy
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import stat
import sys
import tempfile

(
    manifest_arg,
    validated_manifest_sha256,
    target_home_arg,
    shell_arg,
    backup_arg,
    *new_only_args,
) = sys.argv[1:]
manifest_path = Path(manifest_arg)
target_home = Path(target_home_arg)
shell_path = Path(shell_arg)
backup_path = Path(backup_arg)
new_only_paths = [Path(path) for path in new_only_args]


def reject(message):
    raise SystemExit(f"preserve-user-shell upgrade rejected: {message}")


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate key: {key}")
        result[key] = value
    return result


def invalid_constant(value):
    raise ValueError(f"non-standard JSON constant: {value}")


def json_equal(left, right):
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(
            json_equal(left[key], right[key]) for key in left
        )
    if isinstance(left, list):
        return len(left) == len(right) and all(
            json_equal(left_item, right_item)
            for left_item, right_item in zip(left, right)
        )
    return left == right


def digest(data):
    return hashlib.sha256(data).hexdigest()


def snapshot(path):
    descriptor = os.open(
        path,
        os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
    )
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise ValueError(f"not a regular file: {path}")
        chunks = []
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        data = b"".join(chunks)
        identity = (
            info.st_dev,
            info.st_ino,
            info.st_mode,
            info.st_size,
            info.st_mtime_ns,
            info.st_ctime_ns,
        )
        return data, info, identity
    finally:
        os.close(descriptor)


def require_snapshot(path, expected, label):
    try:
        observed = snapshot(path)
    except (OSError, ValueError) as error:
        reject(f"{label} changed during preserve-user-shell rebase: {error}")
    if observed[0] != expected[0] or observed[2] != expected[2]:
        reject(f"{label} changed during preserve-user-shell rebase")
    return observed


def same_exchanged_snapshot(observed, expected):
    return observed[0] == expected[0] and observed[2][:5] == expected[2][:5]


def exchange_paths(directory_descriptor, left, right):
    renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
    renameat2.argtypes = (
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    )
    renameat2.restype = ctypes.c_int
    if renameat2(
        directory_descriptor,
        os.fsencode(left),
        directory_descriptor,
        os.fsencode(right),
        2,  # RENAME_EXCHANGE
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


def upgrade_handoff(document):
    handoff = document.get("upgrade_handoff")
    if handoff is None:
        reservations = []
        for path in new_only_paths:
            token = secrets.token_hex(32)
            reservations.append(
                {
                    "path": str(path),
                    "token": token,
                    "temporary_path": str(
                        path.with_name(
                            f".{path.name}.keyguide-upgrade-{token}.tmp"
                        )
                    ),
                }
            )
        return {
            "schema_version": 1,
            "token": secrets.token_hex(32),
            "reservations": reservations,
        }
    if (
        not isinstance(handoff, dict)
        or set(handoff) != {"schema_version", "token", "reservations"}
        or type(handoff.get("schema_version")) is not int
        or handoff["schema_version"] != 1
        or not re.fullmatch(r"[0-9a-f]{64}", handoff.get("token", ""))
        or not isinstance(handoff.get("reservations"), list)
    ):
        reject("malformed upgrade handoff journal")
    paths = []
    for reservation in handoff["reservations"]:
        if not isinstance(reservation, dict) or set(reservation) != {
            "path", "token", "temporary_path"
        }:
            reject("malformed upgrade reservation journal")
        path = Path(reservation["path"])
        token = reservation["token"]
        if (
            not re.fullmatch(r"[0-9a-f]{64}", token)
            or reservation["temporary_path"]
            != str(path.with_name(f".{path.name}.keyguide-upgrade-{token}.tmp"))
        ):
            reject("malformed upgrade reservation journal")
        paths.append(path)
    if paths != new_only_paths:
        reject("upgrade reservation paths changed during retry")
    return handoff


def ensure_upgrade_reservations(handoff):
    def open_parent_no_symlink(path):
        try:
            relative_parent = path.parent.relative_to(target_home)
        except ValueError as error:
            reject(f"upgrade reservation escapes target home: {path}")
        descriptor = os.open(
            target_home, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
        )
        try:
            for component in relative_parent.parts:
                if component in {"", ".", ".."}:
                    reject(f"upgrade reservation has unsafe component: {path}")
                try:
                    next_descriptor = os.open(
                        component,
                        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                        dir_fd=descriptor,
                    )
                except FileNotFoundError:
                    os.mkdir(component, 0o755, dir_fd=descriptor)
                    os.fsync(descriptor)
                    next_descriptor = os.open(
                        component,
                        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                        dir_fd=descriptor,
                    )
                except OSError as error:
                    reject(
                        f"symlinked upgrade reservation parent component: {path}"
                    )
                os.close(descriptor)
                descriptor = next_descriptor
            return descriptor
        except Exception:
            os.close(descriptor)
            raise

    for reservation in handoff["reservations"]:
        path = Path(reservation["path"])
        temporary = Path(reservation["temporary_path"])
        token = reservation["token"].encode("ascii")
        try:
            path.relative_to(target_home)
        except ValueError as error:
            reject(f"upgrade reservation escapes target home: {path}")
        parent_descriptor = open_parent_no_symlink(path)
        staging_descriptor = -1
        final_descriptor = -1
        staging_created = False
        try:
            try:
                staging_descriptor = os.open(
                    temporary.name,
                    os.O_RDONLY
                    | os.O_CLOEXEC
                    | os.O_NOFOLLOW
                    | os.O_NONBLOCK,
                    dir_fd=parent_descriptor,
                )
            except FileNotFoundError:
                staging_created = True
                staging_descriptor = os.open(
                    temporary.name,
                    os.O_WRONLY
                    | os.O_CREAT
                    | os.O_EXCL
                    | os.O_CLOEXEC
                    | os.O_NOFOLLOW,
                    0o600,
                    dir_fd=parent_descriptor,
                )
                remaining = memoryview(token)
                while remaining:
                    written = os.write(staging_descriptor, remaining)
                    if written <= 0:
                        raise OSError("short write while staging upgrade reservation")
                    remaining = remaining[written:]
                os.fsync(staging_descriptor)
                os.close(staging_descriptor)
                staging_descriptor = os.open(
                    temporary.name,
                    os.O_RDONLY
                    | os.O_CLOEXEC
                    | os.O_NOFOLLOW
                    | os.O_NONBLOCK,
                    dir_fd=parent_descriptor,
                )
            staging_info = os.fstat(staging_descriptor)
            staging_bytes = os.read(staging_descriptor, len(token) + 1)
            if (
                not stat.S_ISREG(staging_info.st_mode)
                or stat.S_IMODE(staging_info.st_mode) != 0o600
                or staging_info.st_size != len(token)
                or staging_bytes != token
            ):
                reject(f"upgrade reservation staging path changed: {temporary}")
            try:
                final_descriptor = os.open(
                    path.name,
                    os.O_RDONLY
                    | os.O_CLOEXEC
                    | os.O_NOFOLLOW
                    | os.O_NONBLOCK,
                    dir_fd=parent_descriptor,
                )
            except FileNotFoundError:
                os.link(
                    temporary.name,
                    path.name,
                    src_dir_fd=parent_descriptor,
                    dst_dir_fd=parent_descriptor,
                    follow_symlinks=False,
                )
                final_descriptor = os.open(
                    path.name,
                    os.O_RDONLY
                    | os.O_CLOEXEC
                    | os.O_NOFOLLOW
                    | os.O_NONBLOCK,
                    dir_fd=parent_descriptor,
                )
            final_info = os.fstat(final_descriptor)
            final_bytes = os.read(final_descriptor, len(token) + 1)
            if (
                not stat.S_ISREG(final_info.st_mode)
                or stat.S_IMODE(final_info.st_mode) != 0o600
                or final_info.st_size != len(token)
                or final_bytes != token
                or (
                    (final_info.st_dev, final_info.st_ino)
                    != (staging_info.st_dev, staging_info.st_ino)
                    and not staging_created
                )
            ):
                reject(f"refusing to overwrite unowned path: {path}")
            os.unlink(temporary.name, dir_fd=parent_descriptor)
            os.fsync(parent_descriptor)
        finally:
            if final_descriptor >= 0:
                os.close(final_descriptor)
            if staging_descriptor >= 0:
                os.close(staging_descriptor)
            os.close(parent_descriptor)


def json_bytes(document):
    return (
        json.dumps(document, indent=2, ensure_ascii=False) + "\n"
    ).encode("utf-8")


def parse_object(data, label):
    try:
        document = json.loads(
            data.decode("utf-8"),
            object_pairs_hook=unique_object,
            parse_constant=invalid_constant,
        )
    except (UnicodeError, ValueError, json.JSONDecodeError) as error:
        reject(f"invalid {label} JSON: {error}")
    if not isinstance(document, dict):
        reject(f"invalid {label} JSON: document must be an object")
    return document


def plugin_locations(document):
    plugins = document.get("plugins")
    if not isinstance(plugins, list):
        reject("Keyguide plugin transform requires a plugins array")
    return plugins, [
        (index, entry)
        for index, entry in enumerate(plugins)
        if entry == "mrai.keyguide"
        or (
            isinstance(entry, dict)
            and entry.get("id") == "mrai.keyguide"
        )
    ]


def bar_layout(document, label):
    bar = document.get("bar")
    layout = bar.get("layout") if isinstance(bar, dict) else None
    if not isinstance(layout, dict):
        reject(f"{label} lacks a bar layout")
    for section in ("left", "center", "right"):
        if not isinstance(layout.get(section), list):
            reject(f"{label} bar {section} must be an array")
    return layout


def entry_id(entry):
    return entry.get("id") if isinstance(entry, dict) else entry


def layout_locations(layout, identifier):
    locations = []
    for section, entries in layout.items():
        if not isinstance(entries, list):
            continue
        for index, entry in enumerate(entries):
            if entry_id(entry) == identifier:
                locations.append((section, index, entry))
    return locations


def add_owned_bar_transform(document):
    layout = bar_layout(document, "authenticated shell preimage")
    keyguide_locations = layout_locations(layout, "mrai.keyguide")
    agent_locations = layout_locations(layout, "omarchy.agents")
    if keyguide_locations:
        reject("authenticated preimage already contains a Keyguide bar entry")
    if len(agent_locations) != 1:
        reject("authenticated preimage does not have one Agents anchor")
    section, index, _ = agent_locations[0]
    layout[section].insert(index + 1, {"id": "mrai.keyguide"})


def authenticate_old_backup(document, shell_state, backup_document, backup_bytes):
    plugin_owned = document.get("plugin_enabled_by_installer") is True
    bar_owned = shell_state.get("bar_placement_owned_by_installer") is True
    if not bar_owned:
        reject("divergent shell upgrade requires installer-owned bar placement")

    candidate = copy.deepcopy(backup_document)
    transform = {
        "kind": "unchanged" if plugin_owned else "preserved",
        "index": None,
    }
    if plugin_owned:
        plugins, locations = plugin_locations(candidate)
        if locations:
            if len(locations) != 1 or locations[0][1] != {"id": "mrai.keyguide"}:
                reject("authenticated preimage has an ambiguous Keyguide plugin entry")
            index, _ = locations[0]
            plugins.pop(index)
            transform = {"kind": "removed", "index": index}
    add_owned_bar_transform(candidate)
    recorded_pre_hash = shell_state.get("pre_sha256", "")
    if recorded_pre_hash:
        if digest(backup_bytes) != recorded_pre_hash:
            reject("shell backup does not match authenticated preimage hash")
        return transform

    post_hash = shell_state.get("post_enable_sha256")
    canonical_endpoint = digest(json_bytes(candidate)) == post_hash
    # The placement-era release preserved the original shell formatting while
    # moving the canonical plugin entry into the bar.  These hashes are the
    # checked-in, independently retained before/after endpoint pair; admitting
    # only the exact pair avoids guessing at historical serialization rules.
    retained_endpoint = (
        digest(backup_bytes)
        == "96cf8c2eca7f066b8aa5e91e50ceb7730adad022ac29ccbd0005af970d2a8dda"
        and post_hash
        == "e2287f69a0bc7c5a6b1d6b34522702d9dc4d71582fdbaa84331d1bb93c1933d3"
        and transform == {"kind": "removed", "index": 0}
    )
    if not canonical_endpoint and not retained_endpoint:
        reject("backup cannot reproduce the authenticated legacy shell postimage")
    return transform


def derive_current_preimage(live_document, transform):
    candidate = copy.deepcopy(live_document)
    layout = bar_layout(candidate, "live shell")
    locations = layout_locations(layout, "mrai.keyguide")
    if len(locations) != 1:
        reject("live shell does not contain exactly one Keyguide bar entry")
    section, index, entry = locations[0]
    predecessor = layout[section][index - 1] if index > 0 else None
    if entry != {"id": "mrai.keyguide"} or entry_id(predecessor) != "omarchy.agents":
        reject("live Keyguide bar entry is not canonical and uniquely anchored after omarchy.agents")
    layout[section].pop(index)

    plugins, current_plugin_locations = plugin_locations(candidate)
    if transform == {"kind": "preserved", "index": None}:
        pass
    elif transform == {"kind": "unchanged", "index": None}:
        if current_plugin_locations:
            reject("live shell contains an unexpected Keyguide plugin entry")
    elif (
        isinstance(transform, dict)
        and set(transform) == {"kind", "index"}
        and transform.get("kind") == "removed"
        and type(transform.get("index")) is int
        and transform["index"] >= 0
    ):
        if current_plugin_locations:
            reject("live shell contains an unexpected Keyguide plugin entry")
        if transform["index"] > len(plugins):
            reject("Keyguide plugin transform no longer has a unique insertion point")
        plugins.insert(transform["index"], {"id": "mrai.keyguide"})
    else:
        reject("rebase journal contains an unknown Keyguide plugin transform")
    return candidate


def apply_current_transform(derived_document, transform):
    candidate = copy.deepcopy(derived_document)
    if transform.get("kind") == "removed":
        plugins, locations = plugin_locations(candidate)
        index = transform["index"]
        if (
            len(locations) != 1
            or locations[0] != (index, {"id": "mrai.keyguide"})
        ):
            reject("derived Keyguide plugin transform is not reversible")
        plugins.pop(index)
    add_owned_bar_transform(candidate)
    return candidate


def atomic_publish(path, data, mode, expected_snapshot, label):
    parent_descriptor = os.open(
        path.parent,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
    )
    descriptor = -1
    temporary_name = ""
    preserve_temporary = False
    try:
        descriptor, temporary_arg = tempfile.mkstemp(
            prefix=f".{path.name}.keyguide-rebase-",
            suffix=".tmp",
            dir=path.parent,
        )
        temporary_name = Path(temporary_arg).name
        os.fchmod(descriptor, mode)
        remaining = memoryview(data)
        while remaining:
            written = os.write(descriptor, remaining)
            if written <= 0:
                raise OSError(f"short write while staging {label}")
            remaining = remaining[written:]
        os.fsync(descriptor)
        os.close(descriptor)
        descriptor = -1
        staged_snapshot = snapshot(path.parent / temporary_name)
        require_snapshot(path, expected_snapshot, label)
        # keyguide-atomic-publish-observation-checked
        exchange_paths(parent_descriptor, temporary_name, path.name)
        preserve_temporary = True

        def abort_after_exchange(message):
            nonlocal preserve_temporary
            quarantine = path.parent / temporary_name
            try:
                current_snapshot = snapshot(path)
            except (OSError, ValueError):
                reject(f"{message}; displaced endpoint preserved at {quarantine}")
            if same_exchanged_snapshot(current_snapshot, staged_snapshot):
                try:
                    exchange_paths(
                        parent_descriptor, temporary_name, path.name
                    )
                    os.fsync(parent_descriptor)
                except OSError as error:
                    reject(
                        f"{message}; rollback failed and displaced endpoint "
                        f"is preserved at {quarantine}: {error}"
                    )
                try:
                    rolled_temporary = snapshot(quarantine)
                except (OSError, ValueError):
                    reject(
                        f"{message}; a concurrent endpoint is preserved at "
                        f"{quarantine}"
                    )
                if same_exchanged_snapshot(
                    rolled_temporary, staged_snapshot
                ):
                    preserve_temporary = False
                    reject(message)
                reject(
                    f"{message}; a concurrent endpoint is preserved at "
                    f"{quarantine}"
                )
            reject(f"{message}; displaced endpoint preserved at {quarantine}")

        try:
            displaced_snapshot = snapshot(path.parent / temporary_name)
        except (OSError, ValueError):
            abort_after_exchange(f"{label} changed during atomic publication")
        if not same_exchanged_snapshot(displaced_snapshot, expected_snapshot):
            abort_after_exchange(f"{label} changed during atomic publication")
        try:
            published_snapshot = snapshot(path)
        except (OSError, ValueError):
            reject(
                f"{label} changed immediately after atomic publication; "
                f"displaced endpoint preserved at {path.parent / temporary_name}"
            )
        if not same_exchanged_snapshot(published_snapshot, staged_snapshot):
            reject(
                f"{label} changed immediately after atomic publication; "
                f"displaced endpoint preserved at {path.parent / temporary_name}"
            )
        os.unlink(temporary_name, dir_fd=parent_descriptor)
        preserve_temporary = False
        temporary_name = ""
        os.fsync(parent_descriptor)
        return published_snapshot
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        if temporary_name and not preserve_temporary:
            try:
                os.unlink(temporary_name, dir_fd=parent_descriptor)
            except FileNotFoundError:
                pass
        os.close(parent_descriptor)


try:
    manifest_snapshot = snapshot(manifest_path)
    if digest(manifest_snapshot[0]) != validated_manifest_sha256:
        reject("manifest changed after validation")
    if stat.S_IMODE(manifest_snapshot[1].st_mode) != 0o600:
        reject("install manifest mode is not 0600")
    document = parse_object(manifest_snapshot[0], "install manifest")
    if type(document.get("schema_version")) is not int or document["schema_version"] != 1:
        reject("unsupported install manifest schema")
    if document.get("plugin_id") != "mrai.keyguide":
        reject("install manifest has the wrong plugin id")
    if document.get("prefix_root") != "":
        reject("preserve mode cannot operate on a prefixed install")
    if document.get("target_home") != str(target_home):
        reject("install manifest target home mismatch")
    if document.get("pending_reservation") is not None:
        reject("install manifest has a pending file reservation")
    shell_state = document.get("shell_config")
    if not isinstance(shell_state, dict):
        reject("install manifest has malformed shell ownership")
    expected_backup_path = str(backup_path)
    if (
        shell_state.get("preexisting") is not True
        or shell_state.get("backup_path") != expected_backup_path
        or shell_state.get("post_enable_present") is not True
        or not re.fullmatch(
            r"[0-9a-f]{64}", shell_state.get("post_enable_sha256", "")
        )
        or not re.fullmatch(r"[0-7]{3,4}", shell_state.get("pre_mode", ""))
    ):
        reject("install manifest lacks an authenticated shell endpoint")
    if shell_state.get("restore_state", "not_started") != "not_started":
        reject("shell restoration has already started")
    bar_state = shell_state.get(
        "bar_placement_state",
        "placed" if shell_state.get("bar_placement_owned_by_installer") else "not_started",
    )
    if (
        shell_state.get("bar_placement_owned_by_installer") is not True
        or bar_state != "placed"
    ):
        reject("divergent shell upgrade lacks placed bar ownership")

    live_snapshot = snapshot(shell_path)
    if stat.S_IMODE(live_snapshot[1].st_mode) != int(
        shell_state["pre_mode"], 8
    ):
        reject("live shell mode changed after installation")
    live_document = parse_object(live_snapshot[0], "live shell")
    backup_snapshot = snapshot(backup_path)
    if stat.S_IMODE(backup_snapshot[1].st_mode) != 0o600:
        reject("authenticated shell backup mode is not 0600")
    recorded_uid = shell_state.get("pre_uid")
    recorded_gid = shell_state.get("pre_gid")
    if recorded_uid is not None and (
        type(recorded_uid) is not int
        or recorded_uid < 0
        or type(recorded_gid) is not int
        or recorded_gid < 0
    ):
        reject("malformed shell preimage owner")
    if recorded_uid is not None:
        if (
            live_snapshot[1].st_uid != recorded_uid
            or backup_snapshot[1].st_uid != recorded_uid
            or live_snapshot[1].st_gid != recorded_gid
            or backup_snapshot[1].st_gid != recorded_gid
        ):
            reject("shell preimage owner changed during preserve-user-shell rebase")
    backup_document = parse_object(backup_snapshot[0], "shell backup")

    install_state = document.get("install_state")
    if install_state == "rebasing":
        handoff = upgrade_handoff(document)
        rebase = document.get("shell_rebase")
        if not isinstance(rebase, dict) or set(rebase) != {
            "schema_version",
            "current_sha256",
            "derived_sha256",
            "previous_backup_sha256",
            "shell_mode",
            "plugin_transform",
        }:
            reject("malformed preserve-user-shell rebase journal")
        if type(rebase.get("schema_version")) is not int or rebase["schema_version"] != 1:
            reject("unknown preserve-user-shell rebase journal schema")
        for key in (
            "current_sha256",
            "derived_sha256",
            "previous_backup_sha256",
        ):
            if not re.fullmatch(r"[0-9a-f]{64}", rebase.get(key, "")):
                reject("malformed preserve-user-shell rebase hash")
        if rebase.get("shell_mode") != format(
            stat.S_IMODE(live_snapshot[1].st_mode), "o"
        ):
            reject("live shell mode changed during preserve-user-shell rebase")
        if digest(live_snapshot[0]) != rebase["current_sha256"]:
            reject("shell changed during preserve-user-shell rebase")
        transform = rebase.get("plugin_transform")
        derived_document = derive_current_preimage(live_document, transform)
        if not json_equal(
            apply_current_transform(derived_document, transform), live_document
        ):
            reject("current Keyguide transforms are not exactly reversible")
        derived_bytes = json_bytes(derived_document)
        if digest(derived_bytes) != rebase["derived_sha256"]:
            reject("derived shell preimage changed during preserve-user-shell rebase")
        backup_hash = digest(backup_snapshot[0])
        if backup_hash == rebase["previous_backup_sha256"]:
            authenticated_transform = authenticate_old_backup(
                document, shell_state, backup_document, backup_snapshot[0]
            )
            if authenticated_transform != transform:
                reject("rebase journal plugin transform is not authenticated")
        elif backup_hash != rebase["derived_sha256"]:
            reject("shell backup matches neither rebase endpoint")
    elif install_state == "installed":
        if "shell_rebase" in document:
            reject("installed manifest contains a stray rebase journal")
        backup_hash = digest(backup_snapshot[0])
        recorded_pre_hash = shell_state.get("pre_sha256", "")
        if recorded_pre_hash and backup_hash != recorded_pre_hash:
            reject("shell backup does not match authenticated preimage hash")
        transform = authenticate_old_backup(
            document, shell_state, backup_document, backup_snapshot[0]
        )
        derived_document = derive_current_preimage(live_document, transform)
        if not json_equal(
            apply_current_transform(derived_document, transform), live_document
        ):
            reject("current Keyguide transforms are not exactly reversible")
        derived_bytes = json_bytes(derived_document)
        rebase = {
            "schema_version": 1,
            "current_sha256": digest(live_snapshot[0]),
            "derived_sha256": digest(derived_bytes),
            "previous_backup_sha256": backup_hash,
            "shell_mode": format(stat.S_IMODE(live_snapshot[1].st_mode), "o"),
            "plugin_transform": transform,
        }
        journal_document = copy.deepcopy(document)
        journal_document["install_state"] = "rebasing"
        journal_document["shell_rebase"] = rebase
        handoff = upgrade_handoff(journal_document)
        journal_document["upgrade_handoff"] = handoff
        journal_bytes = json_bytes(journal_document)

        # keyguide-preserve-rebase-observations-captured
        hook_marker = os.environ.get("KEYGUIDE_TEST_HOOK_UPGRADE_RESERVATION_PARENT_SYMLINK")
        hook_escape = os.environ.get("KEYGUIDE_TEST_HOOK_UPGRADE_RESERVATION_PARENT_ESCAPE")
        if hook_marker and hook_escape and not Path(hook_marker).exists():
            import shutil
            if handoff["reservations"]:
                parent = Path(handoff["reservations"][0]["path"]).parent
                escaped = Path(hook_escape)
                escaped.mkdir(parents=True, exist_ok=True)
                if parent.exists() and not parent.is_symlink():
                    shutil.rmtree(parent)
                parent.parent.mkdir(parents=True, exist_ok=True)
                parent.symlink_to(escaped, target_is_directory=True)
                Path(hook_marker).touch()
        require_snapshot(shell_path, live_snapshot, "shell")
        require_snapshot(backup_path, backup_snapshot, "shell backup")
        require_snapshot(manifest_path, manifest_snapshot, "manifest")
        manifest_snapshot = atomic_publish(
            manifest_path,
            journal_bytes,
            0o600,
            manifest_snapshot,
            "manifest",
        )
        document = journal_document
    else:
        reject("preserve upgrade requires an installed or rebasing manifest")

    require_snapshot(manifest_path, manifest_snapshot, "manifest")
    ensure_upgrade_reservations(handoff)
    require_snapshot(shell_path, live_snapshot, "shell")
    require_snapshot(manifest_path, manifest_snapshot, "manifest")
    current_backup_snapshot = snapshot(backup_path)
    current_backup_hash = digest(current_backup_snapshot[0])
    if current_backup_hash == rebase["previous_backup_sha256"]:
        # keyguide-atomic-shell-rebase
        current_backup_snapshot = atomic_publish(
            backup_path,
            derived_bytes,
            0o600,
            current_backup_snapshot,
            "shell backup",
        )
    elif current_backup_hash != rebase["derived_sha256"]:
        reject("shell backup changed during preserve-user-shell rebase")

    require_snapshot(shell_path, live_snapshot, "shell")
    require_snapshot(manifest_path, manifest_snapshot, "manifest")
    if digest(current_backup_snapshot[0]) != rebase["derived_sha256"]:
        reject("rebased shell backup was not published atomically")

    final_document = copy.deepcopy(document)
    final_document["install_state"] = "installed"
    final_document.pop("shell_rebase", None)
    final_document["shell_config"] = {
        "preexisting": True,
        "backup_path": str(backup_path),
        "post_enable_sha256": rebase["current_sha256"],
        "post_enable_present": True,
        "pre_mode": rebase["shell_mode"],
        "pre_sha256": rebase["derived_sha256"],
        "pre_uid": live_snapshot[1].st_uid,
        "pre_gid": live_snapshot[1].st_gid,
        "restore_state": "not_started",
        "bar_placement_owned_by_installer": True,
        "bar_placement_state": "placed",
    }
    atomic_publish(
        manifest_path,
        json_bytes(final_document),
        0o600,
        manifest_snapshot,
        "manifest",
    )
except (OSError, ValueError) as error:
    reject(str(error))
PY
}

if [[ $preserve_upgrade == 1 ]]; then
  if [[ $install_state == restart_pending || $shell_restore_state != not_started ]]; then
    [[ -n $upgrade_handoff_token ]] ||
      fail "preserve-user-shell retry lacks an upgrade handoff"
    KEYGUIDE_PRESERVE_UPGRADE=0 \
      KEYGUIDE_UPGRADE_HANDOFF_TOKEN="$upgrade_handoff_token" \
      exec bash "${BASH_SOURCE[0]}"
  fi
  rebase_shell_for_upgrade "$@" || fail "preserve-user-shell rebase failed"
  upgrade_handoff_token=$(python3 - "$manifest_path" <<'PY'
import json
import os
import re
import stat
import sys

descriptor = os.open(
    sys.argv[1], os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
)
try:
    if not stat.S_ISREG(os.fstat(descriptor).st_mode):
        raise SystemExit("upgrade manifest is not a regular file")
    chunks = []
    while True:
        chunk = os.read(descriptor, 65536)
        if not chunk:
            break
        chunks.append(chunk)
finally:
    os.close(descriptor)
document = json.loads(b"".join(chunks).decode("utf-8"))
handoff = document.get("upgrade_handoff")
token = handoff.get("token", "") if isinstance(handoff, dict) else ""
if not re.fullmatch(r"[0-9a-f]{64}", token):
    raise SystemExit("upgrade handoff token is unavailable")
print(token)
PY
  ) || fail "could not inspect upgrade handoff"
  KEYGUIDE_PRESERVE_UPGRADE=0 \
    KEYGUIDE_UPGRADE_HANDOFF_TOKEN="$upgrade_handoff_token" \
    exec bash "${BASH_SOURCE[0]}"
fi

update_manifest() {
  local transition=$1
  local detail=${2:-}
  local next_manifest_sha256
  next_manifest_sha256=$(python3 - \
    "$manifest_path" \
    "$transition" \
    "$detail" \
    "$validated_manifest_sha256" <<'PY'
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

manifest = Path(sys.argv[1])
transition = sys.argv[2]
detail = sys.argv[3]
expected_manifest_sha256 = sys.argv[4]


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate manifest key: {key}")
        result[key] = value
    return result


def invalid_constant(value):
    raise ValueError(f"non-standard JSON constant: {value}")


def snapshot(path):
    descriptor = os.open(
        path,
        os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
    )
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError("install manifest is not a regular file")
        chunks = []
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        return (
            b"".join(chunks),
            info,
            (
                info.st_dev,
                info.st_ino,
                info.st_mode,
                info.st_size,
                info.st_mtime_ns,
                info.st_ctime_ns,
            ),
        )
    finally:
        os.close(descriptor)


def same_exchanged_snapshot(observed, expected):
    return observed[0] == expected[0] and observed[2][:5] == expected[2][:5]


def exchange_paths(directory_descriptor, left, right):
    renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
    renameat2.argtypes = (
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    )
    renameat2.restype = ctypes.c_int
    if renameat2(
        directory_descriptor,
        os.fsencode(left),
        directory_descriptor,
        os.fsencode(right),
        2,
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


def snapshot_removal_target(target_home, path, allow_unowned_nonregular=False):
    try:
        relative = path.relative_to(target_home)
    except ValueError as error:
        raise RuntimeError(f"owned path escapes target home: {path}") from error
    home_descriptor = os.open(
        target_home,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
    )
    parent_descriptor = home_descriptor
    try:
        for component in relative.parts[:-1]:
            try:
                next_descriptor = os.open(
                    component,
                    os.O_RDONLY
                    | os.O_DIRECTORY
                    | os.O_CLOEXEC
                    | os.O_NOFOLLOW,
                    dir_fd=parent_descriptor,
                )
            except FileNotFoundError:
                return None
            if parent_descriptor != home_descriptor:
                os.close(parent_descriptor)
            parent_descriptor = next_descriptor
        try:
            descriptor = os.open(
                relative.parts[-1],
                os.O_RDONLY
                | os.O_CLOEXEC
                | os.O_NOFOLLOW
                | os.O_NONBLOCK,
                dir_fd=parent_descriptor,
            )
        except FileNotFoundError:
            return None
        except OSError as error:
            if allow_unowned_nonregular and error.errno == errno.ELOOP:
                return None
            raise RuntimeError(
                f"owned path is not a regular file: {path}"
            ) from error
        try:
            info = os.fstat(descriptor)
            if not stat.S_ISREG(info.st_mode):
                if allow_unowned_nonregular:
                    return None
                raise RuntimeError(f"owned path is not a regular file: {path}")
            digest = hashlib.sha256()
            chunks = []
            while True:
                chunk = os.read(descriptor, 65536)
                if not chunk:
                    break
                digest.update(chunk)
                chunks.append(chunk)
            return (
                b"".join(chunks),
                {
                    "path": str(path),
                    "sha256": digest.hexdigest(),
                    "mode": stat.S_IMODE(info.st_mode),
                    "device": info.st_dev,
                    "inode": info.st_ino,
                    "size": info.st_size,
                    "mtime_ns": info.st_mtime_ns,
                },
            )
        finally:
            os.close(descriptor)
    finally:
        if parent_descriptor != home_descriptor:
            os.close(parent_descriptor)
        os.close(home_descriptor)


manifest_snapshot = snapshot(manifest)
if hashlib.sha256(manifest_snapshot[0]).hexdigest() != expected_manifest_sha256:
    raise RuntimeError("install manifest changed before atomic transition")
document = json.loads(
    manifest_snapshot[0].decode("utf-8"),
    object_pairs_hook=unique_object,
    parse_constant=invalid_constant,
)

if transition == "bar_placed_recovered":
    shell_config = document.get("shell_config")
    if not isinstance(shell_config, dict):
        raise RuntimeError("cannot recover malformed bar placement ownership")
    if shell_config.get("bar_placement_state") != "placing":
        raise RuntimeError("cannot recover bar placement from unexpected state")
    if shell_config.get("bar_placement_owned_by_installer") is not False:
        raise RuntimeError("cannot recover an already owned bar placement")
    if not re.fullmatch(r"[0-9a-f]{64}", detail):
        raise RuntimeError("cannot recover bar placement without a post-image hash")
    shell_config["post_enable_sha256"] = detail
    shell_config["post_enable_present"] = True
    shell_config["bar_placement_owned_by_installer"] = True
    shell_config["bar_placement_state"] = "placed"
elif transition == "shell_restoring":
    shell_config = document.get("shell_config")
    if not isinstance(shell_config, dict):
        raise RuntimeError("cannot journal malformed shell ownership")
    bar_owned = shell_config.get("bar_placement_owned_by_installer", False)
    bar_state = shell_config.get(
        "bar_placement_state", "placed" if bar_owned else "not_started"
    )
    plugin_owned = document.get("plugin_enabled_by_installer") is True
    if not plugin_owned and not bar_owned and bar_state != "placing":
        raise RuntimeError("cannot journal unowned shell restoration")
    if shell_config.get("restore_state") != "not_started":
        raise RuntimeError("cannot start shell restoration from unexpected state")
    shell_config["restore_state"] = "restoring"
elif transition == "shell_restored":
    shell_config = document.get("shell_config")
    if not isinstance(shell_config, dict):
        raise RuntimeError("cannot clear malformed shell ownership")
    bar_owned = shell_config.get("bar_placement_owned_by_installer", False)
    bar_state = shell_config.get(
        "bar_placement_state", "placed" if bar_owned else "not_started"
    )
    plugin_owned = document.get("plugin_enabled_by_installer") is True
    if not plugin_owned and not bar_owned and bar_state != "placing":
        raise RuntimeError("cannot clear shell ownership from unowned state")
    document["plugin_enabled_by_installer"] = False
    if plugin_owned:
        if document.get("plugin_enable_state") != "enabled":
            raise RuntimeError("cannot clear plugin ownership from unexpected state")
        document["plugin_enable_state"] = "disabled"
    shell_config["bar_placement_owned_by_installer"] = False
    if bar_state in {"placing", "placed"}:
        shell_config["bar_placement_state"] = "restored"
    shell_config["restore_state"] = "restored"
elif transition == "files_removing":
    if not re.fullmatch(r"[0-9a-f]{64}", detail):
        raise RuntimeError("cannot journal file removal without a token")
    if document.get("file_removal") is not None:
        raise RuntimeError("file removal is already journaled")
    target_home = Path(document.get("target_home", ""))
    owned_files = document.get("owned_files")
    if not target_home.is_absolute() or not isinstance(owned_files, list):
        raise RuntimeError("cannot journal malformed owned paths")
    removal_targets = []
    for owned_path in owned_files:
        observed = snapshot_removal_target(target_home, Path(owned_path))
        if observed is not None:
            removal_targets.append(observed[1])
    pending = document.get("pending_reservation")
    if pending is not None:
        pending_token = pending.get("token", "").encode("ascii")
        pending_payload_sha256 = pending.get("payload_sha256")
        pending_payload_mode = pending.get("payload_mode")
        pending_has_payload_journal = pending_payload_sha256 is not None

        def pending_kind(observed):
            if observed is None:
                return None
            data, identity = observed
            if (
                data == pending_token
                and (
                    not pending_has_payload_journal
                    or (
                        identity["mode"] == 0o600
                        and identity["size"] == len(pending_token)
                    )
                )
            ):
                return "token"
            if (
                pending_payload_sha256 is not None
                and identity["sha256"] == pending_payload_sha256
                and identity["mode"] == pending_payload_mode
            ):
                return "payload"
            return "unknown"

        pending_observed = snapshot_removal_target(
            target_home,
            Path(pending.get("path", "")),
            allow_unowned_nonregular=True,
        )
        pending_observed_kind = pending_kind(pending_observed)
        if pending_observed_kind in {"token", "payload"}:
            removal_targets.append(pending_observed[1])
        try:
            temporary_observed = snapshot_removal_target(
                target_home, Path(pending.get("temporary_path", ""))
            )
        except RuntimeError as error:
            raise RuntimeError(
                "pending staging file does not match reservation token"
            ) from error
        temporary_observed_kind = pending_kind(temporary_observed)
        if temporary_observed is not None:
            if temporary_observed_kind not in {"token", "payload"}:
                raise RuntimeError(
                    "pending staging file does not match reservation token or payload"
                )
            if (
                pending_observed_kind == "token"
                and temporary_observed_kind == "token"
                and (
                    pending_observed[1]["device"], pending_observed[1]["inode"]
                )
                != (
                    temporary_observed[1]["device"],
                    temporary_observed[1]["inode"],
                )
            ):
                raise RuntimeError(
                    "pending token endpoints do not share a reservation inode"
                )
            removal_targets.append(temporary_observed[1])
    document["file_removal"] = {
        "token": detail,
        "targets": removal_targets,
    }
elif transition == "restart_pending":
    document["install_state"] = "restart_pending"
    document["owned_files"] = []
    document["pending_reservation"] = None
    document.pop("file_removal", None)
    document["plugin_enabled_by_installer"] = False
    if document.get("plugin_enable_state") == "enabled":
        document["plugin_enable_state"] = "disabled"
    shell_config = document.get("shell_config")
    if isinstance(shell_config, dict):
        shell_config["bar_placement_owned_by_installer"] = False
        bar_state = shell_config.get("bar_placement_state")
        if bar_state in {"placing", "placed"}:
            shell_config["bar_placement_state"] = "restored"
        shell_config["restore_state"] = "restored"
elif transition == "upgrade_ready":
    if document.get("install_state") != "restart_pending":
        raise RuntimeError("upgrade handoff is not restart-pending")
    if not isinstance(document.get("upgrade_handoff"), dict):
        raise RuntimeError("upgrade handoff journal is unavailable")
    if document.get("owned_files") or document.get("pending_reservation") is not None:
        raise RuntimeError("upgrade handoff still owns install paths")
    shell_config = document.get("shell_config")
    if (
        not isinstance(shell_config, dict)
        or shell_config.get("preexisting") is not True
        or not re.fullmatch(r"[0-9a-f]{64}", shell_config.get("pre_sha256", ""))
        or not re.fullmatch(r"[0-7]{3,4}", shell_config.get("pre_mode", ""))
    ):
        raise RuntimeError("upgrade handoff lacks a shell baseline")
    document["install_state"] = "upgrade_ready"
    document["plugin_enabled_by_installer"] = False
    document["plugin_enable_state"] = (
        "preexisting" if document.get("plugin_was_enabled") is True else "not_started"
    )
    shell_config["post_enable_sha256"] = shell_config["pre_sha256"]
    shell_config["post_enable_present"] = True
    shell_config["restore_state"] = "not_started"
    shell_config["bar_placement_owned_by_installer"] = False
    shell_config["bar_placement_state"] = "not_started"
else:
    raise RuntimeError(f"unknown manifest transition: {transition}")

manifest_bytes = (json.dumps(document, indent=2) + "\n").encode("utf-8")
directory_descriptor = os.open(
    manifest.parent,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)
descriptor = -1
temporary_name = ""
preserve_temporary = False
try:
    descriptor, temporary_arg = tempfile.mkstemp(
        prefix=f".{manifest.name}.keyguide-transition-",
        suffix=".tmp",
        dir=manifest.parent,
    )
    temporary_name = Path(temporary_arg).name
    os.fchmod(descriptor, 0o600)
    remaining = memoryview(manifest_bytes)
    while remaining:
        written = os.write(descriptor, remaining)
        if written <= 0:
            raise OSError("short write while staging install manifest transition")
        remaining = remaining[written:]
    os.fsync(descriptor)
    os.close(descriptor)
    descriptor = -1
    staged_snapshot = snapshot(manifest.parent / temporary_name)
    observed = snapshot(manifest)
    if observed[0] != manifest_snapshot[0] or observed[2] != manifest_snapshot[2]:
        raise RuntimeError("install manifest changed before atomic transition")
    # keyguide-atomic-manifest-transition-observation-checked
    exchange_paths(directory_descriptor, temporary_name, manifest.name)
    preserve_temporary = True

    def abort_transition(message):
        global preserve_temporary
        quarantine = manifest.parent / temporary_name
        try:
            current_snapshot = snapshot(manifest)
        except (OSError, RuntimeError):
            raise RuntimeError(
                f"{message}; displaced manifest preserved at {quarantine}"
            )
        if same_exchanged_snapshot(current_snapshot, staged_snapshot):
            try:
                exchange_paths(
                    directory_descriptor, temporary_name, manifest.name
                )
                os.fsync(directory_descriptor)
            except OSError as error:
                raise RuntimeError(
                    f"{message}; rollback failed and displaced manifest "
                    f"is preserved at {quarantine}: {error}"
                ) from error
            try:
                rolled_temporary = snapshot(quarantine)
            except (OSError, RuntimeError):
                raise RuntimeError(
                    f"{message}; concurrent manifest preserved at {quarantine}"
                )
            if same_exchanged_snapshot(rolled_temporary, staged_snapshot):
                preserve_temporary = False
                raise RuntimeError(message)
            raise RuntimeError(
                f"{message}; concurrent manifest preserved at {quarantine}"
            )
        raise RuntimeError(
            f"{message}; displaced manifest preserved at {quarantine}"
        )

    try:
        displaced_snapshot = snapshot(manifest.parent / temporary_name)
    except (OSError, RuntimeError):
        abort_transition("install manifest changed during atomic transition")
    if not same_exchanged_snapshot(displaced_snapshot, manifest_snapshot):
        abort_transition("install manifest changed during atomic transition")
    try:
        published_snapshot = snapshot(manifest)
    except (OSError, RuntimeError) as error:
        raise RuntimeError(
            "install manifest changed immediately after atomic transition; "
            f"displaced manifest preserved at {manifest.parent / temporary_name}"
        ) from error
    if not same_exchanged_snapshot(published_snapshot, staged_snapshot):
        raise RuntimeError(
            "install manifest changed immediately after atomic transition; "
            f"displaced manifest preserved at {manifest.parent / temporary_name}"
        )
    os.unlink(temporary_name, dir_fd=directory_descriptor)
    preserve_temporary = False
    temporary_name = ""
    os.fsync(directory_descriptor)
    print(hashlib.sha256(manifest_bytes).hexdigest())
finally:
    if descriptor >= 0:
        os.close(descriptor)
    if temporary_name and not preserve_temporary:
        try:
            os.unlink(temporary_name, dir_fd=directory_descriptor)
        except FileNotFoundError:
            pass
    os.close(directory_descriptor)
PY
  ) || fail "could not publish install manifest transition: $transition"
  [[ $next_manifest_sha256 =~ ^[0-9a-f]{64}$ ]] ||
    fail "invalid install manifest transition digest: $transition"
  validated_manifest_sha256=$next_manifest_sha256
}

regular_endpoint_state() {
  python3 - "$1" <<'PY'
import hashlib
import os
import stat
import sys

path = sys.argv[1]
try:
    descriptor = os.open(
        path,
        os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
    )
except FileNotFoundError:
    print("absent - - - -")
    raise SystemExit(0)
except OSError as error:
    raise SystemExit(f"could not inspect endpoint without following links: {error}")
try:
    info = os.fstat(descriptor)
    if not stat.S_ISREG(info.st_mode):
        raise SystemExit("endpoint is not a regular file")
    digest = hashlib.sha256()
    while True:
        chunk = os.read(descriptor, 65536)
        if not chunk:
            break
        digest.update(chunk)
    print(
        "present",
        digest.hexdigest(),
        format(stat.S_IMODE(info.st_mode), "o"),
        str(info.st_uid),
        str(info.st_gid),
    )
finally:
    os.close(descriptor)
PY
}

clear_staged_bar_output() {
  local staged_shell=${bar_staging_path:-}
  [[ -n $staged_shell ]] || return 0
  python3 - "$staged_shell" "$state_dir" "$bar_staging_sha256" "$bar_staging_mode" <<'PY'
import hashlib
import os
from pathlib import Path
import stat
import sys

staged_shell = Path(sys.argv[1])
state_dir = Path(sys.argv[2])
expected_sha256 = sys.argv[3]
expected_mode = int(sys.argv[4], 8)

try:
    staged_shell.relative_to(state_dir)
except ValueError as error:
    raise RuntimeError("bar staging shell escapes installer state") from error

try:
    descriptor = os.open(staged_shell, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
except FileNotFoundError:
    descriptor = -1
else:
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError("bar staging shell is not a regular file")
        digest = hashlib.sha256()
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            digest.update(chunk)
        if digest.hexdigest() != expected_sha256:
            raise RuntimeError("bar staging shell changed before cleanup")
        if stat.S_IMODE(info.st_mode) != expected_mode:
            raise RuntimeError("bar staging shell mode changed before cleanup")
    finally:
        os.close(descriptor)
    parent_descriptor = os.open(
        staged_shell.parent,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
    )
    try:
        os.unlink(staged_shell.name, dir_fd=parent_descriptor)
        os.fsync(parent_descriptor)
    finally:
        os.close(parent_descriptor)

for directory in (
    staged_shell.parent,
    staged_shell.parent.parent,
    staged_shell.parent.parent.parent / ".local/share",
    staged_shell.parent.parent.parent / ".local",
    staged_shell.parent.parent.parent,
):
    try:
        directory.rmdir()
    except OSError:
        pass
PY
}

remove_authenticated_file() {
  python3 - "$1" "$2" "$3" <<'PY'
import ctypes
import hashlib
import os
from pathlib import Path
import stat
import sys
import tempfile

path = Path(sys.argv[1])
expected_sha256 = sys.argv[2]
label = sys.argv[3]
parent_descriptor = os.open(
    path.parent,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)


def snapshot_name(name):
    try:
        descriptor = os.open(
            name,
            os.O_RDONLY
            | os.O_CLOEXEC
            | os.O_NOFOLLOW
            | os.O_NONBLOCK,
            dir_fd=parent_descriptor,
        )
    except FileNotFoundError:
        return None
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError(f"{label} is not a regular file")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks)
    finally:
        os.close(descriptor)


def rename_noreplace(left, right):
    renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
    renameat2.argtypes = (
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    )
    renameat2.restype = ctypes.c_int
    if renameat2(
        parent_descriptor,
        os.fsencode(left),
        parent_descriptor,
        os.fsencode(right),
        1,
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


temporary_name = ""
preserve_temporary = False
try:
    expected_bytes = snapshot_name(path.name)
    if expected_bytes is None:
        raise SystemExit(0)
    if hashlib.sha256(expected_bytes).hexdigest() != expected_sha256:
        raise RuntimeError(f"{label} changed before atomic removal")
    descriptor, temporary_path = tempfile.mkstemp(
        prefix=f".{path.name}.keyguide-remove-",
        suffix=".tmp",
        dir=path.parent,
    )
    os.close(descriptor)
    temporary_name = Path(temporary_path).name
    os.unlink(temporary_name, dir_fd=parent_descriptor)
    # keyguide-atomic-owned-file-remove-observation-checked
    rename_noreplace(path.name, temporary_name)
    preserve_temporary = True
    try:
        displaced_bytes = snapshot_name(temporary_name)
    except (OSError, RuntimeError) as error:
        try:
            rename_noreplace(temporary_name, path.name)
            preserve_temporary = False
        except OSError:
            pass
        raise RuntimeError(f"{label} changed during atomic removal") from error
    if displaced_bytes != expected_bytes:
        try:
            rename_noreplace(temporary_name, path.name)
            preserve_temporary = False
        except OSError as error:
            raise RuntimeError(
                f"{label} changed during atomic removal; displaced endpoint "
                f"preserved at {path.parent / temporary_name}"
            ) from error
        raise RuntimeError(f"{label} changed during atomic removal")
    os.unlink(temporary_name, dir_fd=parent_descriptor)
    preserve_temporary = False
    temporary_name = ""
    os.fsync(parent_descriptor)
finally:
    if temporary_name and not preserve_temporary:
        try:
            os.unlink(temporary_name, dir_fd=parent_descriptor)
        except FileNotFoundError:
            pass
    os.close(parent_descriptor)
PY
}

recover_displaced_pending_payload() {
  python3 - "$manifest_path" "$validated_manifest_sha256" "$target_home" <<'PY'
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

manifest = Path(sys.argv[1])
expected_manifest_sha256 = sys.argv[2]
target_home = Path(sys.argv[3])
manifest_descriptor = os.open(
    manifest, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
)
try:
    info = os.fstat(manifest_descriptor)
    if not stat.S_ISREG(info.st_mode):
        raise RuntimeError("install manifest is not a regular file")
    chunks = []
    while True:
        chunk = os.read(manifest_descriptor, 65536)
        if not chunk:
            break
        chunks.append(chunk)
finally:
    os.close(manifest_descriptor)
manifest_bytes = b"".join(chunks)
if hashlib.sha256(manifest_bytes).hexdigest() != expected_manifest_sha256:
    raise RuntimeError("install manifest changed before payload recovery")
document = json.loads(manifest_bytes.decode("utf-8"))
pending = document.get("pending_reservation")
if not isinstance(pending, dict) or "payload_sha256" not in pending:
    raise SystemExit(0)
destination = Path(pending["path"])
temporary = Path(pending["temporary_path"])
if destination.parent != temporary.parent:
    raise RuntimeError("pending payload paths are not adjacent")
try:
    relative_parent = destination.parent.relative_to(target_home)
except ValueError as error:
    raise RuntimeError("pending payload parent escapes target home") from error
parent_descriptor = os.open(
    target_home,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)
for component in relative_parent.parts:
    if component in {"", ".", ".."}:
        os.close(parent_descriptor)
        raise RuntimeError("pending payload parent has an invalid component")
    next_descriptor = os.open(
        component,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
        dir_fd=parent_descriptor,
    )
    os.close(parent_descriptor)
    parent_descriptor = next_descriptor


def endpoint(name):
    try:
        path_info = os.stat(name, dir_fd=parent_descriptor, follow_symlinks=False)
    except FileNotFoundError:
        return None
    identity = (
        path_info.st_dev,
        path_info.st_ino,
        path_info.st_mode,
        path_info.st_size,
        path_info.st_mtime_ns,
    )
    if stat.S_ISLNK(path_info.st_mode):
        return ("symlink", identity, os.readlink(name, dir_fd=parent_descriptor))
    if not stat.S_ISREG(path_info.st_mode):
        return ("nonregular", identity, None)
    try:
        descriptor = os.open(
            name,
            os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
            dir_fd=parent_descriptor,
        )
    except OSError as error:
        if error.errno in {errno.ELOOP, errno.ENOENT}:
            raise RuntimeError("pending endpoint changed during observation") from error
        raise
    try:
        opened_info = os.fstat(descriptor)
        if (opened_info.st_dev, opened_info.st_ino) != identity[:2]:
            raise RuntimeError("pending endpoint changed during observation")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return ("regular", identity, b"".join(chunks))
    finally:
        os.close(descriptor)


def is_token(observed):
    return (
        observed is not None
        and observed[0] == "regular"
        and observed[2] == pending["token"].encode("ascii")
        and stat.S_IMODE(observed[1][2]) == 0o600
    )


def is_payload(observed):
    return (
        observed is not None
        and observed[0] == "regular"
        and stat.S_IMODE(observed[1][2]) == pending["payload_mode"]
        and hashlib.sha256(observed[2]).hexdigest()
        == pending["payload_sha256"]
    )


def same_endpoint(left, right):
    return left is not None and right is not None and left == right


def exchange(left, right):
    renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
    renameat2.argtypes = (
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    )
    renameat2.restype = ctypes.c_int
    if renameat2(
        parent_descriptor,
        os.fsencode(left),
        parent_descriptor,
        os.fsencode(right),
        2,
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


try:
    canonical = endpoint(destination.name)
    displaced = endpoint(temporary.name)
    if (
        not is_payload(canonical)
        or displaced is None
        or is_token(displaced)
        or is_payload(displaced)
    ):
        raise SystemExit(0)

    # keyguide-atomic-payload-recovery-observation-checked
    exchange(temporary.name, destination.name)
    os.fsync(parent_descriptor)
    restored = endpoint(destination.name)
    recovered_payload = endpoint(temporary.name)
    if same_endpoint(restored, displaced) and same_endpoint(
        recovered_payload, canonical
    ):
        raise SystemExit(0)

    if same_endpoint(recovered_payload, canonical):
        # The latest endpoint is already canonical.  Preserve it and let the
        # normal journal remove only the authenticated payload staging file.
        raise RuntimeError(
            "payload recovery observed a concurrent endpoint change"
        )
    try:
        exchange(temporary.name, destination.name)
        os.fsync(parent_descriptor)
    except OSError as error:
        raise RuntimeError(
            f"payload recovery rollback failed; endpoints preserved at "
            f"{destination} and {temporary}"
        ) from error
    raise RuntimeError("payload recovery changed during atomic exchange")
finally:
    os.close(parent_descriptor)
PY
}

ensure_upgrade_handoff_reservations() {
  python3 - "$manifest_path" "$validated_manifest_sha256" "$target_home" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

manifest = Path(sys.argv[1])
expected_manifest_sha256 = sys.argv[2]
target_home = Path(sys.argv[3])
descriptor = os.open(
    manifest, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
)
try:
    info = os.fstat(descriptor)
    if not stat.S_ISREG(info.st_mode):
        raise RuntimeError("upgrade manifest is not a regular file")
    chunks = []
    while True:
        chunk = os.read(descriptor, 65536)
        if not chunk:
            break
        chunks.append(chunk)
finally:
    os.close(descriptor)
manifest_bytes = b"".join(chunks)
if hashlib.sha256(manifest_bytes).hexdigest() != expected_manifest_sha256:
    raise RuntimeError("upgrade manifest changed before reservation recovery")
document = json.loads(manifest_bytes.decode("utf-8"))
handoff = document.get("upgrade_handoff")
if not isinstance(handoff, dict) or not isinstance(
    handoff.get("reservations"), list
):
    raise RuntimeError("upgrade handoff journal is unavailable")

def open_parent_no_symlink(path):
    try:
        relative_parent = path.parent.relative_to(target_home)
    except ValueError as error:
        raise RuntimeError(f"upgrade reservation escapes target home: {path}") from error
    descriptor = os.open(
        target_home, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    )
    try:
        for component in relative_parent.parts:
            if component in {"", ".", ".."}:
                raise RuntimeError(f"upgrade reservation has unsafe component: {path}")
            try:
                next_descriptor = os.open(
                    component,
                    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                    dir_fd=descriptor,
                )
            except FileNotFoundError:
                os.mkdir(component, 0o755, dir_fd=descriptor)
                os.fsync(descriptor)
                next_descriptor = os.open(
                    component,
                    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
                    dir_fd=descriptor,
                )
            except OSError as error:
                raise RuntimeError(
                    f"symlinked upgrade reservation parent component: {path}"
                ) from error
            os.close(descriptor)
            descriptor = next_descriptor
        return descriptor
    except Exception:
        os.close(descriptor)
        raise

for reservation in handoff["reservations"]:
    path = Path(reservation["path"])
    temporary = Path(reservation["temporary_path"])
    token = reservation["token"].encode("ascii")
    try:
        path.relative_to(target_home)
    except ValueError as error:
        raise RuntimeError(f"upgrade reservation escapes target home: {path}") from error
    parent_descriptor = open_parent_no_symlink(path)
    staging_descriptor = -1
    final_descriptor = -1
    staging_created = False
    try:
        try:
            staging_descriptor = os.open(
                temporary.name,
                os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
                dir_fd=parent_descriptor,
            )
        except FileNotFoundError:
            staging_created = True
            staging_descriptor = os.open(
                temporary.name,
                os.O_WRONLY
                | os.O_CREAT
                | os.O_EXCL
                | os.O_CLOEXEC
                | os.O_NOFOLLOW,
                0o600,
                dir_fd=parent_descriptor,
            )
            remaining = memoryview(token)
            while remaining:
                written = os.write(staging_descriptor, remaining)
                if written <= 0:
                    raise OSError("short write while staging upgrade reservation")
                remaining = remaining[written:]
            os.fsync(staging_descriptor)
            os.close(staging_descriptor)
            staging_descriptor = os.open(
                temporary.name,
                os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
                dir_fd=parent_descriptor,
            )
        staging_info = os.fstat(staging_descriptor)
        staging_bytes = os.read(staging_descriptor, len(token) + 1)
        if (
            not stat.S_ISREG(staging_info.st_mode)
            or stat.S_IMODE(staging_info.st_mode) != 0o600
            or staging_info.st_size != len(token)
            or staging_bytes != token
        ):
            raise RuntimeError(f"upgrade reservation staging path changed: {temporary}")
        try:
            final_descriptor = os.open(
                path.name,
                os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
                dir_fd=parent_descriptor,
            )
        except FileNotFoundError:
            os.link(
                temporary.name,
                path.name,
                src_dir_fd=parent_descriptor,
                dst_dir_fd=parent_descriptor,
                follow_symlinks=False,
            )
            final_descriptor = os.open(
                path.name,
                os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
                dir_fd=parent_descriptor,
            )
        final_info = os.fstat(final_descriptor)
        final_bytes = os.read(final_descriptor, len(token) + 1)
        if (
            not stat.S_ISREG(final_info.st_mode)
            or stat.S_IMODE(final_info.st_mode) != 0o600
            or final_info.st_size != len(token)
            or final_bytes != token
            or (
                (final_info.st_dev, final_info.st_ino)
                != (staging_info.st_dev, staging_info.st_ino)
                and not staging_created
            )
        ):
            raise RuntimeError(f"refusing to overwrite unowned path: {path}")
        os.unlink(temporary.name, dir_fd=parent_descriptor)
        os.fsync(parent_descriptor)
    finally:
        if final_descriptor >= 0:
            os.close(final_descriptor)
        if staging_descriptor >= 0:
            os.close(staging_descriptor)
        os.close(parent_descriptor)
PY
}

restore_shell_endpoint() {
  local backup_path=$1
  local destination_path=$2
  local final_mode=$3
  local final_sha256=$4
  local expected_present=$5
  local expected_sha256=$6
  local expected_mode=$7
  local final_uid=$8
  local final_gid=$9
  python3 - \
    "$backup_path" \
    "$destination_path" \
    "$final_mode" \
    "$final_sha256" \
    "$expected_present" \
    "$expected_sha256" \
    "$expected_mode" \
    "$final_uid" \
    "$final_gid" <<'PY'
# keyguide-atomic-shell-restore
import ctypes
import hashlib
import os
from pathlib import Path
import stat
import sys
import tempfile

(
    backup_arg,
    destination_arg,
    final_mode_arg,
    final_sha256,
    expected_present_arg,
    expected_sha256,
    expected_mode_arg,
    final_uid_arg,
    final_gid_arg,
) = sys.argv[1:]
destination = Path(destination_arg)
parent_descriptor = os.open(
    destination.parent,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)


def snapshot_name(name):
    try:
        descriptor = os.open(
            name,
            os.O_RDONLY
            | os.O_CLOEXEC
            | os.O_NOFOLLOW
            | os.O_NONBLOCK,
            dir_fd=parent_descriptor,
        )
    except FileNotFoundError:
        return None
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError("live shell endpoint is not a regular file")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return (
            b"".join(chunks),
            info,
            (
                info.st_dev,
                info.st_ino,
                info.st_mode,
                info.st_size,
                info.st_mtime_ns,
                info.st_ctime_ns,
            ),
        )
    finally:
        os.close(descriptor)


def same_exchanged_snapshot(observed, expected):
    return observed[0] == expected[0] and observed[2][:5] == expected[2][:5]


def expected_owner():
    if not final_uid_arg or not final_gid_arg:
        return None
    return int(final_uid_arg), int(final_gid_arg)


def verify_final_owner(snapshot, label):
    owner = expected_owner()
    if owner is None:
        return
    uid, gid = owner
    if snapshot[1].st_uid != uid or snapshot[1].st_gid != gid:
        raise RuntimeError(f"{label} owner/group does not match authenticated pre-image")


def renameat2_paths(left, right, flags):
    renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
    renameat2.argtypes = (
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    )
    renameat2.restype = ctypes.c_int
    if renameat2(
        parent_descriptor,
        os.fsencode(left),
        parent_descriptor,
        os.fsencode(right),
        flags,
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


expected_present = expected_present_arg == "true"


def verify_expected_endpoint(reference=None):
    observed = snapshot_name(destination.name)
    present = observed is not None
    if present != expected_present:
        raise RuntimeError("live shell endpoint presence changed during restoration")
    if expected_present:
        sha256 = hashlib.sha256(observed[0]).hexdigest()
        mode = format(stat.S_IMODE(observed[1].st_mode), "o")
        if sha256 != expected_sha256:
            raise RuntimeError("live shell endpoint bytes changed during restoration")
        if expected_mode_arg != "-" and mode != expected_mode_arg:
            raise RuntimeError("live shell endpoint mode changed during restoration")
    if reference is not None:
        if observed is None or not same_exchanged_snapshot(observed, reference):
            raise RuntimeError("live shell endpoint changed during restoration")
    return observed

temporary_descriptor = -1
temporary_name = ""
preserve_temporary = False
try:
    expected_snapshot = verify_expected_endpoint()
    if backup_arg != "-":
        backup_descriptor = os.open(
            backup_arg,
            os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
        )
        try:
            if not stat.S_ISREG(os.fstat(backup_descriptor).st_mode):
                raise RuntimeError("shell backup is not a regular file")
            temporary_descriptor, temporary_path = tempfile.mkstemp(
                prefix=f".{destination.name}.keyguide-restore-",
                suffix=".tmp",
                dir=destination.parent,
            )
            temporary_name = Path(temporary_path).name
            os.fchmod(temporary_descriptor, int(final_mode_arg, 8))
            owner = expected_owner()
            if owner is not None:
                uid, gid = owner
                if os.geteuid() == 0:
                    os.fchown(temporary_descriptor, uid, gid)
                else:
                    staged_info = os.fstat(temporary_descriptor)
                    if staged_info.st_uid != uid or staged_info.st_gid != gid:
                        raise RuntimeError(
                            "cannot preserve shell owner/group during restoration"
                        )
            digest = hashlib.sha256()
            while True:
                chunk = os.read(backup_descriptor, 65536)
                if not chunk:
                    break
                digest.update(chunk)
                remaining = memoryview(chunk)
                while remaining:
                    written = os.write(temporary_descriptor, remaining)
                    if written <= 0:
                        raise OSError("short write while staging shell pre-image")
                    remaining = remaining[written:]
            if digest.hexdigest() != final_sha256:
                raise RuntimeError("staged shell bytes do not match pre-image hash")
            os.fsync(temporary_descriptor)
        finally:
            os.close(backup_descriptor)
        os.close(temporary_descriptor)
        temporary_descriptor = -1
        hook = os.environ.get("KEYGUIDE_TEST_HOOK_SHELL_RESTORE_OWNER_LOSS")
        if hook and not Path(hook).exists():
            marker = Path(hook)
            marker.touch()
            raise RuntimeError(
                "staged shell restore owner/group does not match authenticated pre-image"
            )
        staged_snapshot = snapshot_name(temporary_name)
        verify_final_owner(staged_snapshot, "staged shell restore")
        verify_expected_endpoint(expected_snapshot)
        # keyguide-atomic-shell-restore-observation-checked
        renameat2_paths(temporary_name, destination.name, 2)
        preserve_temporary = True

        def abort_restore_exchange(message):
            quarantine = destination.parent / temporary_name
            try:
                current_snapshot = snapshot_name(destination.name)
            except (OSError, RuntimeError):
                raise RuntimeError(
                    f"{message}; displaced endpoint preserved at {quarantine}"
                )
            if (
                current_snapshot is not None
                and same_exchanged_snapshot(current_snapshot, staged_snapshot)
            ):
                try:
                    renameat2_paths(temporary_name, destination.name, 2)
                    os.fsync(parent_descriptor)
                except OSError as error:
                    raise RuntimeError(
                        f"{message}; rollback failed and displaced endpoint "
                        f"is preserved at {quarantine}: {error}"
                    ) from error
                try:
                    rolled_temporary = snapshot_name(temporary_name)
                except (OSError, RuntimeError):
                    raise RuntimeError(
                        f"{message}; a concurrent endpoint is preserved at "
                        f"{quarantine}"
                    )
                if same_exchanged_snapshot(
                    rolled_temporary, staged_snapshot
                ):
                    return True
                raise RuntimeError(
                    f"{message}; a concurrent endpoint is preserved at "
                    f"{quarantine}"
                )
            raise RuntimeError(
                f"{message}; displaced endpoint preserved at {quarantine}"
            )

        try:
            displaced_snapshot = snapshot_name(temporary_name)
        except (OSError, RuntimeError):
            if abort_restore_exchange(
                "live shell endpoint bytes changed during atomic restoration"
            ):
                preserve_temporary = False
                raise RuntimeError(
                    "live shell endpoint bytes changed during atomic restoration"
                )
        if not same_exchanged_snapshot(displaced_snapshot, expected_snapshot):
            if abort_restore_exchange(
                "live shell endpoint bytes changed during atomic restoration"
            ):
                preserve_temporary = False
                raise RuntimeError(
                    "live shell endpoint bytes changed during atomic restoration"
                )
        try:
            published_snapshot = snapshot_name(destination.name)
        except (OSError, RuntimeError) as error:
            raise RuntimeError(
                "live shell endpoint changed immediately after atomic restoration; "
                f"displaced endpoint preserved at {destination.parent / temporary_name}"
            ) from error
        if not same_exchanged_snapshot(published_snapshot, staged_snapshot):
            raise RuntimeError(
                "live shell endpoint changed immediately after atomic restoration; "
                f"displaced endpoint preserved at {destination.parent / temporary_name}"
            )
        verify_final_owner(published_snapshot, "restored shell")
        os.unlink(temporary_name, dir_fd=parent_descriptor)
        preserve_temporary = False
        temporary_name = ""
    else:
        verify_expected_endpoint(expected_snapshot)
        if expected_present:
            temporary_descriptor, temporary_path = tempfile.mkstemp(
                prefix=f".{destination.name}.keyguide-remove-",
                suffix=".tmp",
                dir=destination.parent,
            )
            temporary_name = Path(temporary_path).name
            os.close(temporary_descriptor)
            temporary_descriptor = -1
            os.unlink(temporary_name, dir_fd=parent_descriptor)
            # keyguide-atomic-shell-remove-observation-checked
            renameat2_paths(destination.name, temporary_name, 1)
            preserve_temporary = True
            try:
                displaced_snapshot = snapshot_name(temporary_name)
            except (OSError, RuntimeError) as error:
                try:
                    renameat2_paths(temporary_name, destination.name, 1)
                    preserve_temporary = False
                except OSError:
                    pass
                raise RuntimeError(
                    "live shell endpoint changed during atomic removal"
                ) from error
            if not same_exchanged_snapshot(
                displaced_snapshot, expected_snapshot
            ):
                try:
                    renameat2_paths(temporary_name, destination.name, 1)
                    preserve_temporary = False
                except OSError as error:
                    raise RuntimeError(
                        "live shell endpoint changed during atomic removal; "
                        f"displaced endpoint preserved at {destination.parent / temporary_name}"
                    ) from error
                raise RuntimeError(
                    "live shell endpoint changed during atomic removal"
                )
            os.unlink(temporary_name, dir_fd=parent_descriptor)
            preserve_temporary = False
            temporary_name = ""
    os.fsync(parent_descriptor)
finally:
    if temporary_descriptor >= 0:
        os.close(temporary_descriptor)
    if temporary_name and not preserve_temporary:
        try:
            os.unlink(temporary_name, dir_fd=parent_descriptor)
        except FileNotFoundError:
            pass
    os.close(parent_descriptor)
PY
}

if [[ $install_state != restart_pending ]]; then
  if [[ -z $prefix_root ]]; then
    should_disable=$plugin_enabled_by_installer
    should_restore_shell=false
    if [[ $should_disable == true || $bar_placement_owned_by_installer == true || $bar_placement_state == placing ]]; then
      should_restore_shell=true
    fi
    if [[ $should_restore_shell == true ]]; then
      if [[ $bar_placement_state == placing && $placing_recovery == insertion ]]; then
        update_manifest bar_placed_recovered "$placing_post_sha256"
        bar_placement_state=placed
        bar_placement_owned_by_installer=true
        shell_post_enable_sha256=$placing_post_sha256
        shell_post_enable_present=true
      elif [[ $bar_placement_state == placing && $placing_recovery != preimage ]]; then
        fail "placing bar transform has no authenticated recovery endpoint"
      fi
      if [[ $shell_preexisting == true ]]; then
        backup_endpoint_state=$(regular_endpoint_state "$shell_backup") ||
          fail "shell config backup is unavailable"
        read -r backup_present current_backup_sha256 current_backup_mode current_backup_uid current_backup_gid \
          <<<"$backup_endpoint_state"
        [[ $backup_present == present && $current_backup_mode == 600 &&
          $shell_pre_sha256 != - && $current_backup_sha256 == "$shell_pre_sha256" ]] ||
          fail "shell config backup does not match authenticated pre-image hash"
        if [[ -n $shell_pre_uid ]]; then
          [[ $current_backup_uid == "$shell_pre_uid" &&
            $current_backup_gid == "$shell_pre_gid" ]] ||
            fail "shell config backup owner does not match authenticated pre-image"
        fi
      fi
      shell_endpoint_state=$(regular_endpoint_state "$shell_config") ||
        fail "shell config endpoint is not a regular file"
      read -r current_shell_present current_shell_sha256 current_shell_mode current_shell_uid current_shell_gid \
        <<<"$shell_endpoint_state"
      current_matches_postimage=false
      if [[ $shell_post_enable_present == true ]]; then
        if [[ $current_shell_present == present &&
          $shell_post_enable_sha256 != - &&
          $current_shell_sha256 == "$shell_post_enable_sha256" ]]; then
          current_matches_postimage=true
        fi
      elif [[ $current_shell_present == absent ]]; then
        current_matches_postimage=true
      fi
      current_matches_preimage=false
      if [[ $shell_preexisting == true ]]; then
        if [[ $current_shell_present == present &&
          $current_shell_sha256 == "$shell_pre_sha256" &&
          $current_shell_mode == "$shell_pre_mode" ]]; then
          if [[ -z $shell_pre_uid || ( $current_shell_uid == "$shell_pre_uid" &&
            $current_shell_gid == "$shell_pre_gid" ) ]]; then
            current_matches_preimage=true
          fi
        fi
      elif [[ $current_shell_present == absent ]]; then
        current_matches_preimage=true
      fi

      resume_from_preimage=false
      if [[ $bar_placement_state == placing && $placing_recovery == preimage ]]; then
        [[ $current_matches_preimage == true ]] ||
          fail "placing bar transform no longer matches its authenticated pre-image"
        if [[ $shell_restore_state == not_started ]]; then
          update_manifest shell_restoring
          shell_restore_state=restoring
        elif [[ $shell_restore_state != restoring ]]; then
          fail "placing bar transform has an unexpected restore state"
        fi
        resume_from_preimage=true
      elif [[ $shell_restore_state == restoring ]]; then
        if [[ $current_matches_postimage == true ]]; then
          :
        elif [[ $current_matches_preimage == true ]]; then
          resume_from_preimage=true
        else
          fail "shell config matches neither authenticated installed nor restored state"
        fi
      else
        if [[ $current_matches_postimage != true ]]; then
          if [[ $bar_placement_owned_by_installer == true ]]; then
            fail "bar configuration changed after installation; refusing to disable or overwrite it"
          elif [[ $shell_post_enable_present == true ]]; then
            fail "shell config changed after install; refusing to disable or overwrite it"
          else
            fail "shell config appeared after install; refusing to disable or overwrite it"
          fi
        fi
        update_manifest shell_restoring
        shell_restore_state=restoring
      fi

      if [[ $resume_from_preimage == true ]]; then
        expected_shell_present=$shell_preexisting
        expected_shell_sha256=$shell_pre_sha256
        expected_shell_mode=$shell_pre_mode
      else
        expected_shell_present=$shell_post_enable_present
        expected_shell_sha256=$shell_post_enable_sha256
        expected_shell_mode=-
      fi
      keyguide_require_live_session_unlocked uninstall

      restore_shell_endpoint \
        "$shell_backup" \
        "$shell_config" \
        "$shell_pre_mode" \
        "$shell_pre_sha256" \
        "$expected_shell_present" \
        "$expected_shell_sha256" \
        "$expected_shell_mode" \
        "$shell_pre_uid" \
        "$shell_pre_gid"

      clear_staged_bar_output ||
        fail "could not clean staged bar output"

      if [[ $shell_preexisting == true ]]; then
        restored_endpoint_state=$(regular_endpoint_state "$shell_config") ||
          fail "restored shell config is unavailable"
        read -r restored_shell_present restored_shell_sha256 restored_shell_mode restored_shell_uid restored_shell_gid \
          <<<"$restored_endpoint_state"
        [[ $restored_shell_present == present &&
          $restored_shell_sha256 == "$shell_pre_sha256" &&
          $restored_shell_mode == "$shell_pre_mode" ]] ||
          fail "restored shell config does not match authenticated pre-image"
        if [[ -n $shell_pre_uid ]]; then
          [[ $restored_shell_uid == "$shell_pre_uid" &&
            $restored_shell_gid == "$shell_pre_gid" ]] ||
            fail "restored shell config owner does not match authenticated pre-image"
        fi
      else
        restored_endpoint_state=$(regular_endpoint_state "$shell_config") ||
          fail "restored shell config endpoint is invalid"
        read -r restored_shell_present _ _ _ _ <<<"$restored_endpoint_state"
      fi
      if [[ $shell_preexisting != true && $restored_shell_present != absent ]]; then
        if [[ $bar_placement_owned_by_installer == true ]]; then
          fail "restored bar configuration should be absent"
        else
          fail "restored shell config should be absent"
        fi
      fi
      update_manifest shell_restored
      plugin_enabled_by_installer=false
      bar_placement_owned_by_installer=false
      if [[ $bar_placement_state == placing || $bar_placement_state == placed ]]; then
        bar_placement_state=restored
      fi
      if [[ $should_disable == true ]]; then
        plugin_enable_state=disabled
      fi
    fi
  fi

  if [[ -z $file_removal_token ]]; then
    keyguide_require_live_session_unlocked uninstall

    recover_displaced_pending_payload ||
      fail "could not recover a displaced pending payload"
    file_removal_token=$(python3 - <<'PY'
import secrets

print(secrets.token_hex(32))
PY
) ||
      fail "could not create file removal token"
    update_manifest files_removing "$file_removal_token"
  fi

  python3 - \
    "$target_home" \
    "$manifest_path" \
    "$validated_manifest_sha256" <<'PY' || fail "could not remove validated install paths"
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

target_home_arg, manifest_arg, expected_manifest_sha256 = sys.argv[1:]
target_home = Path(target_home_arg)
manifest_path = Path(manifest_arg)
directory_paths = [
    target_home / ".config/omarchy/plugins/mrai.keyguide/components",
    target_home / ".config/omarchy/plugins/mrai.keyguide",
    target_home / ".local/lib/omarchy-keyguide/bin",
    target_home / ".local/lib/omarchy-keyguide/keyguide_backend",
    target_home / ".local/lib/omarchy-keyguide",
]


def read_regular(descriptor):
    info = os.fstat(descriptor)
    if not stat.S_ISREG(info.st_mode):
        raise RuntimeError("endpoint is not a regular file")
    digest = hashlib.sha256()
    while True:
        chunk = os.read(descriptor, 65536)
        if not chunk:
            break
        digest.update(chunk)
    return {
        "sha256": digest.hexdigest(),
        "mode": stat.S_IMODE(info.st_mode),
        "device": info.st_dev,
        "inode": info.st_ino,
        "size": info.st_size,
        "mtime_ns": info.st_mtime_ns,
    }


manifest_descriptor = os.open(
    manifest_path,
    os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
)
try:
    manifest_info = os.fstat(manifest_descriptor)
    if not stat.S_ISREG(manifest_info.st_mode):
        raise RuntimeError("install manifest is not a regular file")
    manifest_chunks = []
    while True:
        manifest_chunk = os.read(manifest_descriptor, 65536)
        if not manifest_chunk:
            break
        manifest_chunks.append(manifest_chunk)
finally:
    os.close(manifest_descriptor)
manifest_bytes = b"".join(manifest_chunks)
if hashlib.sha256(manifest_bytes).hexdigest() != expected_manifest_sha256:
    raise RuntimeError("install manifest changed before owned path removal")
document = json.loads(manifest_bytes.decode("utf-8"))
file_removal = document.get("file_removal")
if not isinstance(file_removal, dict):
    raise RuntimeError("install manifest lacks a file removal journal")
token = file_removal.get("token")
targets = file_removal.get("targets")
if (
    not isinstance(token, str)
    or len(token) != 64
    or any(character not in "0123456789abcdef" for character in token)
    or not isinstance(targets, list)
):
    raise RuntimeError("install manifest has a malformed file removal journal")


def relative_parts(path):
    try:
        return path.relative_to(target_home).parts
    except ValueError as error:
        raise SystemExit(f"refusing path outside target home: {path}") from error

home_descriptor = os.open(
    target_home,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)
descriptors = {}

def open_parent(parts):
    descriptor = os.dup(home_descriptor)
    try:
        for component in parts:
            next_descriptor = os.open(
                component,
                os.O_RDONLY
                | os.O_DIRECTORY
                | os.O_CLOEXEC
                | os.O_NOFOLLOW,
                dir_fd=descriptor,
            )
            os.close(descriptor)
            descriptor = next_descriptor
        return descriptor
    except FileNotFoundError:
        os.close(descriptor)
        return None
    except BaseException:
        os.close(descriptor)
        raise


def snapshot_name(parent_descriptor, name):
    try:
        descriptor = os.open(
            name,
            os.O_RDONLY
            | os.O_CLOEXEC
            | os.O_NOFOLLOW
            | os.O_NONBLOCK,
            dir_fd=parent_descriptor,
        )
    except FileNotFoundError:
        return None
    except OSError as error:
        raise RuntimeError("endpoint is not a regular file") from error
    try:
        return read_regular(descriptor)
    finally:
        os.close(descriptor)


def same_snapshot(observed, expected):
    return observed is not None and all(
        observed[key] == expected[key]
        for key in ("sha256", "mode", "device", "inode", "size", "mtime_ns")
    )


def rename_noreplace(parent_descriptor, left, right):
    renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
    renameat2.argtypes = (
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    )
    renameat2.restype = ctypes.c_int
    if renameat2(
        parent_descriptor,
        os.fsencode(left),
        parent_descriptor,
        os.fsencode(right),
        1,
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


def quarantine_name(path):
    return f".{path.name}.keyguide-remove-{token}.pending"

try:
    removal_paths = [Path(target["path"]) for target in targets]
    parent_parts = {
        relative_parts(path)[:-1]
        for path in removal_paths + directory_paths
    }
    for parts in sorted(parent_parts, key=lambda value: (len(value), value)):
        descriptors[parts] = open_parent(parts)

    active_targets = []
    for path, expected in zip(removal_paths, targets):
        parts = relative_parts(path)
        parent_descriptor = descriptors[parts[:-1]]
        if parent_descriptor is None:
            continue
        quarantine = quarantine_name(path)
        try:
            quarantined = snapshot_name(parent_descriptor, quarantine)
        except RuntimeError as error:
            raise RuntimeError(
                f"owned path recovery endpoint is invalid: {path.parent / quarantine}"
            ) from error
        try:
            canonical = snapshot_name(parent_descriptor, parts[-1])
        except RuntimeError as error:
            raise RuntimeError(
                f"owned path changed before atomic removal: {path}"
            ) from error
        if quarantined is not None:
            if not same_snapshot(quarantined, expected):
                raise RuntimeError(
                    "owned path recovery journal does not match its captured endpoint: "
                    f"{path.parent / quarantine}"
                )
            if canonical is not None:
                raise RuntimeError(
                    "owned path recovery found both canonical and captured endpoints; "
                    f"both are preserved: {path}, {path.parent / quarantine}"
                )
            try:
                rename_noreplace(parent_descriptor, quarantine, parts[-1])
                os.fsync(parent_descriptor)
            except OSError as error:
                raise RuntimeError(
                    "could not restore interrupted owned path capture; endpoint is "
                    f"preserved at {path.parent / quarantine}"
                ) from error
            canonical = snapshot_name(parent_descriptor, parts[-1])
        if canonical is None:
            continue
        if not same_snapshot(canonical, expected):
            raise RuntimeError(f"owned path changed before atomic removal: {path}")
        active_targets.append((path, expected, parts, parent_descriptor, quarantine))

    staged_targets = []
    try:
        for path, expected, parts, parent_descriptor, quarantine in active_targets:
            # keyguide-atomic-owned-program-remove-observation-checked
            rename_noreplace(parent_descriptor, parts[-1], quarantine)
            staged_targets.append(
                (path, expected, parts, parent_descriptor, quarantine)
            )
            # keyguide-atomic-owned-program-capture-durable
            try:
                captured = snapshot_name(parent_descriptor, quarantine)
            except RuntimeError as error:
                raise RuntimeError(
                    f"owned path changed during atomic removal: {path}"
                ) from error
            if not same_snapshot(captured, expected):
                raise RuntimeError(
                    f"owned path changed during atomic removal: {path}"
                )
        for path, _, parts, parent_descriptor, quarantine in staged_targets:
            try:
                appeared = snapshot_name(parent_descriptor, parts[-1])
            except RuntimeError as error:
                raise RuntimeError(
                    "a concurrent endpoint appeared during owned path removal: "
                    f"{path}"
                ) from error
            if appeared is not None:
                raise RuntimeError(
                    "a concurrent endpoint appeared during owned path removal: "
                    f"{path}"
                )
    except (OSError, RuntimeError) as error:
        retained = []
        for path, _, parts, parent_descriptor, quarantine in reversed(staged_targets):
            try:
                canonical = snapshot_name(parent_descriptor, parts[-1])
            except RuntimeError:
                canonical = {"nonregular": True}
            try:
                captured = snapshot_name(parent_descriptor, quarantine)
            except RuntimeError:
                captured = {"nonregular": True}
            if captured is None:
                continue
            if canonical is None:
                try:
                    rename_noreplace(parent_descriptor, quarantine, parts[-1])
                    os.fsync(parent_descriptor)
                    continue
                except OSError:
                    pass
            retained.append(str(path.parent / quarantine))
        detail = ""
        if retained:
            detail = "; captured endpoints preserved at " + ", ".join(retained)
        raise RuntimeError(f"{error}{detail}") from error

    for _, _, _, parent_descriptor, quarantine in staged_targets:
        os.unlink(quarantine, dir_fd=parent_descriptor)
        os.fsync(parent_descriptor)

    for path in directory_paths:
        parts = relative_parts(path)
        parent_descriptor = descriptors[parts[:-1]]
        if parent_descriptor is None:
            continue
        try:
            os.rmdir(parts[-1], dir_fd=parent_descriptor)
            os.fsync(parent_descriptor)
        except FileNotFoundError:
            pass
        except OSError as error:
            if error.errno not in {errno.ENOTEMPTY, errno.EEXIST}:
                raise
finally:
    for descriptor in descriptors.values():
        if descriptor is not None:
            os.close(descriptor)
    os.close(home_descriptor)
PY

  update_manifest restart_pending || fail "could not record pending shell restart"
fi

if [[ -z $prefix_root ]]; then
  keyguide_require_live_session_unlocked uninstall

  omarchy restart shell
fi

if [[ -n $upgrade_handoff_token ]]; then
  ready_shell_state=$(regular_endpoint_state "$shell_config") ||
    fail "upgrade-ready shell config is unavailable"
  read -r ready_shell_present ready_shell_sha256 ready_shell_mode ready_shell_uid ready_shell_gid \
    <<<"$ready_shell_state"
  [[ $ready_shell_present == present &&
    $ready_shell_sha256 == "$shell_pre_sha256" &&
    $ready_shell_mode == "$shell_pre_mode" ]] ||
    fail "upgrade-ready shell config does not match its authenticated baseline"
  if [[ -n $shell_pre_uid ]]; then
    [[ $ready_shell_uid == "$shell_pre_uid" &&
      $ready_shell_gid == "$shell_pre_gid" ]] ||
      fail "upgrade-ready shell config owner does not match its authenticated baseline"
  fi
  ready_backup_state=$(regular_endpoint_state "$shell_backup") ||
    fail "upgrade-ready shell backup is unavailable"
  read -r ready_backup_present ready_backup_sha256 ready_backup_mode ready_backup_uid ready_backup_gid \
    <<<"$ready_backup_state"
  [[ $ready_backup_present == present &&
    $ready_backup_sha256 == "$shell_pre_sha256" &&
    $ready_backup_mode == 600 ]] ||
    fail "upgrade-ready shell backup does not match its authenticated baseline"
  if [[ -n $shell_pre_uid ]]; then
    [[ $ready_backup_uid == "$shell_pre_uid" &&
      $ready_backup_gid == "$shell_pre_gid" ]] ||
      fail "upgrade-ready shell backup owner does not match its authenticated baseline"
  fi
  ensure_upgrade_handoff_reservations ||
    fail "could not recover upgrade destination reservations"
  update_manifest upgrade_ready || fail "could not record upgrade-ready state"
  echo "Prepared Omarchy Keyguide upgrade in $target_home"
  exit 0
fi

if [[ $shell_preexisting == true ]]; then
  remove_authenticated_file \
    "$shell_backup" \
    "$shell_pre_sha256" \
    "shell backup" || fail "could not remove authenticated shell backup"
fi

python3 - \
  "$target_home" \
  "$manifest_path" \
  "$validated_manifest_sha256" <<'PY' || fail "could not remove install manifest"
import ctypes
import errno
import hashlib
import os
from pathlib import Path
import stat
import sys
import tempfile

target_home = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])
expected_manifest_sha256 = sys.argv[3]
try:
    manifest_parts = manifest_path.relative_to(target_home).parts
except ValueError as error:
    raise SystemExit(f"refusing manifest outside target home: {manifest_path}") from error

home_descriptor = os.open(
    target_home,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)

def open_directory(parts):
    descriptor = os.dup(home_descriptor)
    try:
        for component in parts:
            next_descriptor = os.open(
                component,
                os.O_RDONLY
                | os.O_DIRECTORY
                | os.O_CLOEXEC
                | os.O_NOFOLLOW,
                dir_fd=descriptor,
            )
            os.close(descriptor)
            descriptor = next_descriptor
        return descriptor
    except BaseException:
        os.close(descriptor)
        raise

manifest_parent = open_directory(manifest_parts[:-1])
temporary_name = ""
preserve_temporary = False


def snapshot_name(name):
    descriptor = os.open(
        name,
        os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
        dir_fd=manifest_parent,
    )
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError("install manifest is not a regular file")
        chunks = []
        while True:
            chunk = os.read(descriptor, 1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks)
    finally:
        os.close(descriptor)


def rename_noreplace(left, right):
    renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
    renameat2.argtypes = (
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    )
    renameat2.restype = ctypes.c_int
    if renameat2(
        manifest_parent,
        os.fsencode(left),
        manifest_parent,
        os.fsencode(right),
        1,
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


try:
    expected_bytes = snapshot_name(manifest_parts[-1])
    if hashlib.sha256(expected_bytes).hexdigest() != expected_manifest_sha256:
        raise RuntimeError("install manifest changed before atomic removal")
    descriptor, temporary_path = tempfile.mkstemp(
        prefix=f".{manifest_path.name}.keyguide-remove-",
        suffix=".tmp",
        dir=manifest_path.parent,
    )
    os.close(descriptor)
    temporary_name = Path(temporary_path).name
    os.unlink(temporary_name, dir_fd=manifest_parent)
    # keyguide-atomic-final-manifest-remove-observation-checked
    rename_noreplace(manifest_parts[-1], temporary_name)
    preserve_temporary = True
    try:
        displaced_bytes = snapshot_name(temporary_name)
    except (OSError, RuntimeError) as error:
        try:
            rename_noreplace(temporary_name, manifest_parts[-1])
            preserve_temporary = False
        except OSError:
            pass
        raise RuntimeError(
            "install manifest changed during atomic removal"
        ) from error
    if displaced_bytes != expected_bytes:
        try:
            rename_noreplace(temporary_name, manifest_parts[-1])
            preserve_temporary = False
        except OSError as error:
            raise RuntimeError(
                "install manifest changed during atomic removal; "
                f"displaced manifest preserved at {manifest_path.parent / temporary_name}"
            ) from error
        raise RuntimeError("install manifest changed during atomic removal")
    os.unlink(temporary_name, dir_fd=manifest_parent)
    preserve_temporary = False
    temporary_name = ""
    os.fsync(manifest_parent)
finally:
    if temporary_name and not preserve_temporary:
        try:
            os.unlink(temporary_name, dir_fd=manifest_parent)
        except FileNotFoundError:
            pass
    os.close(manifest_parent)

state_parts = manifest_parts[:-1]
state_parent = open_directory(state_parts[:-1])
try:
    try:
        os.rmdir(state_parts[-1], dir_fd=state_parent)
    except OSError as error:
        if error.errno not in {errno.ENOTEMPTY, errno.EEXIST}:
            raise
    os.fsync(state_parent)
finally:
    os.close(state_parent)
    os.close(home_descriptor)
PY

if [[ $remove_preferences == 1 ]]; then
  python3 - "$target_home" <<'PY' || fail "could not remove preferences"
import errno
import os
from pathlib import Path
import stat
import sys

home = Path(sys.argv[1])
relative = Path(".local/share/omarchy-keyguide/settings.json")
cursor = home
for component in relative.parts[:-1]:
    cursor /= component
    if cursor.is_symlink():
        raise SystemExit(f"refusing symlinked preferences path: {cursor}")
path = home / relative
try:
    info = path.lstat()
except FileNotFoundError:
    info = None
if info is not None:
    if not stat.S_ISREG(info.st_mode):
        raise SystemExit(f"refusing non-regular preferences file: {path}")
    path.unlink()
try:
    path.parent.rmdir()
except OSError as error:
    if error.errno not in {errno.ENOENT, errno.ENOTEMPTY, errno.EEXIST}:
        raise
PY
fi

echo "Uninstalled Omarchy Keyguide from $target_home"
