#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "install: $*" >&2
  exit 1
}

project_root=$(realpath -m -- "$(dirname -- "${BASH_SOURCE[0]}")/..")
cd "$project_root"
source "$project_root/scripts/live-session-safety.sh"

[[ ${HOME:-} == /* && $HOME != / ]] || fail "HOME must be an absolute user directory"

prefix_root=${PREFIX_ROOT:-}
preserve_user_shell=${PRESERVE_USER_SHELL:-0}
[[ $preserve_user_shell == 0 || $preserve_user_shell == 1 ]] ||
  fail "PRESERVE_USER_SHELL must be 0 or 1"
if [[ -n $prefix_root ]]; then
  [[ $prefix_root == /* && $prefix_root != / ]] ||
    fail "PREFIX_ROOT must be an absolute directory other than /"
  prefix_root=$(realpath -m -- "$prefix_root")
  target_home=$(realpath -m -- "${prefix_root}${HOME}")
  [[ $target_home == "$prefix_root"/* ]] || fail "target home escapes PREFIX_ROOT"
else
  target_home=$(realpath -m -- "$HOME")
fi

if [[ -z $prefix_root ]]; then
  compat_program=${KEYGUIDE_COMPAT_PROGRAM:-python3}
  PYTHONPATH="$project_root/src/backend" "$compat_program" -m keyguide_backend compat >/dev/null ||
    fail "system compatibility check failed"
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
shell_backup="$state_dir/shell.json.pre-keyguide"
omarchy_path=${OMARCHY_PATH:-/usr/share/omarchy}
[[ $omarchy_path == /* && $omarchy_path != / ]] ||
  fail "OMARCHY_PATH must be an absolute directory"
default_shell_config="$omarchy_path/config/omarchy/shell.json"

shell_bar_placement_status() {
  python3 - "$shell_config" <<'PY'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
if not path.exists():
    print("absent")
    raise SystemExit(0)

def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate shell key: {key}")
        result[key] = value
    return result

try:
    with path.open(encoding="utf-8") as stream:
        document = json.load(stream, object_pairs_hook=unique_object)
except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
    raise SystemExit(f"invalid shell config: {error}") from error
if not isinstance(document, dict):
    raise SystemExit("invalid shell config: document must be an object")
bar = document.get("bar", {})
if not isinstance(bar, dict):
    raise SystemExit("invalid shell config: bar must be an object")
layout = bar.get("layout", {})
if not isinstance(layout, dict):
    raise SystemExit("invalid shell config: bar layout must be an object")
locations = []
for section in ("left", "center", "right"):
    entries = layout.get(section, [])
    if not isinstance(entries, list):
        raise SystemExit(f"invalid shell config: bar {section} must be an array")
    for index, entry in enumerate(entries):
        entry_id = entry.get("id") if isinstance(entry, dict) else entry
        if entry_id == "mrai.keyguide":
            locations.append((section, index, entries))
if not locations:
    print("absent")
elif len(locations) != 1:
    print("duplicate")
else:
    section, index, entries = locations[0]
    predecessor = entries[index - 1] if index > 0 else None
    predecessor_id = (
        predecessor.get("id") if isinstance(predecessor, dict) else predecessor
    )
    print("anchored" if predecessor_id == "omarchy.agents" else "misplaced")
PY
}

validate_bar_placement_postimage() {
  local candidate_shell=${1:-$shell_config}
  python3 - \
    "$candidate_shell" \
    "$shell_backup" \
    "$shell_preexisting" \
    "$shell_pre_sha256" \
    "$shell_pre_mode" <<'PY'
import copy
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

shell_arg, backup_arg, preexisting_arg, pre_sha256, pre_mode = sys.argv[1:]
shell = Path(shell_arg)
backup = Path(backup_arg)
preexisting = preexisting_arg == "true"


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate shell key: {key}")
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


def read_regular(path):
    descriptor = os.open(
        path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW
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
        return b"".join(chunks), info
    finally:
        os.close(descriptor)


try:
    live_bytes, live_info = read_regular(shell)
    live_document = json.loads(
        live_bytes.decode("utf-8"), object_pairs_hook=unique_object
    )
except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
    raise SystemExit(f"invalid bar placement postimage: {error}") from error
if not isinstance(live_document, dict):
    raise SystemExit("invalid bar placement postimage: document must be an object")

candidate = copy.deepcopy(live_document)
bar = candidate.get("bar")
layout = bar.get("layout") if isinstance(bar, dict) else None
if not isinstance(layout, dict):
    raise SystemExit("invalid bar placement postimage: missing bar layout")
locations = []
for section in ("left", "center", "right"):
    entries = layout.get(section)
    if not isinstance(entries, list):
        raise SystemExit(
            f"invalid bar placement postimage: {section} must be an array"
        )
    for index, entry in enumerate(entries):
        entry_id = entry.get("id") if isinstance(entry, dict) else entry
        if entry_id == "mrai.keyguide":
            locations.append((index, entries, entry))
if len(locations) != 1:
    raise SystemExit(
        "invalid bar placement postimage: insertion must be unique"
    )
index, entries, entry = locations[0]
predecessor = entries[index - 1] if index > 0 else None
predecessor_id = (
    predecessor.get("id") if isinstance(predecessor, dict) else predecessor
)
if entry != {"id": "mrai.keyguide"} or predecessor_id != "omarchy.agents":
    raise SystemExit(
        "invalid bar placement postimage: insertion is not canonical and anchored"
    )
del entries[index]

if preexisting:
    if stat.S_IMODE(live_info.st_mode) != int(pre_mode, 8):
        raise SystemExit("invalid bar placement postimage: shell mode changed")
    try:
        backup_bytes, _ = read_regular(backup)
        if hashlib.sha256(backup_bytes).hexdigest() != pre_sha256:
            raise ValueError("backup hash does not match authenticated preimage")
        backup_document = json.loads(
            backup_bytes.decode("utf-8"), object_pairs_hook=unique_object
        )
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        raise SystemExit(
            f"invalid bar placement postimage: {error}"
        ) from error
    if not isinstance(backup_document, dict) or not json_equal(
        candidate, backup_document
    ):
        raise SystemExit(
            "invalid bar placement postimage: insertion changed unrelated state"
        )

print(hashlib.sha256(live_bytes).hexdigest())
PY
}

capture_regular_endpoint_identity() {
  python3 - "$1" <<'PY'
import hashlib
import os
from pathlib import Path
import stat
import sys

path = Path(sys.argv[1])
descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK)
try:
    info = os.fstat(descriptor)
    if not stat.S_ISREG(info.st_mode):
        raise RuntimeError(f"endpoint is not regular: {path}")
    digest = hashlib.sha256()
    while True:
        chunk = os.read(descriptor, 65536)
        if not chunk:
            break
        digest.update(chunk)
    print(
        "\t".join(
            str(value)
            for value in (
                info.st_dev,
                info.st_ino,
                info.st_mode,
                info.st_size,
                info.st_mtime_ns,
                info.st_uid,
                info.st_gid,
                digest.hexdigest(),
            )
        )
    )
finally:
    os.close(descriptor)
PY
}

capture_shell_endpoint_for_bar_put() {
  python3 - "$shell_config" "$state_dir" <<'PY'
import os
from pathlib import Path
import stat
import sys
import tempfile

shell = Path(sys.argv[1])
state_dir = Path(sys.argv[2])
def read_all(descriptor):
    chunks = []
    while True:
        chunk = os.read(descriptor, 65536)
        if not chunk:
            break
        chunks.append(chunk)
    return b"".join(chunks)

try:
    descriptor = os.open(shell, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
except FileNotFoundError:
    print("-")
    raise SystemExit(0)
try:
    info = os.fstat(descriptor)
    if not stat.S_ISREG(info.st_mode):
        raise RuntimeError("shell config is not a regular file")
    original_bytes = read_all(descriptor)
    temporary_descriptor, temporary_path = tempfile.mkstemp(
        prefix=".shell-before-bar-put.", suffix=".tmp", dir=state_dir
    )
    try:
        os.fchmod(temporary_descriptor, stat.S_IMODE(info.st_mode))
        if os.geteuid() == 0:
            os.fchown(temporary_descriptor, info.st_uid, info.st_gid)
        remaining = memoryview(original_bytes)
        while remaining:
            written = os.write(temporary_descriptor, remaining)
            if written <= 0:
                raise OSError("short write while capturing shell")
            remaining = remaining[written:]
        os.fsync(temporary_descriptor)
    finally:
        os.close(temporary_descriptor)
    if os.environ.get("KEYGUIDE_TEST_HOOK_SHELL_CAPTURE_OWNER_LOSS"):
        marker = Path(os.environ["KEYGUIDE_TEST_HOOK_SHELL_CAPTURE_OWNER_LOSS"])
        if not marker.exists():
            marker.touch()
            raise RuntimeError("shell capture owner/group cannot be reproduced")
    capture_descriptor = os.open(
        temporary_path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW
    )
    try:
        capture_info = os.fstat(capture_descriptor)
        capture_bytes = read_all(capture_descriptor)
    finally:
        os.close(capture_descriptor)
    if (
        not stat.S_ISREG(capture_info.st_mode)
        or capture_bytes != original_bytes
        or stat.S_IMODE(capture_info.st_mode) != stat.S_IMODE(info.st_mode)
        or capture_info.st_uid != info.st_uid
        or capture_info.st_gid != info.st_gid
    ):
        try:
            os.unlink(temporary_path)
        except FileNotFoundError:
            pass
        raise RuntimeError("shell capture does not preserve source bytes/mode/owner")
    print(temporary_path)
finally:
    os.close(descriptor)
PY
}

restore_shell_capture_after_failed_bar_put() {
  local capture_path=$1
  python3 - "$shell_config" "$capture_path" <<'PY'
import json
import os
import ctypes
from pathlib import Path
import stat
import sys
import tempfile

shell = Path(sys.argv[1])
capture_arg = sys.argv[2]
capture = Path(capture_arg)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate shell key: {key}")
        result[key] = value
    return result


def read_regular(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError(f"not a regular file: {path}")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks), info
    finally:
        os.close(descriptor)


def read_optional_regular(path):
    try:
        return read_regular(path)
    except FileNotFoundError:
        return None


def snapshot_from(bytes_value, info):
    return (
        bytes_value,
        (
            info.st_dev,
            info.st_ino,
            stat.S_IMODE(info.st_mode),
            info.st_size,
            info.st_mtime_ns,
            info.st_uid,
            info.st_gid,
        ),
    )


def same_snapshot(left, right):
    return left[0] == right[0] and left[1] == right[1]


def entry_id(entry):
    return entry.get("id") if isinstance(entry, dict) else entry


def has_keyguide_bar_entry(document):
    bar = document.get("bar")
    layout = bar.get("layout") if isinstance(bar, dict) else None
    if not isinstance(layout, dict):
        raise RuntimeError("failed bar placement rollback lacks a bar layout")
    found = False
    for section in ("left", "center", "right"):
        entries = layout.get(section)
        if not isinstance(entries, list):
            raise RuntimeError(
                f"failed bar placement rollback has invalid {section} bar entries"
            )
        for entry in entries:
            if entry_id(entry) == "mrai.keyguide":
                found = True
    return found


def exchange(directory_descriptor, left, right):
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


def rename_no_replace(directory_descriptor, left, right):
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
        1,
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


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


def remove_command_created_shell(observed_snapshot):
    directory_descriptor = os.open(
        shell.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    )
    temporary_descriptor, temporary_path = tempfile.mkstemp(
        prefix=f".{shell.name}.bar-rollback-remove-",
        suffix=".tmp",
        dir=shell.parent,
    )
    temporary = Path(temporary_path)
    preserve_temporary = False
    try:
        os.close(temporary_descriptor)
        temporary_descriptor = -1
        temporary.unlink()
        # keyguide-atomic-bar-rollback-remove-observation-checked
        current = read_optional_regular(shell)
        if current is None or not same_snapshot(snapshot_from(*current), observed_snapshot):
            raise RuntimeError("shell changed during bar rollback removal")
        rename_no_replace(directory_descriptor, shell.name, temporary.name)
        preserve_temporary = True
        displaced = read_optional_regular(temporary)
        if displaced is None or not same_snapshot(
            snapshot_from(*displaced), observed_snapshot
        ):
            try:
                rename_no_replace(directory_descriptor, temporary.name, shell.name)
                preserve_temporary = False
                os.fsync(directory_descriptor)
            except OSError:
                pass
            raise RuntimeError(
                f"shell changed during bar rollback removal; displaced endpoint "
                f"is preserved at {temporary}"
            )
        os.unlink(temporary.name, dir_fd=directory_descriptor)
        preserve_temporary = False
        os.fsync(directory_descriptor)
    finally:
        if temporary_descriptor >= 0:
            os.close(temporary_descriptor)
        if not preserve_temporary:
            temporary.unlink(missing_ok=True)
        os.close(directory_descriptor)


def restore_captured_shell_to_absent(captured_bytes, captured_info):
    directory_descriptor = os.open(
        shell.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    )
    temporary_descriptor, temporary_path = tempfile.mkstemp(
        prefix=f".{shell.name}.bar-rollback-restore-",
        suffix=".tmp",
        dir=shell.parent,
    )
    temporary = Path(temporary_path)
    try:
        os.fchmod(temporary_descriptor, stat.S_IMODE(captured_info.st_mode))
        if os.geteuid() == 0:
            os.fchown(temporary_descriptor, captured_info.st_uid, captured_info.st_gid)
        elif (
            os.fstat(temporary_descriptor).st_uid != captured_info.st_uid
            or os.fstat(temporary_descriptor).st_gid != captured_info.st_gid
        ):
            raise RuntimeError("cannot preserve shell owner during bar rollback")
        remaining = memoryview(captured_bytes)
        while remaining:
            written = os.write(temporary_descriptor, remaining)
            if written <= 0:
                raise OSError("short write while restoring captured shell")
            remaining = remaining[written:]
        os.fsync(temporary_descriptor)
    finally:
        os.close(temporary_descriptor)
    try:
        staged_snapshot = snapshot_from(*read_regular(temporary))
        if (
            staged_snapshot[0] != captured_bytes
            or stat.S_IMODE(staged_snapshot[1][2]) != stat.S_IMODE(captured_info.st_mode)
            or staged_snapshot[1][5] != captured_info.st_uid
            or staged_snapshot[1][6] != captured_info.st_gid
        ):
            raise RuntimeError("staged shell restore does not match captured endpoint")
        # keyguide-atomic-bar-rollback-restore-absence-checked
        if read_optional_regular(shell) is not None:
            raise RuntimeError("shell appeared during bar rollback restore")
        try:
            rename_no_replace(directory_descriptor, temporary.name, shell.name)
        except OSError as error:
            raise RuntimeError("shell appeared during bar rollback restore") from error
        final = read_optional_regular(shell)
        if final is None or not same_snapshot(snapshot_from(*final), staged_snapshot):
            raise RuntimeError("restored shell changed during bar rollback")
        os.fsync(directory_descriptor)
    finally:
        temporary.unlink(missing_ok=True)
        os.close(directory_descriptor)


if capture_arg == "-":
    live = read_optional_regular(shell)
    if live is None:
        raise SystemExit(0)
    observed_snapshot = snapshot_from(*live)
    remove_command_created_shell(observed_snapshot)
    raise SystemExit(0)

captured_bytes, captured_info = read_regular(capture)
live = read_optional_regular(shell)
if live is None:
    restore_captured_shell_to_absent(captured_bytes, captured_info)
    raise SystemExit(0)
live_bytes, live_info = live
observed_snapshot = snapshot_from(live_bytes, live_info)
if (
    stat.S_IMODE(live_info.st_mode) != stat.S_IMODE(captured_info.st_mode)
    or live_info.st_uid != captured_info.st_uid
    or live_info.st_gid != captured_info.st_gid
):
    raise RuntimeError("failed bar placement changed shell metadata")
captured_document = json.loads(
    captured_bytes.decode("utf-8"), object_pairs_hook=unique_object
)
live_document = json.loads(live_bytes.decode("utf-8"), object_pairs_hook=unique_object)
bar = live_document.get("bar")
layout = bar.get("layout") if isinstance(bar, dict) else None
if not isinstance(layout, dict):
    raise RuntimeError("failed bar placement rollback lacks a bar layout")
removed = 0
for section in ("left", "center", "right"):
    entries = layout.get(section)
    if not isinstance(entries, list):
        continue
    retained = [entry for entry in entries if entry_id(entry) != "mrai.keyguide"]
    removed += len(entries) - len(retained)
    layout[section] = retained
if removed == 0:
    raise RuntimeError("failed bar placement rollback could not identify insertion")
if not json_equal(live_document, captured_document):
    raise RuntimeError("failed bar placement changed unrelated shell state")

temporary_descriptor, temporary_path = tempfile.mkstemp(
    prefix=f".{shell.name}.bar-rollback-", suffix=".tmp", dir=shell.parent
)
temporary = Path(temporary_path)
try:
    os.fchmod(temporary_descriptor, stat.S_IMODE(captured_info.st_mode))
    if os.geteuid() == 0:
        os.fchown(temporary_descriptor, captured_info.st_uid, captured_info.st_gid)
    elif (
        os.fstat(temporary_descriptor).st_uid != captured_info.st_uid
        or os.fstat(temporary_descriptor).st_gid != captured_info.st_gid
    ):
        raise RuntimeError("cannot preserve shell owner during bar rollback")
    remaining = memoryview(captured_bytes)
    while remaining:
        written = os.write(temporary_descriptor, remaining)
        if written <= 0:
            raise OSError("short write while rolling back shell")
        remaining = remaining[written:]
    os.fsync(temporary_descriptor)
finally:
    os.close(temporary_descriptor)
directory_descriptor = os.open(
    shell.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
)
preserve_temporary = False
try:
    # keyguide-atomic-bar-rollback-observation-checked
    current_bytes, current_info = read_regular(shell)
    if not same_snapshot(snapshot_from(current_bytes, current_info), observed_snapshot):
        temporary.unlink(missing_ok=True)
        raise RuntimeError("shell changed during bar rollback")
    staged_snapshot = snapshot_from(*read_regular(temporary))
    exchange(directory_descriptor, temporary.name, shell.name)
    preserve_temporary = True
    displaced_snapshot = snapshot_from(*read_regular(temporary))
    if not same_snapshot(displaced_snapshot, observed_snapshot):
        # keyguide-atomic-bar-rollback-mismatch-before-abort
        raise RuntimeError("shell changed during bar rollback")
    final_bytes, final_info = read_regular(shell)
    if (
        final_bytes != captured_bytes
        or stat.S_IMODE(final_info.st_mode) != stat.S_IMODE(captured_info.st_mode)
        or final_info.st_uid != captured_info.st_uid
        or final_info.st_gid != captured_info.st_gid
    ):
        raise RuntimeError(
            f"bar rollback final endpoint does not match captured shell; displaced endpoint is preserved at {temporary}"
        )
    hook = os.environ.get("KEYGUIDE_TEST_HOOK_SHELL_ROLLBACK_FINAL_CHANGE")
    if hook:
        marker = Path(hook)
        if not marker.exists():
            shell.write_bytes(captured_bytes + b"\n")
            marker.touch()
    final_bytes, final_info = read_regular(shell)
    if (
        final_bytes != captured_bytes
        or stat.S_IMODE(final_info.st_mode) != stat.S_IMODE(captured_info.st_mode)
        or final_info.st_uid != captured_info.st_uid
        or final_info.st_gid != captured_info.st_gid
    ):
        raise RuntimeError(
            f"bar rollback final endpoint does not match captured shell; displaced endpoint is preserved at {temporary}"
        )
    os.fsync(directory_descriptor)
finally:
    os.close(directory_descriptor)
if not preserve_temporary:
    temporary.unlink(missing_ok=True)
else:
    temporary.unlink()
PY
}

prepare_absent_bar_staging_home() {
  local staging_home=$1
  local staged_shell=$2
  python3 - "$target_home" "$state_dir" "$staging_home" "$staged_shell" <<'PY'
import os
from pathlib import Path
import sys

target_home = Path(sys.argv[1])
state_dir = Path(sys.argv[2])
staging_home = Path(sys.argv[3])
staged_shell = Path(sys.argv[4])

try:
    staging_home.relative_to(state_dir)
    staged_relative = staged_shell.relative_to(staging_home)
    state_dir.relative_to(target_home)
except ValueError as error:
    raise RuntimeError("bar staging path escapes installer state") from error
if staged_relative.parts != (".config", "omarchy", "shell.json"):
    raise RuntimeError("bar staging shell path is not the expected endpoint")


def ensure_directory(parent_descriptor, component):
    if component in {"", ".", ".."}:
        raise RuntimeError("bar staging path has an unsafe component")
    try:
        return os.open(
            component,
            os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
            dir_fd=parent_descriptor,
        )
    except FileNotFoundError:
        os.mkdir(component, 0o700, dir_fd=parent_descriptor)
        os.fsync(parent_descriptor)
        return os.open(
            component,
            os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
            dir_fd=parent_descriptor,
        )

state_descriptor = os.open(
    state_dir, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
)
opened = []
try:
    relative = staging_home.relative_to(state_dir)
    cursor = state_descriptor
    for component in relative.parts:
        next_descriptor = ensure_directory(cursor, component)
        opened.append(next_descriptor)
        cursor = next_descriptor
    staging_descriptor = cursor
    config_descriptor = ensure_directory(staging_descriptor, ".config")
    opened.append(config_descriptor)
    omarchy_descriptor = ensure_directory(config_descriptor, "omarchy")
    opened.append(omarchy_descriptor)
    local_descriptor = ensure_directory(staging_descriptor, ".local")
    opened.append(local_descriptor)
    share_descriptor = ensure_directory(local_descriptor, "share")
    opened.append(share_descriptor)
    try:
        os.stat(
            staged_relative.name,
            dir_fd=omarchy_descriptor,
            follow_symlinks=False,
        )
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError(f"bar staging shell already exists: {staged_shell}")
    for descriptor in (
        omarchy_descriptor,
        config_descriptor,
        share_descriptor,
        local_descriptor,
        staging_descriptor,
        state_descriptor,
    ):
        os.fsync(descriptor)
finally:
    for descriptor in opened:
        try:
            os.close(descriptor)
        except OSError:
            pass
    os.close(state_descriptor)
PY
}

stage_absent_bar_from_default() {
  local staged_shell=$1
  python3 - "$default_shell_config" "$staged_shell" "$state_dir" <<'PY'
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

default_shell = Path(sys.argv[1])
staged_shell = Path(sys.argv[2])
state_dir = Path(sys.argv[3])

try:
    staged_shell.relative_to(state_dir)
except ValueError as error:
    raise RuntimeError("bar staging shell escapes installer state") from error


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate shell key: {key}")
        result[key] = value
    return result


def invalid_constant(value):
    raise ValueError(f"non-standard JSON constant: {value}")


def read_default(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError("default shell is not a regular file")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks)
    finally:
        os.close(descriptor)


try:
    default_bytes = read_default(default_shell)
    document = json.loads(
        default_bytes.decode("utf-8"),
        object_pairs_hook=unique_object,
        parse_constant=invalid_constant,
    )
except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
    raise RuntimeError(f"invalid default shell: {error}") from error

if not isinstance(document, dict):
    raise RuntimeError("invalid default shell: document must be an object")
if type(document.get("version")) is not int or document["version"] != 1:
    raise RuntimeError("invalid default shell: version must be integer 1")


def plugin_list_contains_keyguide(value):
    if not isinstance(value, list):
        raise RuntimeError("invalid default shell: plugin list must be an array")
    for index, entry in enumerate(value):
        if entry == "mrai.keyguide":
            return True
        if isinstance(entry, dict) and entry.get("id") == "mrai.keyguide":
            return True
        if not isinstance(entry, (str, dict)):
            raise RuntimeError(
                f"invalid default shell: plugin list entry {index} is invalid"
            )
    return False


if plugin_list_contains_keyguide(document.get("plugins")):
    raise RuntimeError("invalid default shell: mrai.keyguide is already present")
disabled_plugins = document.get("disabledPlugins")
if disabled_plugins is not None and plugin_list_contains_keyguide(disabled_plugins):
    raise RuntimeError("invalid default shell: mrai.keyguide is already present")

bar = document.get("bar")
if not isinstance(bar, dict):
    raise RuntimeError("invalid default shell: bar must be an object")
def contains_keyguide_widget_id(value):
    if isinstance(value, dict):
        if value.get("id") == "mrai.keyguide":
            return True
        return any(contains_keyguide_widget_id(child) for child in value.values())
    if isinstance(value, list):
        return any(contains_keyguide_widget_id(child) for child in value)
    return False


if contains_keyguide_widget_id(bar):
    raise RuntimeError("invalid default shell: mrai.keyguide is already present")
layout = bar.get("layout")
if not isinstance(layout, dict):
    raise RuntimeError("invalid default shell: bar.layout must be an object")

agents_locations = []
for section in ("left", "center", "right"):
    entries = layout.get(section)
    if not isinstance(entries, list):
        raise RuntimeError(
            f"invalid default shell: bar.layout.{section} must be an array"
        )
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise RuntimeError(
                f"invalid default shell: {section}[{index}] must be an object"
            )
        entry_id = entry.get("id")
        if not isinstance(entry_id, str):
            raise RuntimeError(
                f"invalid default shell: {section}[{index}].id must be a string"
            )
        if entry_id == "omarchy.agents":
            agents_locations.append((entries, index))

if len(agents_locations) != 1:
    raise RuntimeError(
        "invalid default shell: exactly one omarchy.agents entry is required"
    )

entries, index = agents_locations[0]
entries.insert(index + 1, {"id": "mrai.keyguide"})
payload = (
    json.dumps(
        document,
        indent=2,
        ensure_ascii=False,
        sort_keys=True,
    )
    + "\n"
).encode("utf-8")
payload_sha256 = hashlib.sha256(payload).hexdigest()

parent_descriptor = os.open(
    staged_shell.parent,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)
descriptor = -1
try:
    descriptor = os.open(
        staged_shell.name,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_CLOEXEC | os.O_NOFOLLOW,
        0o644,
        dir_fd=parent_descriptor,
    )
    remaining = memoryview(payload)
    while remaining:
        written = os.write(descriptor, remaining)
        if written <= 0:
            raise OSError("short write while staging default shell")
        remaining = remaining[written:]
    os.fchmod(descriptor, 0o644)
    os.fsync(descriptor)
    info = os.fstat(descriptor)
    os.fsync(parent_descriptor)
finally:
    if descriptor >= 0:
        os.close(descriptor)
    os.close(parent_descriptor)

print(f"{payload_sha256}\t{stat.S_IMODE(info.st_mode):o}")
PY
}

capture_staged_bar_output() {
  local staged_shell=$1
  python3 - "$staged_shell" "$state_dir" <<'PY'
import hashlib
import os
from pathlib import Path
import stat
import sys

staged_shell = Path(sys.argv[1])
state_dir = Path(sys.argv[2])
try:
    staged_shell.relative_to(state_dir)
except ValueError as error:
    raise RuntimeError("bar staging shell escapes installer state") from error

descriptor = os.open(staged_shell, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
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
    os.fsync(descriptor)
finally:
    os.close(descriptor)

for directory in (staged_shell.parent, state_dir):
    directory_descriptor = os.open(
        directory, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    )
    try:
        os.fsync(directory_descriptor)
    finally:
        os.close(directory_descriptor)

print(f"{digest.hexdigest()}\t{stat.S_IMODE(info.st_mode):o}")
PY
}

publish_staged_absent_bar_shell() {
  local staged_shell=$1
  local expected_sha256=$2
  local expected_mode=$3
  python3 - "$staged_shell" "$shell_config" "$target_home" "$state_dir" "$expected_sha256" "$expected_mode" <<'PY'
import hashlib
import os
from pathlib import Path
import stat
import sys

staged_shell = Path(sys.argv[1])
live_shell = Path(sys.argv[2])
target_home = Path(sys.argv[3])
state_dir = Path(sys.argv[4])
expected_sha256 = sys.argv[5]
expected_mode = int(sys.argv[6], 8)

try:
    staged_shell.relative_to(state_dir)
    live_shell.relative_to(target_home)
except ValueError as error:
    raise RuntimeError("staged bar publication path escapes trusted roots") from error


def read_regular(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError(f"not a regular file: {path}")
        chunks = []
        digest = hashlib.sha256()
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
            digest.update(chunk)
        return b"".join(chunks), info, digest.hexdigest()
    finally:
        os.close(descriptor)


def open_live_parent():
    relative_parent = live_shell.parent.relative_to(target_home)
    descriptor = os.open(
        target_home, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    )
    for component in relative_parent.parts:
        if component in {"", ".", ".."}:
            os.close(descriptor)
            raise RuntimeError("live shell parent has an unsafe component")
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
        os.close(descriptor)
        descriptor = next_descriptor
    return descriptor


staged_bytes, staged_info, staged_sha256 = read_regular(staged_shell)
if staged_sha256 != expected_sha256:
    raise RuntimeError("staged bar output changed before publication")
if stat.S_IMODE(staged_info.st_mode) != expected_mode:
    raise RuntimeError("staged bar output mode changed before publication")

parent_descriptor = open_live_parent()
try:
    try:
        os.stat(live_shell.name, dir_fd=parent_descriptor, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError("live shell appeared before staged bar publication")

    # keyguide-atomic-staged-bar-publication-observation-checked
    try:
        os.link(
            staged_shell,
            live_shell.name,
            dst_dir_fd=parent_descriptor,
            follow_symlinks=False,
        )
    except FileExistsError as error:
        raise RuntimeError("live shell appeared before staged bar publication") from error
    os.fsync(parent_descriptor)
    # keyguide-staged-bar-publication-durable

    live_bytes, live_info, live_sha256 = read_regular(live_shell)
    if (
        live_sha256 != expected_sha256
        or live_bytes != staged_bytes
        or (live_info.st_dev, live_info.st_ino)
        != (staged_info.st_dev, staged_info.st_ino)
        or stat.S_IMODE(live_info.st_mode) != expected_mode
    ):
        raise RuntimeError("published staged bar output changed before verification")
finally:
    os.close(parent_descriptor)

print(expected_sha256)
PY
}

staged_absent_bar_shell_is_published() {
  local staged_shell=$1
  local expected_sha256=$2
  local expected_mode=$3
  python3 - "$staged_shell" "$shell_config" "$state_dir" "$expected_sha256" "$expected_mode" <<'PY'
import hashlib
import os
from pathlib import Path
import stat
import sys

staged_shell = Path(sys.argv[1])
live_shell = Path(sys.argv[2])
state_dir = Path(sys.argv[3])
expected_sha256 = sys.argv[4]
expected_mode = int(sys.argv[5], 8)

try:
    staged_shell.relative_to(state_dir)
except ValueError as error:
    raise RuntimeError("bar staging shell escapes installer state") from error


def snapshot(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            return None
        digest = hashlib.sha256()
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            digest.update(chunk)
        return (
            digest.hexdigest(),
            info.st_dev,
            info.st_ino,
            stat.S_IMODE(info.st_mode),
        )
    finally:
        os.close(descriptor)


try:
    staged = snapshot(staged_shell)
    live = snapshot(live_shell)
except FileNotFoundError:
    raise SystemExit(1)
if (
    staged is not None
    and live is not None
    and staged == live
    and staged[0] == expected_sha256
    and staged[3] == expected_mode
):
    raise SystemExit(0)
raise SystemExit(1)
PY
}

clear_staged_bar_output() {
  local staged_shell=${1:-}
  local expected_sha256=${2:-}
  local expected_mode=${3:-}
  [[ -n $staged_shell ]] || return 0
  python3 - "$staged_shell" "$state_dir" "$expected_sha256" "$expected_mode" <<'PY'
import hashlib
import os
from pathlib import Path
import stat
import sys

staged_shell = Path(sys.argv[1])
state_dir = Path(sys.argv[2])
expected_sha256 = sys.argv[3]
expected_mode = sys.argv[4]

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
        if expected_sha256 and digest.hexdigest() != expected_sha256:
            raise RuntimeError("bar staging shell changed before cleanup")
        if expected_mode and stat.S_IMODE(info.st_mode) != int(expected_mode, 8):
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

source_files=(
  "build/keyguide-observer"
  "src/backend/keyguide_backend/__init__.py"
  "src/backend/keyguide_backend/__main__.py"
  "src/backend/keyguide_backend/bindings.py"
  "src/backend/keyguide_backend/catalog.py"
  "src/backend/keyguide_backend/compat.py"
  "src/backend/keyguide_backend/groups.py"
  "src/backend/keyguide_backend/layout.py"
  "src/backend/keyguide_backend/presentation.py"
  "src/backend/keyguide_backend/settings.py"
  "src/backend/keyguide_backend/shortcuts.py"
  "src/plugin/manifest.json"
  "src/plugin/ActionSearchModel.js"
  "src/plugin/BarWidget.qml"
  "src/plugin/Hud.qml"
  "src/plugin/HudModel.js"
  "src/plugin/I18n.js"
  "src/plugin/Service.qml"
  "src/plugin/Settings.qml"
  "src/plugin/VisibilityModel.js"
  "src/plugin/components/BindingRow.qml"
  "src/plugin/components/ActionSearch.qml"
  "src/plugin/components/ExecutablePicker.qml"
  "src/plugin/components/HudPreview.qml"
  "src/plugin/components/ShortcutEditRow.qml"
  "assets/omarchy-keyguide.svg"
  "packaging/omarchy-keyguide-settings.desktop"
)

resolved_manifest=$(realpath -m -- "$manifest_path")
[[ $resolved_manifest == "$target_home"/* ]] ||
  fail "manifest path escapes target home: $manifest_path"

for source_path in "${source_files[@]}"; do
  [[ -f $source_path ]] || fail "missing build input: $source_path"
done

upgrade_plugin_was_enabled=
upgrade_manifest_sha256=
upgrade_install_state=
upgrade_handoff_token=
upgrade_ready_shell_preexisting=false
upgrade_ready_shell_backup=
upgrade_ready_shell_pre_sha256=
upgrade_ready_shell_pre_mode=
upgrade_ready_shell_pre_uid=
upgrade_ready_shell_pre_gid=
upgrade_ready_shell_restore_state=
upgrade_owned_files=()
upgrade_reservation_paths=()
upgrade_reservation_tokens=()
upgrade_reservation_temporary_paths=()
upgrade_recovered_restart_pending=false
upgrade_shell_restarted=false

inspect_upgrade_manifest() {
  local upgrade_manifest_info
  local -a upgrade_manifest_values
  upgrade_manifest_info=$(python3 - "$manifest_path" <<'PY'
import hashlib
import json
import os
import re
import stat
import sys

path = sys.argv[1]


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate manifest key: {key}")
        result[key] = value
    return result


def invalid_constant(value):
    raise ValueError(f"non-standard JSON constant: {value}")


descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
try:
    if not stat.S_ISREG(os.fstat(descriptor).st_mode):
        raise SystemExit("install manifest is not a regular file")
    chunks = []
    while True:
        chunk = os.read(descriptor, 1024 * 1024)
        if not chunk:
            break
        chunks.append(chunk)
finally:
    os.close(descriptor)
manifest_bytes = b"".join(chunks)
print(hashlib.sha256(manifest_bytes).hexdigest())
document = json.loads(
    manifest_bytes.decode("utf-8"),
    object_pairs_hook=unique_object,
    parse_constant=invalid_constant,
)
if not isinstance(document, dict):
    raise SystemExit("install manifest must contain an object")
value = document.get("plugin_was_enabled")
if type(value) is not bool:
    raise SystemExit("install manifest has invalid prior plugin state")
print("true" if value else "false")
install_state = document.get("install_state")
if not isinstance(install_state, str):
    raise SystemExit("install manifest has invalid install state")
print(install_state)
handoff = document.get("upgrade_handoff")
reservations = []
if handoff is not None:
    if not isinstance(handoff, dict) or set(handoff) != {
        "schema_version", "token", "reservations"
    }:
        raise SystemExit("install manifest has malformed upgrade handoff")
    if (
        type(handoff["schema_version"]) is not int
        or handoff["schema_version"] != 1
        or not re.fullmatch(r"[0-9a-f]{64}", handoff["token"])
        or not isinstance(handoff["reservations"], list)
    ):
        raise SystemExit("install manifest has malformed upgrade handoff")
    reservations = handoff["reservations"]
    print(handoff["token"])
else:
    print("-")
shell = document.get("shell_config")
if not isinstance(shell, dict):
    raise SystemExit("install manifest has invalid shell state")
print("true" if shell.get("preexisting") is True else "false")
print(shell.get("backup_path") or "-")
print(shell.get("pre_sha256") or "-")
print(shell.get("pre_mode") or "-")
pre_uid = shell.get("pre_uid")
pre_gid = shell.get("pre_gid")
print(str(pre_uid) if isinstance(pre_uid, int) and pre_uid >= 0 else "-")
print(str(pre_gid) if isinstance(pre_gid, int) and pre_gid >= 0 else "-")
print(shell.get("restore_state", "not_started"))
print(len(reservations))
for reservation in reservations:
    if not isinstance(reservation, dict) or set(reservation) != {
        "path", "token", "temporary_path"
    }:
        raise SystemExit("install manifest has malformed upgrade reservation")
    values = (
        reservation["path"],
        reservation["token"],
        reservation["temporary_path"],
    )
    if (
        any(not isinstance(item, str) or "\n" in item or "\t" in item for item in values)
        or not re.fullmatch(r"[0-9a-f]{64}", reservation["token"])
    ):
        raise SystemExit("install manifest has malformed upgrade reservation")
    print("\t".join(values))
owned_files = document.get("owned_files")
if not isinstance(owned_files, list) or not all(
    isinstance(item, str) and "\n" not in item for item in owned_files
):
    raise SystemExit("install manifest has invalid owned files")
for item in owned_files:
    print(item)
PY
  ) || fail "could not inspect prior upgrade state"
  mapfile -t upgrade_manifest_values <<<"$upgrade_manifest_info"
  upgrade_manifest_sha256=${upgrade_manifest_values[0]}
  upgrade_plugin_was_enabled=${upgrade_manifest_values[1]}
  upgrade_install_state=${upgrade_manifest_values[2]}
  upgrade_handoff_token=${upgrade_manifest_values[3]}
  [[ $upgrade_handoff_token != - ]] || upgrade_handoff_token=
  upgrade_ready_shell_preexisting=${upgrade_manifest_values[4]}
  upgrade_ready_shell_backup=${upgrade_manifest_values[5]}
  [[ $upgrade_ready_shell_backup != - ]] || upgrade_ready_shell_backup=
  upgrade_ready_shell_pre_sha256=${upgrade_manifest_values[6]}
  [[ $upgrade_ready_shell_pre_sha256 != - ]] || upgrade_ready_shell_pre_sha256=
  upgrade_ready_shell_pre_mode=${upgrade_manifest_values[7]}
  [[ $upgrade_ready_shell_pre_mode != - ]] || upgrade_ready_shell_pre_mode=
  upgrade_ready_shell_pre_uid=${upgrade_manifest_values[8]}
  [[ $upgrade_ready_shell_pre_uid != - ]] || upgrade_ready_shell_pre_uid=
  upgrade_ready_shell_pre_gid=${upgrade_manifest_values[9]}
  [[ $upgrade_ready_shell_pre_gid != - ]] || upgrade_ready_shell_pre_gid=
  upgrade_ready_shell_restore_state=${upgrade_manifest_values[10]}
  local reservation_count=${upgrade_manifest_values[11]}
  [[ $reservation_count =~ ^[0-9]+$ ]] ||
    fail "invalid upgrade reservation count"
  upgrade_reservation_paths=()
  upgrade_reservation_tokens=()
  upgrade_reservation_temporary_paths=()
  local index
  local path
  local token
  local temporary
  for ((index = 0; index < reservation_count; index++)); do
    IFS=$'\t' read -r path token temporary \
      <<<"${upgrade_manifest_values[12 + index]}"
    upgrade_reservation_paths+=("$path")
    upgrade_reservation_tokens+=("$token")
    upgrade_reservation_temporary_paths+=("$temporary")
  done
  upgrade_owned_files=("${upgrade_manifest_values[@]:12 + reservation_count}")
}

trusted_upgrade_reservation_paths() {
  python3 - "$target_home" "${owned_files[@]}" -- "${upgrade_reservation_paths[@]}" <<'PY'
from pathlib import Path
import sys

arguments = sys.argv[1:]
try:
    separator = arguments.index("--")
except ValueError as error:
    raise SystemExit("missing reservation separator") from error

target_home = Path(arguments[0])
expected_files = arguments[1:separator]
observed = arguments[separator + 1 :]


def without_suffixes(*suffixes):
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


historical_plans = (
    expected_files,
    without_suffixes(*localized_search_suffixes),
    without_suffixes(
        *localized_search_suffixes,
        "/mrai.keyguide/components/ExecutablePicker.qml",
    ),
    without_suffixes(
        *localized_search_suffixes,
        "/keyguide_backend/shortcuts.py",
        "/mrai.keyguide/components/ShortcutEditRow.qml",
        "/mrai.keyguide/components/ExecutablePicker.qml",
    ),
    without_suffixes(
        *localized_search_suffixes,
        "/keyguide_backend/shortcuts.py",
        "/mrai.keyguide/components/ShortcutEditRow.qml",
        "/mrai.keyguide/VisibilityModel.js",
        "/mrai.keyguide/components/ExecutablePicker.qml",
    ),
    without_suffixes(
        *localized_search_suffixes,
        "/keyguide_backend/shortcuts.py",
        "/mrai.keyguide/components/ShortcutEditRow.qml",
        "/mrai.keyguide/VisibilityModel.js",
        "/icons/hicolor/scalable/apps/omarchy-keyguide.svg",
        "/mrai.keyguide/components/ExecutablePicker.qml",
    ),
    without_suffixes(
        *localized_search_suffixes,
        "/keyguide_backend/shortcuts.py",
        "/mrai.keyguide/components/ShortcutEditRow.qml",
        "/keyguide_backend/groups.py",
        "/keyguide_backend/presentation.py",
        "/mrai.keyguide/VisibilityModel.js",
        "/icons/hicolor/scalable/apps/omarchy-keyguide.svg",
        "/mrai.keyguide/components/ExecutablePicker.qml",
    ),
    without_suffixes(
        *localized_search_suffixes,
        "/keyguide_backend/shortcuts.py",
        "/mrai.keyguide/components/ShortcutEditRow.qml",
        "/keyguide_backend/groups.py",
        "/keyguide_backend/presentation.py",
        "/mrai.keyguide/BarWidget.qml",
        "/mrai.keyguide/VisibilityModel.js",
        "/icons/hicolor/scalable/apps/omarchy-keyguide.svg",
        "/mrai.keyguide/components/ExecutablePicker.qml",
    ),
)
trusted_sequences = []
for plan in historical_plans:
    sequence = [path for path in expected_files if path not in plan]
    if sequence not in trusted_sequences:
        trusted_sequences.append(sequence)
retained_visibility_sequence = [
    path for path in expected_files if path.endswith("/mrai.keyguide/VisibilityModel.js")
]
if retained_visibility_sequence and retained_visibility_sequence not in trusted_sequences:
    trusted_sequences.append(retained_visibility_sequence)
for path in observed:
    candidate = Path(path)
    try:
        relative = candidate.relative_to(target_home)
    except ValueError as error:
        raise SystemExit(f"upgrade reservation escapes target home: {candidate}") from error
    if any(component in {"", ".", ".."} for component in relative.parts):
        raise SystemExit(f"upgrade reservation has unsafe component: {candidate}")
if observed not in trusted_sequences:
    raise SystemExit("unsupported upgrade reservation plan")
print(len(observed))
for path in observed:
    print(path)
PY
}

keyguide_require_live_session_unlocked install

upgrade_manifest_present=false
if [[ -e $manifest_path || -L $manifest_path ]]; then
  upgrade_manifest_present=true
  if [[ $preserve_user_shell != 1 ]]; then
    fail "installation manifest already exists: $manifest_path"
  fi
  [[ -z $prefix_root ]] ||
    fail "PRESERVE_USER_SHELL=1 requires a live installation"
  [[ -f $manifest_path && ! -L $manifest_path ]] ||
    fail "preserve-user-shell upgrade requires a regular install manifest"
  inspect_upgrade_manifest
elif [[ $preserve_user_shell == 1 ]]; then
  fail "PRESERVE_USER_SHELL=1 requires an existing installation"
fi

upgrade_new_only_files=()
for destination in "${owned_files[@]}"; do
  resolved_destination=$(realpath -m -- "$destination")
  [[ $resolved_destination == "$target_home"/* ]] ||
    fail "destination escapes target home: $destination"
  destination_owned_by_upgrade=false
  for old_destination in "${upgrade_owned_files[@]}"; do
    if [[ $destination == "$old_destination" ]]; then
      destination_owned_by_upgrade=true
      break
    fi
  done
  destination_reserved_by_upgrade=false
  for reserved_destination in "${upgrade_reservation_paths[@]}"; do
    if [[ $destination == "$reserved_destination" ]]; then
      destination_reserved_by_upgrade=true
      break
    fi
  done
  if [[ $destination_owned_by_upgrade == false ]]; then
    upgrade_new_only_files+=("$destination")
    if [[ $upgrade_manifest_present == true && $upgrade_install_state == upgrade_ready ]]; then
      :
    elif [[ $destination_reserved_by_upgrade == false ]]; then
      [[ ! -e $destination && ! -L $destination ]] ||
        fail "refusing to overwrite unowned path: $destination"
    fi
  fi
done
upgrade_expected_reservation_paths=("${upgrade_new_only_files[@]}")
if [[ -n $upgrade_handoff_token ]]; then
  trusted_upgrade_reservation_info=$(trusted_upgrade_reservation_paths) ||
    fail "upgrade-ready reservation plan is not trusted"
  mapfile -t trusted_upgrade_reservation_values <<<"$trusted_upgrade_reservation_info"
  trusted_upgrade_reservation_count=${trusted_upgrade_reservation_values[0]}
  [[ $trusted_upgrade_reservation_count =~ ^[0-9]+$ ]] ||
    fail "invalid trusted upgrade reservation count"
  upgrade_expected_reservation_paths=("${trusted_upgrade_reservation_values[@]:1}")
  [[ ${#upgrade_expected_reservation_paths[@]} -eq $trusted_upgrade_reservation_count ]] ||
    fail "trusted upgrade reservation count mismatch"
fi

if ! python3 - "$target_home" "$manifest_path" "${owned_files[@]}" <<'PY'
from pathlib import Path
import sys

target_home = Path(sys.argv[1])
for candidate_arg in sys.argv[2:]:
    candidate = Path(candidate_arg)
    try:
        relative = candidate.relative_to(target_home)
    except ValueError as error:
        raise SystemExit(f"destination escapes target home: {candidate}") from error
    cursor = target_home
    for component in relative.parts[:-1]:
        cursor /= component
        if cursor.is_symlink():
            raise SystemExit(f"symlinked destination component: {cursor}")
        if not cursor.exists():
            break
PY
then
  fail "symlinked destination component detected"
fi

if [[ $upgrade_manifest_present == true ]]; then
  if [[ -z $upgrade_handoff_token || $upgrade_install_state == rebasing ]]; then
    if KEYGUIDE_PRESERVE_UPGRADE=1 \
      KEYGUIDE_EXPECTED_PLUGIN_WAS_ENABLED="$upgrade_plugin_was_enabled" \
      REMOVE_PREFERENCES=0 \
      bash scripts/uninstall.sh "${upgrade_new_only_files[@]}"
    then
      :
    else
      upgrade_uninstall_status=$?
      [[ $upgrade_uninstall_status -ne 75 ]] || exit 75
      fail "preserve-user-shell upgrade rejected"
    fi
    upgrade_shell_restarted=true
  elif [[ $upgrade_install_state == restart_pending ]]; then
    if KEYGUIDE_PRESERVE_UPGRADE=1 \
      KEYGUIDE_EXPECTED_PLUGIN_WAS_ENABLED="$upgrade_plugin_was_enabled" \
      KEYGUIDE_UPGRADE_HANDOFF_TOKEN="$upgrade_handoff_token" \
      REMOVE_PREFERENCES=0 \
      bash scripts/uninstall.sh "${upgrade_expected_reservation_paths[@]}"
    then
      :
    else
      upgrade_uninstall_status=$?
      [[ $upgrade_uninstall_status -ne 75 ]] || exit 75
      fail "preserve-user-shell upgrade recovery rejected"
    fi
    upgrade_recovered_restart_pending=true
    upgrade_shell_restarted=true
  elif [[ $upgrade_install_state != upgrade_ready ]]; then
    if KEYGUIDE_PRESERVE_UPGRADE=0 \
      KEYGUIDE_EXPECTED_PLUGIN_WAS_ENABLED="$upgrade_plugin_was_enabled" \
      KEYGUIDE_UPGRADE_HANDOFF_TOKEN="$upgrade_handoff_token" \
      REMOVE_PREFERENCES=0 \
      bash scripts/uninstall.sh
    then
      :
    else
      upgrade_uninstall_status=$?
      [[ $upgrade_uninstall_status -ne 75 ]] || exit 75
      fail "preserve-user-shell upgrade recovery rejected"
    fi
    upgrade_shell_restarted=true
  fi
  if [[ $upgrade_shell_restarted == true ]]; then
    keyguide_wait_live_session_unlocked install
  fi
  [[ -f $manifest_path && ! -L $manifest_path ]] ||
    fail "preserve-user-shell upgrade lost its handoff manifest"
  inspect_upgrade_manifest
  [[ $upgrade_install_state == upgrade_ready && -n $upgrade_handoff_token ]] ||
    fail "preserve-user-shell upgrade did not reach upgrade-ready state"
  if KEYGUIDE_VALIDATE_ONLY=1 \
    KEYGUIDE_PRESERVE_UPGRADE=1 \
    KEYGUIDE_EXPECTED_PLUGIN_WAS_ENABLED="$upgrade_plugin_was_enabled" \
    KEYGUIDE_UPGRADE_HANDOFF_TOKEN="$upgrade_handoff_token" \
    REMOVE_PREFERENCES=0 \
    bash scripts/uninstall.sh "${upgrade_expected_reservation_paths[@]}"
  then
    :
  else
    upgrade_uninstall_status=$?
    [[ $upgrade_uninstall_status -ne 75 ]] || exit 75
    fail "upgrade-ready manifest validation failed"
  fi
fi

for destination in "${owned_files[@]}"; do
  resolved_destination=$(realpath -m -- "$destination")
  [[ $resolved_destination == "$target_home"/* ]] ||
    fail "destination escapes target home: $destination"
  destination_reserved_by_upgrade=false
  for reserved_destination in "${upgrade_reservation_paths[@]}"; do
    if [[ $destination == "$reserved_destination" ]]; then
      destination_reserved_by_upgrade=true
      break
    fi
  done
  if [[ $destination_reserved_by_upgrade == false ]]; then
    [[ ! -e $destination && ! -L $destination ]] ||
      fail "refusing to overwrite unowned path: $destination"
  fi
done

if ! python3 - "$target_home" "$manifest_path" "${owned_files[@]}" <<'PY'
from pathlib import Path
import sys

target_home = Path(sys.argv[1])
for candidate_arg in sys.argv[2:]:
    candidate = Path(candidate_arg)
    try:
        relative = candidate.relative_to(target_home)
    except ValueError as error:
        raise SystemExit(f"destination escapes target home: {candidate}") from error
    cursor = target_home
    for component in relative.parts[:-1]:
        cursor /= component
        if cursor.is_symlink():
            raise SystemExit(f"symlinked destination component: {cursor}")
        if not cursor.exists():
            break
PY
then
  fail "symlinked destination component detected"
fi

plugin_was_enabled=false
if [[ -z $prefix_root ]]; then
  if [[ -n $upgrade_plugin_was_enabled ]]; then
    plugin_was_enabled=$upgrade_plugin_was_enabled
  else
    plugin_catalog=$(omarchy plugin list --json)
    plugin_was_enabled=$(python3 -c '
import json
import sys

try:
    plugins = json.load(sys.stdin)
except (UnicodeError, ValueError) as error:
    raise SystemExit(f"invalid plugin catalog: {error}") from error
if not isinstance(plugins, list):
    raise SystemExit("plugin catalog must be a list")
enabled = any(
    isinstance(plugin, dict)
    and plugin.get("id") == "mrai.keyguide"
    and plugin.get("enabled") is True
    for plugin in plugins
)
print("true" if enabled else "false")
' <<<"$plugin_catalog") || fail "could not determine existing plugin state"
  fi
fi

if [[ -e $state_dir || -L $state_dir ]]; then
  [[ -d $state_dir && ! -L $state_dir ]] ||
    fail "state path is not a directory: $state_dir"
else
  install -d -m755 "$state_dir"
fi

shell_preexisting=false
shell_post_enable_sha256=
shell_post_enable_present=false
shell_pre_mode=
shell_pre_sha256=
shell_pre_uid=
shell_pre_gid=
shell_restore_state=not_started
bar_placement_preexisting=false
bar_placement_owned_by_installer=false
bar_placement_state=not_started
bar_staging_path=
bar_staging_sha256=
bar_staging_mode=
manifest_publication=create
if [[ $upgrade_install_state == upgrade_ready ]]; then
  [[ $upgrade_ready_shell_preexisting == true &&
    $upgrade_ready_shell_backup == "$shell_backup" &&
    $upgrade_ready_shell_pre_sha256 =~ ^[0-9a-f]{64}$ &&
    $upgrade_ready_shell_pre_mode =~ ^[0-7]{3,4}$ &&
    $upgrade_ready_shell_restore_state == not_started ]] ||
    fail "upgrade-ready manifest has an invalid shell baseline"
  [[ -f $shell_config && ! -L $shell_config ]] ||
    fail "upgrade-ready shell config is not a regular file"
  [[ -f $shell_backup && ! -L $shell_backup ]] ||
    fail "upgrade-ready shell backup is not a regular file"
  ready_shell_sha256=$(sha256sum -- "$shell_config" | cut -d' ' -f1)
  ready_shell_mode=$(stat -c '%a' -- "$shell_config")
  ready_shell_uid=$(stat -c '%u' -- "$shell_config")
  ready_shell_gid=$(stat -c '%g' -- "$shell_config")
  [[ $ready_shell_sha256 == "$upgrade_ready_shell_pre_sha256" &&
    $ready_shell_mode == "$upgrade_ready_shell_pre_mode" ]] ||
    fail "upgrade-ready shell config changed before adoption"
  ready_backup_sha256=$(sha256sum -- "$shell_backup" | cut -d' ' -f1)
  ready_backup_mode=$(stat -c '%a' -- "$shell_backup")
  ready_backup_uid=$(stat -c '%u' -- "$shell_backup")
  ready_backup_gid=$(stat -c '%g' -- "$shell_backup")
  [[ $ready_backup_sha256 == "$upgrade_ready_shell_pre_sha256" &&
    $ready_backup_mode == 600 ]] ||
    fail "upgrade-ready shell backup changed before adoption"
  if [[ -n $upgrade_ready_shell_pre_uid ]]; then
    [[ $ready_shell_uid == "$upgrade_ready_shell_pre_uid" &&
      $ready_backup_uid == "$upgrade_ready_shell_pre_uid" ]] ||
      fail "upgrade-ready shell owner changed before adoption"
  fi
  if [[ -n $upgrade_ready_shell_pre_gid ]]; then
    [[ $ready_shell_gid == "$upgrade_ready_shell_pre_gid" &&
      $ready_backup_gid == "$upgrade_ready_shell_pre_gid" ]] ||
      fail "upgrade-ready shell group changed before adoption"
  fi
  bar_placement_status=$(shell_bar_placement_status) ||
    fail "could not inspect upgrade-ready Keyguide bar placement"
  [[ $bar_placement_status == absent ]] ||
    fail "upgrade-ready shell unexpectedly contains a Keyguide bar placement"
  shell_preexisting=true
  shell_post_enable_sha256=$upgrade_ready_shell_pre_sha256
  shell_post_enable_present=true
  shell_pre_mode=$upgrade_ready_shell_pre_mode
  shell_pre_sha256=$upgrade_ready_shell_pre_sha256
  shell_pre_uid=$upgrade_ready_shell_pre_uid
  shell_pre_gid=$upgrade_ready_shell_pre_gid
  if [[ $upgrade_recovered_restart_pending == true ]]; then
    bar_placement_preexisting=true
  fi
  manifest_publication=replace
elif [[ -z $prefix_root && ( -e $shell_config || -L $shell_config ) ]]; then
  [[ -f $shell_config && ! -L $shell_config ]] || fail "shell config is not a regular file"
  bar_placement_status=$(shell_bar_placement_status) ||
    fail "could not inspect Keyguide bar placement"
  if [[ $bar_placement_status != absent ]]; then
    bar_placement_preexisting=true
    bar_placement_state=preexisting
  fi
  [[ ! -e $shell_backup && ! -L $shell_backup ]] || fail "shell backup already exists"
  shell_preexisting=true
  shell_pre_mode=$(stat -c '%a' -- "$shell_config")
  shell_pre_sha256=$(sha256sum -- "$shell_config" | cut -d' ' -f1)
  shell_pre_uid=$(stat -c '%u' -- "$shell_config")
  shell_pre_gid=$(stat -c '%g' -- "$shell_config")
fi

capture_shell_postimage() {
  if [[ -e $shell_config || -L $shell_config ]]; then
    [[ -f $shell_config && ! -L $shell_config ]] ||
      fail "updated shell config is not a regular file"
    shell_post_enable_present=true
    shell_post_enable_sha256=$(sha256sum -- "$shell_config" | cut -d' ' -f1)
  else
    shell_post_enable_present=false
    shell_post_enable_sha256=
  fi
}

canonicalize_enable_inserted_bar_placement() {
  python3 - \
    "$shell_config" \
    "$shell_backup" \
    "$shell_pre_sha256" \
    "$shell_pre_mode" \
    "$target_home" <<'PY'
import ctypes
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import tempfile

shell = Path(sys.argv[1])
backup = Path(sys.argv[2])
pre_sha256 = sys.argv[3]
pre_mode = int(sys.argv[4], 8)
target_home = Path(sys.argv[5])


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate shell key: {key}")
        result[key] = value
    return result


def read_regular(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW)
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError(f"not a regular file: {path}")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks), info
    finally:
        os.close(descriptor)


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


live_bytes, live_info = read_regular(shell)
if stat.S_IMODE(live_info.st_mode) != pre_mode:
    raise RuntimeError("enable-inserted shell mode changed")
backup_bytes, _ = read_regular(backup)
if hashlib.sha256(backup_bytes).hexdigest() != pre_sha256:
    raise RuntimeError("backup hash does not match authenticated preimage")
live_document = json.loads(live_bytes.decode("utf-8"), object_pairs_hook=unique_object)
backup_document = json.loads(
    backup_bytes.decode("utf-8"), object_pairs_hook=unique_object
)
if not isinstance(live_document, dict) or not isinstance(backup_document, dict):
    raise RuntimeError("shell documents must be objects")

bar = live_document.get("bar")
layout = bar.get("layout") if isinstance(bar, dict) else None
if not isinstance(layout, dict):
    raise RuntimeError("shell bar layout is missing")
locations = []
agents_locations = []
for section in ("left", "center", "right"):
    entries = layout.get(section)
    if not isinstance(entries, list):
        raise RuntimeError(f"shell bar {section} must be an array")
    for index, entry in enumerate(entries):
        entry_id = entry.get("id") if isinstance(entry, dict) else entry
        if entry_id == "mrai.keyguide":
            locations.append((section, index, entries, entry))
        if entry_id == "omarchy.agents":
            agents_locations.append((section, index, entries))
if len(locations) != 1 or len(agents_locations) != 1:
    raise RuntimeError("enable-inserted placement is not unique")
section, index, entries, entry = locations[0]
if entry != {"id": "mrai.keyguide"}:
    raise RuntimeError("enable-inserted placement has settings")
candidate_without = json.loads(
    json.dumps(live_document), object_pairs_hook=unique_object
)
candidate_layout = candidate_without["bar"]["layout"]
candidate_entries = candidate_layout[section]
del candidate_entries[index]
if not json_equal(candidate_without, backup_document):
    raise RuntimeError("enable-inserted placement changed unrelated state")

agent_section, agent_index, _ = agents_locations[0]
if section == agent_section and index == agent_index + 1:
    print(hashlib.sha256(live_bytes).hexdigest())
    raise SystemExit(0)
entry_to_move = entries.pop(index)
agent_entries = layout[agent_section]
if section == agent_section and index < agent_index:
    agent_index -= 1
agent_entries.insert(agent_index + 1, entry_to_move)
output = (
    json.dumps(live_document, indent=2, ensure_ascii=False, sort_keys=True) + "\n"
).encode("utf-8")

try:
    relative_parent = shell.parent.relative_to(target_home)
except ValueError as error:
    raise RuntimeError("shell parent escapes target home") from error
parent_descriptor = os.open(
    target_home,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)
for component in relative_parent.parts:
    if component in {"", ".", ".."}:
        os.close(parent_descriptor)
        raise RuntimeError("shell parent has an invalid component")
    next_descriptor = os.open(
        component,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
        dir_fd=parent_descriptor,
    )
    os.close(parent_descriptor)
    parent_descriptor = next_descriptor
temporary_descriptor, temporary_path = tempfile.mkstemp(
    prefix=f".{shell.name}.keyguide-enable-placement.",
    suffix=".tmp",
    dir=shell.parent,
)
temporary = Path(temporary_path)
try:
    os.fchmod(temporary_descriptor, pre_mode)
    if os.geteuid() == 0:
        os.fchown(temporary_descriptor, live_info.st_uid, live_info.st_gid)
    remaining = memoryview(output)
    while remaining:
        written = os.write(temporary_descriptor, remaining)
        if written <= 0:
            raise OSError("short write while staging canonical placement")
        remaining = remaining[written:]
    os.fsync(temporary_descriptor)
finally:
    os.close(temporary_descriptor)
renameat2 = ctypes.CDLL(None, use_errno=True).renameat2
renameat2.argtypes = (
    ctypes.c_int,
    ctypes.c_char_p,
    ctypes.c_int,
    ctypes.c_char_p,
    ctypes.c_uint,
)
renameat2.restype = ctypes.c_int
try:
    if renameat2(
        parent_descriptor,
        os.fsencode(temporary.name),
        parent_descriptor,
        os.fsencode(shell.name),
        2,
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))
    os.fsync(parent_descriptor)
    displaced_bytes, displaced_info = read_regular(temporary)
    if (
        displaced_bytes != live_bytes
        or displaced_info.st_dev != live_info.st_dev
        or displaced_info.st_ino != live_info.st_ino
    ):
        if renameat2(
            parent_descriptor,
            os.fsencode(temporary.name),
            parent_descriptor,
            os.fsencode(shell.name),
            2,
        ) != 0:
            error_number = ctypes.get_errno()
            raise OSError(error_number, os.strerror(error_number))
        os.fsync(parent_descriptor)
        raise RuntimeError("shell changed during enable-placement canonicalization")
    os.unlink(temporary.name, dir_fd=parent_descriptor)
    os.fsync(parent_descriptor)
finally:
    os.close(parent_descriptor)
    try:
        temporary.unlink()
    except FileNotFoundError:
        pass
print(hashlib.sha256(output).hexdigest())
PY
}

write_manifest() {
  local enabled_by_installer=$1
  local install_state=$2
  local plugin_enable_state=$3
  local publication=$4
  local next_manifest_sha256
  next_manifest_sha256=$(python3 - \
    "$manifest_path" \
    "$prefix_root" \
    "$target_home" \
    "$plugin_was_enabled" \
    "$enabled_by_installer" \
    "$install_state" \
    "$plugin_enable_state" \
    "$pending_reservation_path" \
    "$pending_reservation_token" \
    "$pending_reservation_temporary_path" \
    "$pending_reservation_payload_sha256" \
    "$pending_reservation_payload_mode" \
    "$publication" \
    "$shell_preexisting" \
    "$shell_backup" \
    "$shell_post_enable_sha256" \
    "$shell_post_enable_present" \
    "$shell_pre_mode" \
    "$shell_pre_sha256" \
    "$shell_pre_uid" \
    "$shell_pre_gid" \
    "$shell_restore_state" \
    "$bar_placement_owned_by_installer" \
    "$bar_placement_state" \
    "$bar_staging_path" \
    "$bar_staging_sha256" \
    "$bar_staging_mode" \
    "$retain_upgrade_handoff" \
    "$manifest_expected_sha256" \
    "$completed_payload_path" \
    "$completed_payload_sha256" \
    "$completed_payload_mode" \
    "$completed_payload_identity" \
    "${journal_files[@]}" <<'PY'
import ctypes
import hashlib
import json
import os
from pathlib import Path
import stat
import sys
import tempfile

(
    manifest_arg,
    prefix_root,
    target_home,
    plugin_was_enabled,
    plugin_enabled_by_installer,
    install_state,
    plugin_enable_state,
    pending_reservation_path,
    pending_reservation_token,
    pending_reservation_temporary_path,
    pending_reservation_payload_sha256,
    pending_reservation_payload_mode,
    publication,
    shell_preexisting,
    shell_backup_path,
    shell_post_enable_sha256,
    shell_post_enable_present,
    shell_pre_mode,
    shell_pre_sha256,
    shell_pre_uid,
    shell_pre_gid,
    shell_restore_state,
    bar_placement_owned_by_installer,
    bar_placement_state,
    bar_staging_path,
    bar_staging_sha256,
    bar_staging_mode,
    retain_upgrade_handoff,
    expected_manifest_sha256,
    completed_payload_path,
    completed_payload_sha256,
    completed_payload_mode,
    completed_payload_identity,
    *owned_files,
) = sys.argv[1:]
manifest = Path(manifest_arg)


def snapshot(path):
    descriptor = os.open(
        path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
    )
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError("install manifest is not a regular file")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return (
            b"".join(chunks),
            (info.st_dev, info.st_ino, info.st_mode, info.st_size, info.st_mtime_ns),
        )
    finally:
        os.close(descriptor)


def same_snapshot(left, right):
    return left[0] == right[0] and left[1] == right[1]


def snapshot_regular_endpoint(path_arg, label):
    path = Path(path_arg)
    try:
        path.relative_to(Path(target_home))
    except ValueError as error:
        raise RuntimeError(f"{label} escapes target home: {path}") from error
    descriptor = os.open(
        path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
    )
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError(f"{label} is not a regular file: {path}")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        data = b"".join(chunks)
        return (
            data,
            (
                info.st_dev,
                info.st_ino,
                info.st_mode,
                info.st_size,
                info.st_mtime_ns,
                info.st_uid,
                info.st_gid,
            ),
        )
    finally:
        os.close(descriptor)


def verify_completed_payload(snapshot_value):
    if not completed_payload_path:
        return
    if not completed_payload_sha256 or not completed_payload_mode:
        raise RuntimeError("completed payload verification is incomplete")
    if hashlib.sha256(snapshot_value[0]).hexdigest() != completed_payload_sha256:
        raise RuntimeError("completed payload changed before ownership journal")
    if stat.S_IMODE(snapshot_value[1][2]) != int(completed_payload_mode, 8):
        raise RuntimeError("completed payload mode changed before ownership journal")


def same_completed_payload_endpoint(observed):
    if completed_payload_snapshot is not None:
        return observed[0] == completed_payload_snapshot[0] and observed[1] == completed_payload_snapshot[1]
    return False


def expected_completed_payload_identity():
    if not completed_payload_identity:
        return None
    parts = completed_payload_identity.split("\t")
    if len(parts) != 8:
        raise RuntimeError("completed payload identity is malformed")
    return (
        tuple(int(value) for value in parts[:7]),
        parts[7],
    )


def exchange(parent_descriptor, left, right):
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


previous_snapshot = None
if publication == "replace":
    previous_snapshot = snapshot(manifest)
    if hashlib.sha256(previous_snapshot[0]).hexdigest() != expected_manifest_sha256:
        raise RuntimeError("install manifest changed before publication")
upgrade_handoff = None
if retain_upgrade_handoff == "true":
    if publication != "replace":
        raise RuntimeError("upgrade handoff requires manifest replacement")
    previous_document = json.loads(previous_snapshot[0].decode("utf-8"))
    upgrade_handoff = previous_document.get("upgrade_handoff")
    if not isinstance(upgrade_handoff, dict):
        raise RuntimeError("upgrade handoff is unavailable")
completed_payload_snapshot = None
if completed_payload_path:
    completed_payload_snapshot = snapshot_regular_endpoint(
        completed_payload_path, "completed payload"
    )
    verify_completed_payload(completed_payload_snapshot)
    expected_identity = expected_completed_payload_identity()
    if expected_identity is not None and (
        completed_payload_snapshot[1] != expected_identity[0]
        or hashlib.sha256(completed_payload_snapshot[0]).hexdigest()
        != expected_identity[1]
    ):
        raise RuntimeError("completed payload endpoint changed before ownership journal")
shell_config_document = {
    "preexisting": shell_preexisting == "true",
    "backup_path": shell_backup_path if shell_preexisting == "true" else "",
    "post_enable_sha256": shell_post_enable_sha256,
    "post_enable_present": shell_post_enable_present == "true",
    "pre_mode": shell_pre_mode,
    "pre_sha256": shell_pre_sha256,
    "pre_uid": int(shell_pre_uid) if shell_pre_uid else None,
    "pre_gid": int(shell_pre_gid) if shell_pre_gid else None,
    "restore_state": shell_restore_state,
    "bar_placement_owned_by_installer": (
        bar_placement_owned_by_installer == "true"
    ),
    "bar_placement_state": bar_placement_state,
}
if bar_staging_path or bar_staging_sha256 or bar_staging_mode:
    if (
        not bar_staging_path
        or not bar_staging_sha256
        or not bar_staging_mode
    ):
        raise RuntimeError("staged bar output journal is incomplete")
    shell_config_document["bar_staging_path"] = bar_staging_path
    shell_config_document["bar_staging_sha256"] = bar_staging_sha256
    shell_config_document["bar_staging_mode"] = bar_staging_mode

document = {
    "schema_version": 1,
    "plugin_id": "mrai.keyguide",
    "prefix_root": prefix_root,
    "target_home": target_home,
    "plugin_was_enabled": plugin_was_enabled == "true",
    "plugin_enabled_by_installer": plugin_enabled_by_installer == "true",
    "install_state": install_state,
    "plugin_enable_state": plugin_enable_state,
    "pending_reservation": (
        {
            "path": pending_reservation_path,
            "token": pending_reservation_token,
            "temporary_path": pending_reservation_temporary_path,
            "payload_sha256": pending_reservation_payload_sha256,
            "payload_mode": int(pending_reservation_payload_mode, 8),
        }
        if pending_reservation_path
        else None
    ),
    "shell_config": shell_config_document,
    "owned_files": owned_files,
}
if upgrade_handoff is not None:
    document["upgrade_handoff"] = upgrade_handoff
descriptor, temporary_arg = tempfile.mkstemp(
    prefix=f".{manifest.name}.", suffix=".tmp", dir=manifest.parent
)
temporary = Path(temporary_arg)
preserve_temporary = False
try:
    os.fchmod(descriptor, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
        descriptor = -1
        json.dump(document, stream, indent=2)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())

    directory_descriptor = os.open(
        manifest.parent,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
    )
    try:
        if publication == "create":
            os.link(temporary, manifest, follow_symlinks=False)
            temporary.unlink()
        elif publication == "replace":
            staged_snapshot = snapshot(temporary)
            observed = snapshot(manifest)
            if not same_snapshot(observed, previous_snapshot):
                raise RuntimeError("install manifest changed before publication")
            if completed_payload_snapshot is not None:
                observed_payload = snapshot_regular_endpoint(
                    completed_payload_path, "completed payload"
                )
                verify_completed_payload(observed_payload)
                if not same_completed_payload_endpoint(observed_payload):
                    raise RuntimeError(
                        "completed payload endpoint changed before ownership journal"
                    )
            exchange(directory_descriptor, temporary.name, manifest.name)
            preserve_temporary = True
            try:
                displaced = snapshot(temporary)
            except (OSError, RuntimeError) as error:
                raise RuntimeError(
                    f"install manifest changed during publication; displaced endpoint preserved at {temporary}"
                ) from error
            if not same_snapshot(displaced, previous_snapshot):
                current = snapshot(manifest)
                if same_snapshot(current, staged_snapshot):
                    try:
                        exchange(directory_descriptor, temporary.name, manifest.name)
                        os.fsync(directory_descriptor)
                        preserve_temporary = False
                    except OSError as error:
                        raise RuntimeError(
                            f"install manifest changed during publication; rollback failed and displaced endpoint is preserved at {temporary}"
                        ) from error
                raise RuntimeError("install manifest changed during publication")
            published = snapshot(manifest)
            if not same_snapshot(published, staged_snapshot):
                raise RuntimeError(
                    f"install manifest changed after publication; displaced endpoint preserved at {temporary}"
                )
            if completed_payload_snapshot is not None:
                try:
                    observed_payload = snapshot_regular_endpoint(
                        completed_payload_path, "completed payload"
                    )
                    verify_completed_payload(observed_payload)
                    if not same_completed_payload_endpoint(observed_payload):
                        raise RuntimeError(
                            "completed payload endpoint changed after ownership journal"
                        )
                except (OSError, RuntimeError) as error:
                    current = snapshot(manifest)
                    if same_snapshot(current, staged_snapshot):
                        try:
                            exchange(directory_descriptor, temporary.name, manifest.name)
                            os.fsync(directory_descriptor)
                            preserve_temporary = False
                        except OSError as rollback_error:
                            raise RuntimeError(
                                f"completed payload changed after ownership journal; rollback failed and displaced endpoint is preserved at {temporary}"
                            ) from rollback_error
                    raise RuntimeError(
                        "completed payload changed after ownership journal"
                    ) from error
            temporary.unlink()
            preserve_temporary = False
        else:
            raise RuntimeError(f"unknown manifest publication mode: {publication}")
        os.fsync(directory_descriptor)
    finally:
        os.close(directory_descriptor)
    manifest_bytes = (json.dumps(document, indent=2) + "\n").encode("utf-8")
    print(hashlib.sha256(manifest_bytes).hexdigest())
finally:
    if descriptor >= 0:
        os.close(descriptor)
    if not preserve_temporary:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass
PY
  ) || fail "could not publish install manifest"
  [[ $next_manifest_sha256 =~ ^[0-9a-f]{64}$ ]] ||
    fail "invalid install manifest digest"
  manifest_expected_sha256=$next_manifest_sha256
}

if [[ -n $prefix_root ]]; then
  plugin_enable_state=skipped
elif [[ $plugin_was_enabled == true ]]; then
  plugin_enable_state=preexisting
else
  plugin_enable_state=not_started
fi

journal_files=()
pending_reservation_path=
pending_reservation_token=
pending_reservation_temporary_path=
pending_reservation_payload_sha256=
pending_reservation_payload_mode=
completed_payload_path=
completed_payload_sha256=
completed_payload_mode=
completed_payload_identity=
retain_upgrade_handoff=false
[[ -z $upgrade_handoff_token ]] || retain_upgrade_handoff=true
manifest_expected_sha256=
if [[ $manifest_publication == replace ]]; then
  if [[ -n $upgrade_manifest_sha256 ]]; then
    manifest_expected_sha256=$upgrade_manifest_sha256
  else
    manifest_expected_sha256=$(sha256sum -- "$manifest_path" | cut -d' ' -f1)
  fi
fi
if [[ -n ${KEYGUIDE_TEST_HOOK_UPGRADE_HANDOFF_BEFORE_ADOPT:-} &&
  $retain_upgrade_handoff == true &&
  ! -e ${KEYGUIDE_TEST_HOOK_UPGRADE_HANDOFF_BEFORE_ADOPT} ]]; then
  python3 - "$manifest_path" "${KEYGUIDE_TEST_HOOK_UPGRADE_HANDOFF_BEFORE_ADOPT}" <<'PY'
import json
from pathlib import Path
import sys

manifest = Path(sys.argv[1])
marker = Path(sys.argv[2])
document = json.loads(manifest.read_text(encoding="utf-8"))
document["upgrade_handoff"]["reservations"] = []
manifest.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
marker.touch()
PY
fi
write_manifest false installing "$plugin_enable_state" "$manifest_publication"

if [[ $shell_preexisting == true && $manifest_publication == create ]]; then
  install -m600 "$shell_config" "$shell_backup"
  shell_backup_sha256=$(sha256sum -- "$shell_backup" | cut -d' ' -f1)
  [[ $shell_backup_sha256 == "$shell_pre_sha256" ]] ||
    fail "shell backup does not match captured pre-image"
  python3 - "$shell_backup" "$state_dir" "$shell_pre_uid" "$shell_pre_gid" <<'PY'
import os
from pathlib import Path
import stat
import sys

backup = Path(sys.argv[1])
state_directory = Path(sys.argv[2])
expected_uid = sys.argv[3]
expected_gid = sys.argv[4]
descriptor = os.open(
    backup, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW
)
try:
    info = os.fstat(descriptor)
    if not stat.S_ISREG(info.st_mode):
        raise RuntimeError("shell backup is not a regular file")
    if expected_uid and info.st_uid != int(expected_uid):
        raise RuntimeError("shell backup owner does not match captured pre-image")
    if expected_gid and info.st_gid != int(expected_gid):
        raise RuntimeError("shell backup group does not match captured pre-image")
    os.fsync(descriptor)
finally:
    os.close(descriptor)
directory_descriptor = os.open(
    state_directory, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
)
try:
    os.fsync(directory_descriptor)
finally:
    os.close(directory_descriptor)
PY
fi

reserve_destination() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import os
from pathlib import Path
import stat
import sys

destination = Path(sys.argv[1])
temporary = Path(sys.argv[2])
token = sys.argv[3].encode("ascii")
target_home = Path(sys.argv[4])
if temporary.parent != destination.parent:
    raise SystemExit("reservation staging file is not beside destination")
try:
    relative_parent = destination.parent.relative_to(target_home)
except ValueError as error:
    raise RuntimeError("destination parent escapes target home") from error
parent_descriptor = os.open(
    target_home,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)
for component in relative_parent.parts:
    if component in {"", ".", ".."}:
        os.close(parent_descriptor)
        raise RuntimeError("destination parent has an invalid component")
    try:
        next_descriptor = os.open(
            component,
            os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
            dir_fd=parent_descriptor,
        )
    except FileNotFoundError:
        os.mkdir(component, 0o755, dir_fd=parent_descriptor)
        os.fsync(parent_descriptor)
        next_descriptor = os.open(
            component,
            os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
            dir_fd=parent_descriptor,
        )
    os.close(parent_descriptor)
    parent_descriptor = next_descriptor
descriptor = -1
try:
    descriptor = os.open(
        temporary.name,
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | os.O_CLOEXEC
        | os.O_NOFOLLOW,
        0o600,
        dir_fd=parent_descriptor,
    )
    os.fchmod(descriptor, 0o600)
    remaining = memoryview(token)
    while remaining:
        written = os.write(descriptor, remaining)
        if written <= 0:
            raise OSError("short write while staging destination reservation")
        remaining = remaining[written:]
    os.fsync(descriptor)
    os.link(
        temporary.name,
        destination.name,
        src_dir_fd=parent_descriptor,
        dst_dir_fd=parent_descriptor,
        follow_symlinks=False,
    )
    staged_stat = os.fstat(descriptor)
    published_stat = os.stat(
        destination.name,
        dir_fd=parent_descriptor,
        follow_symlinks=False,
    )
    if (
        not stat.S_ISREG(published_stat.st_mode)
        or (staged_stat.st_dev, staged_stat.st_ino)
        != (published_stat.st_dev, published_stat.st_ino)
    ):
        raise RuntimeError("published reservation does not match staging file")
    os.fsync(parent_descriptor)
    os.unlink(temporary.name, dir_fd=parent_descriptor)
    os.fsync(parent_descriptor)
finally:
    if descriptor >= 0:
        os.close(descriptor)
    os.close(parent_descriptor)
PY
}

adopt_upgrade_reservation() {
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import os
from pathlib import Path
import stat
import sys

destination = Path(sys.argv[1])
temporary = Path(sys.argv[2])
token = sys.argv[3].encode("ascii")
target_home = Path(sys.argv[4])
if temporary.parent != destination.parent:
    raise RuntimeError("upgrade reservation staging path is not adjacent")
try:
    relative_parent = destination.parent.relative_to(target_home)
except ValueError as error:
    raise RuntimeError("upgrade reservation parent escapes target home") from error
parent_descriptor = os.open(
    target_home,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)
for component in relative_parent.parts:
    if component in {"", ".", ".."}:
        os.close(parent_descriptor)
        raise RuntimeError("upgrade reservation parent has an invalid component")
    next_descriptor = os.open(
        component,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
        dir_fd=parent_descriptor,
    )
    os.close(parent_descriptor)
    parent_descriptor = next_descriptor
try:
    try:
        os.stat(temporary.name, dir_fd=parent_descriptor, follow_symlinks=False)
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError("upgrade reservation retains a staging path")
    descriptor = os.open(
        destination.name,
        os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
        dir_fd=parent_descriptor,
    )
    try:
        info = os.fstat(descriptor)
        data = os.read(descriptor, len(token) + 1)
        if (
            not stat.S_ISREG(info.st_mode)
            or stat.S_IMODE(info.st_mode) != 0o600
            or info.st_size != len(token)
            or data != token
        ):
            raise RuntimeError(
                f"upgrade reservation changed before adoption: {destination}"
            )
    finally:
        os.close(descriptor)
    os.fsync(parent_descriptor)
finally:
    os.close(parent_descriptor)
PY
}

publish_reserved_payload() {
  python3 - "$1" "$2" "$3" "$4" "$5" "$6" "$7" <<'PY'
import ctypes
import hashlib
import os
from pathlib import Path
import stat
import sys

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
temporary = Path(sys.argv[3])
token = sys.argv[4].encode("ascii")
expected_payload_sha256 = sys.argv[5]
payload_mode = int(sys.argv[6], 8)
target_home = Path(sys.argv[7])
if temporary.parent != destination.parent:
    raise RuntimeError("payload staging path is not adjacent to destination")
try:
    relative_parent = destination.parent.relative_to(target_home)
except ValueError as error:
    raise RuntimeError("payload destination parent escapes target home") from error
parent_descriptor = os.open(
    target_home,
    os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
)
for component in relative_parent.parts:
    if component in {"", ".", ".."}:
        os.close(parent_descriptor)
        raise RuntimeError("payload destination parent has an invalid component")
    next_descriptor = os.open(
        component,
        os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW,
        dir_fd=parent_descriptor,
    )
    os.close(parent_descriptor)
    parent_descriptor = next_descriptor


def snapshot_name(name):
    descriptor = os.open(
        name,
        os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK,
        dir_fd=parent_descriptor,
    )
    try:
        info = os.fstat(descriptor)
        if not stat.S_ISREG(info.st_mode):
            raise RuntimeError(f"payload endpoint is not regular: {name}")
        chunks = []
        while True:
            chunk = os.read(descriptor, 65536)
            if not chunk:
                break
            chunks.append(chunk)
        return (
            b"".join(chunks),
            (
                info.st_dev,
                info.st_ino,
                stat.S_IMODE(info.st_mode),
                info.st_size,
                info.st_mtime_ns,
            ),
        )
    finally:
        os.close(descriptor)


def same_snapshot(left, right):
    return left[0] == right[0] and left[1] == right[1]


def lstat_name(name):
    info = os.stat(name, dir_fd=parent_descriptor, follow_symlinks=False)
    return (
        info.st_dev,
        info.st_ino,
        info.st_mode,
        info.st_size,
        info.st_mtime_ns,
        info.st_ctime_ns,
    )


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


def rollback(displaced_identity, reason):
    try:
        current = snapshot_name(destination.name)
    except (OSError, RuntimeError) as error:
        raise RuntimeError(
            f"payload publication changed after exchange; displaced endpoint "
            f"preserved at {temporary}"
        ) from error
    if not same_snapshot(current, staged_snapshot):
        raise RuntimeError(
            f"payload publication changed after exchange; displaced endpoint "
            f"preserved at {temporary}"
        )
    try:
        exchange(temporary.name, destination.name)
        os.fsync(parent_descriptor)
    except OSError as error:
        raise RuntimeError(
            f"payload publication rollback failed; displaced endpoint "
            f"preserved at {temporary}"
        ) from error
    if lstat_name(destination.name) != displaced_identity:
        raise RuntimeError(
            f"payload publication rollback could not verify {destination}"
        )
    if not same_snapshot(snapshot_name(temporary.name), staged_snapshot):
        raise RuntimeError(
            f"payload publication rollback lost staged data at {temporary}"
        )
    raise RuntimeError(reason)


payload_descriptor = -1
source_descriptor = -1
linked = False
try:
    reservation_snapshot = snapshot_name(destination.name)
    if (
        reservation_snapshot[0] != token
        or reservation_snapshot[1][2] != 0o600
        or reservation_snapshot[1][3] != len(token)
    ):
        raise RuntimeError(
            f"destination reservation changed before payload staging: {destination}"
        )
    try:
        snapshot_name(temporary.name)
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError(f"payload staging path already exists: {temporary}")

    payload_descriptor = os.open(
        ".",
        os.O_RDWR | os.O_CLOEXEC | os.O_TMPFILE,
        0o600,
        dir_fd=parent_descriptor,
    )
    source_descriptor = os.open(
        source, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
    )
    source_info = os.fstat(source_descriptor)
    if not stat.S_ISREG(source_info.st_mode):
        raise RuntimeError(f"payload source is not a regular file: {source}")
    digest = hashlib.sha256()
    while True:
        chunk = os.read(source_descriptor, 65536)
        if not chunk:
            break
        digest.update(chunk)
        remaining = memoryview(chunk)
        while remaining:
            written = os.write(payload_descriptor, remaining)
            if written <= 0:
                raise OSError("short write while staging payload")
            remaining = remaining[written:]
    if digest.hexdigest() != expected_payload_sha256:
        raise RuntimeError(f"payload source changed while staging: {source}")
    os.fchmod(payload_descriptor, payload_mode)
    os.fsync(payload_descriptor)
    os.lseek(payload_descriptor, 0, os.SEEK_SET)
    staged_info = os.fstat(payload_descriptor)
    staged_snapshot = (
        b"",
        (
            staged_info.st_dev,
            staged_info.st_ino,
            stat.S_IMODE(staged_info.st_mode),
            staged_info.st_size,
            staged_info.st_mtime_ns,
        ),
    )
    if staged_snapshot[1][2] != payload_mode:
        raise RuntimeError("staged payload has the wrong mode")

    linkat = ctypes.CDLL(None, use_errno=True).linkat
    linkat.argtypes = (
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
    )
    linkat.restype = ctypes.c_int
    if linkat(
        payload_descriptor,
        b"",
        parent_descriptor,
        os.fsencode(temporary.name),
        0x1000,
    ) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))
    linked = True
    os.fsync(parent_descriptor)
    staged_snapshot = snapshot_name(temporary.name)
    if (
        hashlib.sha256(staged_snapshot[0]).hexdigest()
        != expected_payload_sha256
        or staged_snapshot[1][2] != payload_mode
    ):
        raise RuntimeError("staged payload does not match its journal")
    if not same_snapshot(snapshot_name(destination.name), reservation_snapshot):
        raise RuntimeError(
            f"destination reservation changed before publication: {destination}"
        )

    # keyguide-atomic-payload-publication-observation-checked
    exchange(temporary.name, destination.name)
    os.fsync(parent_descriptor)
    # keyguide-atomic-payload-publication-exchange-durable

    try:
        published_snapshot = snapshot_name(destination.name)
    except (OSError, RuntimeError) as error:
        raise RuntimeError(
            f"published payload changed; displaced endpoint preserved at {temporary}"
        ) from error
    try:
        displaced_identity = lstat_name(temporary.name)
    except OSError as error:
        raise RuntimeError(
            f"displaced reservation is unavailable after payload publication: {temporary}"
        ) from error
    if not same_snapshot(published_snapshot, staged_snapshot):
        raise RuntimeError(
            f"published payload changed; displaced endpoint preserved at {temporary}"
        )
    try:
        displaced_snapshot = snapshot_name(temporary.name)
    except (OSError, RuntimeError):
        rollback(
            displaced_identity,
            f"destination reservation changed during publication: {destination}",
        )
    if not same_snapshot(displaced_snapshot, reservation_snapshot):
        rollback(
            displaced_identity,
            f"destination reservation changed during publication: {destination}",
        )

    os.unlink(temporary.name, dir_fd=parent_descriptor)
    linked = False
    os.fsync(parent_descriptor)
    # keyguide-atomic-payload-reservation-cleanup-durable
    if not same_snapshot(snapshot_name(destination.name), staged_snapshot):
        raise RuntimeError(f"published payload changed after commit: {destination}")
finally:
    if source_descriptor >= 0:
        os.close(source_descriptor)
    if payload_descriptor >= 0:
        os.close(payload_descriptor)
    os.close(parent_descriptor)
PY
}

keyguide_require_live_session_unlocked install

for ((owned_index = 0; owned_index < ${#owned_files[@]}; owned_index++)); do
  destination=${owned_files[owned_index]}
  source_path=${source_files[owned_index]}
  if ((owned_index == 0)); then
    payload_mode=755
  else
    payload_mode=644
  fi
  pending_reservation_payload_sha256=$(sha256sum -- "$source_path" | cut -d' ' -f1)
  [[ $pending_reservation_payload_sha256 =~ ^[0-9a-f]{64}$ ]] ||
    fail "could not hash payload source: $source_path"
  pending_reservation_payload_mode=$payload_mode
  upgrade_reservation_index=-1
  for ((index = 0; index < ${#upgrade_reservation_paths[@]}; index++)); do
    if [[ $destination == "${upgrade_reservation_paths[index]}" ]]; then
      upgrade_reservation_index=$index
      break
    fi
  done
  pending_reservation_path=$destination
  if ((upgrade_reservation_index >= 0)); then
    pending_reservation_token=${upgrade_reservation_tokens[upgrade_reservation_index]}
    pending_reservation_temporary_path=${upgrade_reservation_temporary_paths[upgrade_reservation_index]}
    write_manifest false installing "$plugin_enable_state" replace
    adopt_upgrade_reservation \
      "$destination" \
      "$pending_reservation_temporary_path" \
      "$pending_reservation_token" \
      "$target_home"
  else
    pending_reservation_token=$(python3 - <<'PY'
import secrets

print(secrets.token_hex(32))
PY
)
    pending_reservation_temporary_path="${destination%/*}/.${destination##*/}.keyguide-reservation-${pending_reservation_token}.tmp"
    write_manifest false installing "$plugin_enable_state" replace
    reserve_destination \
      "$destination" \
      "$pending_reservation_temporary_path" \
      "$pending_reservation_token" \
      "$target_home"
  fi
  publish_reserved_payload \
    "$source_path" \
    "$destination" \
    "$pending_reservation_temporary_path" \
    "$pending_reservation_token" \
    "$pending_reservation_payload_sha256" \
    "$pending_reservation_payload_mode" \
    "$target_home" ||
    fail "could not atomically publish payload: $destination"
  completed_payload_identity=$(capture_regular_endpoint_identity "$destination") ||
    fail "could not capture published payload endpoint identity: $destination"
  if [[ -n ${KEYGUIDE_TEST_HOOK_PAYLOAD_AFTER_VERIFY_BEFORE_JOURNAL:-} &&
    $destination == "$icon_dir/omarchy-keyguide.svg" &&
    ! -e ${KEYGUIDE_TEST_HOOK_PAYLOAD_AFTER_VERIFY_BEFORE_JOURNAL} ]]; then
    printf '%s\n' 'user replacement after payload verification' >"$destination"
    printf '%s\n' 'user replacement after payload verification' \
      >"${KEYGUIDE_TEST_HOOK_PAYLOAD_AFTER_VERIFY_BEFORE_JOURNAL}"
  fi
  if [[ -n ${KEYGUIDE_TEST_HOOK_PAYLOAD_AFTER_VERIFY_BEFORE_JOURNAL_SAME_BYTES:-} &&
    $destination == "$icon_dir/omarchy-keyguide.svg" &&
    ! -e ${KEYGUIDE_TEST_HOOK_PAYLOAD_AFTER_VERIFY_BEFORE_JOURNAL_SAME_BYTES} ]]; then
    replacement="${destination}.same-bytes-replacement"
    install -m "$pending_reservation_payload_mode" "$source_path" "$replacement"
    mv -f -- "$replacement" "$destination"
    touch "${KEYGUIDE_TEST_HOOK_PAYLOAD_AFTER_VERIFY_BEFORE_JOURNAL_SAME_BYTES}"
  fi
  journal_files+=("$destination")
  completed_payload_path=$destination
  completed_payload_sha256=$pending_reservation_payload_sha256
  completed_payload_mode=$pending_reservation_payload_mode
  pending_reservation_path=
  pending_reservation_token=
  pending_reservation_temporary_path=
  pending_reservation_payload_sha256=
  pending_reservation_payload_mode=
  write_manifest false installing "$plugin_enable_state" replace
  completed_payload_path=
  completed_payload_sha256=
  completed_payload_mode=
  completed_payload_identity=
done

if [[ -z $prefix_root ]]; then
  keyguide_require_live_session_unlocked install
  omarchy shell shell rescanPlugins
  if [[ $plugin_was_enabled == false ]]; then
    plugin_discovered=false
    for ((attempt = 0; attempt < 40; attempt++)); do
      plugin_catalog=$(omarchy plugin list --json)
      plugin_discovered=$(python3 -c '
import json
import sys

try:
    plugins = json.load(sys.stdin)
except (UnicodeError, ValueError) as error:
    raise SystemExit(f"invalid plugin catalog: {error}") from error
if not isinstance(plugins, list):
    raise SystemExit("plugin catalog must be a list")
print(
    "true"
    if any(
        isinstance(plugin, dict) and plugin.get("id") == "mrai.keyguide"
        for plugin in plugins
    )
    else "false"
)
' <<<"$plugin_catalog") || fail "could not inspect plugin discovery state"
      [[ $plugin_discovered == true ]] && break
      sleep 0.05
    done
    [[ $plugin_discovered == true ]] || fail "plugin mrai.keyguide was not discovered"
  fi

  if [[ $bar_placement_preexisting == false ]]; then
    bar_placement_state=placing
    write_manifest false installing "$plugin_enable_state" replace
    if [[ -n ${KEYGUIDE_TEST_HOOK_SHELL_BEFORE_BAR_PLACE:-} &&
      ! -e ${KEYGUIDE_TEST_HOOK_SHELL_BEFORE_BAR_PLACE} ]]; then
      python3 - "$shell_config" "${KEYGUIDE_TEST_HOOK_SHELL_BEFORE_BAR_PLACE}" <<'PY'
import json
from pathlib import Path
import sys

shell = Path(sys.argv[1])
marker = Path(sys.argv[2])
document = json.loads(shell.read_text(encoding="utf-8"))
document["concurrentUserEdit"] = "retained"
shell.write_text(json.dumps(document, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
marker.touch()
PY
    fi
    if [[ -n ${KEYGUIDE_TEST_HOOK_SHELL_BEFORE_BAR_PLACE_ODD_BYTES:-} &&
      ! -e ${KEYGUIDE_TEST_HOOK_SHELL_BEFORE_BAR_PLACE_ODD_BYTES} ]]; then
      python3 - "$shell_config" "${KEYGUIDE_TEST_HOOK_SHELL_BEFORE_BAR_PLACE_ODD_BYTES}" <<'PY'
from pathlib import Path
import sys

shell = Path(sys.argv[1])
marker = Path(sys.argv[2])
odd_bytes = (
    b'{\n'
    b'  "plugins" : [ "mrai.keyguide" ],\n'
    b'  "bar" : { "layout" : { "left" : [ ], "center" : [ ], '
    b'"right" : [ {"id":"omarchy.agents"} , {"id":"omarchy.bluetooth"} ] } },\n'
    b'  "concurrentUserEdit" : "retained"\n'
    b'}\n'
)
shell.write_bytes(odd_bytes)
shell.chmod(0o640)
marker.touch()
PY
    fi
    bar_shell_capture=$(capture_shell_endpoint_for_bar_put) ||
      fail "could not capture shell before Keyguide bar placement"
    rollback_failed_bar_placement() {
      local reason=$1
      if [[ -n ${bar_shell_capture:-} ]]; then
        restore_shell_capture_after_failed_bar_put "$bar_shell_capture" ||
          fail "bar rollback final endpoint verification failed"
        [[ $bar_shell_capture == - ]] || rm -f -- "$bar_shell_capture"
        bar_shell_capture=-
      fi
      fail "$reason after bar rollback"
    }
    if [[ $bar_shell_capture == - ]]; then
      bar_staging_home="$state_dir/bar-placement-home"
      bar_staging_path="$bar_staging_home/.config/omarchy/shell.json"
      prepare_absent_bar_staging_home "$bar_staging_home" "$bar_staging_path" ||
        fail "could not prepare isolated bar placement staging home"
      if [[ -n ${KEYGUIDE_TEST_HOOK_LIVE_SHELL_BEFORE_STAGED_BAR:-} &&
        ! -e ${KEYGUIDE_TEST_HOOK_LIVE_SHELL_BEFORE_STAGED_BAR} ]]; then
        python3 - \
          "$shell_config" \
          "${KEYGUIDE_TEST_HOOK_LIVE_SHELL_BEFORE_STAGED_BAR}" \
          "${KEYGUIDE_TEST_HOOK_LIVE_SHELL_BEFORE_STAGED_BAR_HEX:-}" <<'PY'
from pathlib import Path
import sys

shell = Path(sys.argv[1])
marker = Path(sys.argv[2])
replacement_hex = sys.argv[3]
if not replacement_hex:
    raise RuntimeError("missing staged bar live-shell hook bytes")
shell.parent.mkdir(parents=True, exist_ok=True)
shell.write_bytes(bytes.fromhex(replacement_hex))
marker.write_bytes(bytes.fromhex(replacement_hex))
PY
      fi
      if ! stage_absent_bar_from_default "$bar_staging_path" >/dev/null; then
        clear_staged_bar_output "$bar_staging_path" "" "" ||
          fail "could not clean failed default shell stage"
        fail "could not stage default shell bar placement"
      fi
      if ! staged_bar_post_sha256=$(validate_bar_placement_postimage "$bar_staging_path"); then
        clear_staged_bar_output "$bar_staging_path" "" "" ||
          fail "could not clean invalid staged bar output"
        fail "default shell transform did not produce a canonical anchored insertion"
      fi
      staged_bar_info=$(capture_staged_bar_output "$bar_staging_path") ||
        fail "could not authenticate staged bar output"
      IFS=$'\t' read -r bar_staging_sha256 bar_staging_mode <<<"$staged_bar_info"
      [[ $bar_staging_sha256 == "$staged_bar_post_sha256" &&
        $bar_staging_mode =~ ^[0-7]{3,4}$ ]] ||
        fail "staged bar output digest is inconsistent"
      write_manifest false installing "$plugin_enable_state" replace
      python3 - <<'PY'
# keyguide-staged-bar-output-journal-durable
PY
      keyguide_require_live_session_unlocked install
      if ! published_bar_sha256=$(
        publish_staged_absent_bar_shell \
          "$bar_staging_path" \
          "$bar_staging_sha256" \
          "$bar_staging_mode"
      ); then
        if staged_absent_bar_shell_is_published \
          "$bar_staging_path" \
          "$bar_staging_sha256" \
          "$bar_staging_mode"; then
          fail "staged bar publication interrupted after durable publication"
        fi
        clear_staged_bar_output \
          "$bar_staging_path" \
          "$bar_staging_sha256" \
          "$bar_staging_mode" ||
          fail "could not clean unpublished staged bar output"
        bar_staging_path=
        bar_staging_sha256=
        bar_staging_mode=
        shell_post_enable_sha256=
        shell_post_enable_present=false
        bar_placement_owned_by_installer=false
        bar_placement_state=not_started
        write_manifest false installing "$plugin_enable_state" replace
        fail "live shell appeared before staged bar publication"
      fi
      [[ $published_bar_sha256 == "$bar_staging_sha256" ]] ||
        fail "published staged bar output digest mismatch"
      shell_post_enable_sha256=$published_bar_sha256
      shell_post_enable_present=true
      bar_placement_owned_by_installer=true
      bar_placement_state=placed
      write_manifest false installing "$plugin_enable_state" replace
      clear_staged_bar_output \
        "$bar_staging_path" \
        "$bar_staging_sha256" \
        "$bar_staging_mode" ||
        fail "could not clean staged bar output"
      bar_staging_path=
      bar_staging_sha256=
      bar_staging_mode=
      write_manifest false installing "$plugin_enable_state" replace
    else
      keyguide_require_live_session_unlocked install
      if ! omarchy bar put mrai.keyguide --after omarchy.agents; then
        rollback_failed_bar_placement "omarchy bar put failed"
      fi
      bar_placement_status=$(shell_bar_placement_status) ||
        rollback_failed_bar_placement "could not verify Keyguide bar placement"
      if [[ $bar_placement_status == duplicate ]]; then
        rollback_failed_bar_placement "omarchy bar put did not produce a unique mrai.keyguide placement"
      fi
      [[ $bar_placement_status == anchored ]] ||
        rollback_failed_bar_placement "omarchy bar put did not place mrai.keyguide immediately after omarchy.agents"
      if ! shell_post_enable_sha256=$(validate_bar_placement_postimage); then
        rollback_failed_bar_placement "omarchy bar put did not produce a canonical anchored insertion"
      fi
      rm -f -- "$bar_shell_capture"
      bar_shell_capture=-
      shell_post_enable_present=true
      bar_placement_owned_by_installer=true
      bar_placement_state=placed
      write_manifest false installing "$plugin_enable_state" replace
    fi
  fi

  if [[ $plugin_was_enabled == false ]]; then
    plugin_enable_state=enabling
    write_manifest false installing "$plugin_enable_state" replace
    keyguide_require_live_session_unlocked install
    if ! omarchy plugin enable mrai.keyguide; then
      plugin_enable_state=enable_failed
      write_manifest false installing "$plugin_enable_state" replace
      fail "could not enable plugin mrai.keyguide"
    fi
    bar_placement_status=$(shell_bar_placement_status) ||
      fail "could not inspect post-enable Keyguide bar placement"
    if [[ $bar_placement_owned_by_installer == false &&
      $shell_preexisting == true &&
      $bar_placement_status == misplaced ]]; then
      bar_placement_state=placing
      write_manifest false installing "$plugin_enable_state" replace
      keyguide_require_live_session_unlocked install
      shell_post_enable_sha256=$(canonicalize_enable_inserted_bar_placement) ||
        fail "could not canonicalize enable-inserted Keyguide bar placement"
      shell_post_enable_present=true
      bar_placement_owned_by_installer=true
      bar_placement_state=placed
      write_manifest false installing "$plugin_enable_state" replace
    elif [[ $bar_placement_status == duplicate ]]; then
      fail "post-enable Keyguide bar placement is duplicated"
    fi
    capture_shell_postimage
    plugin_enable_state=enabled
    retain_upgrade_handoff=false
    write_manifest true installed "$plugin_enable_state" replace
  else
    retain_upgrade_handoff=false
    write_manifest false installed "$plugin_enable_state" replace
  fi
  keyguide_require_live_session_unlocked install
  omarchy restart shell
else
  retain_upgrade_handoff=false
  write_manifest false installed "$plugin_enable_state" replace
fi

echo "Installed Omarchy Keyguide in $target_home"
