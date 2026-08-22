#!/usr/bin/env bash

keyguide_require_live_session_unlocked() {
  local operation=$1 compositor_status lock_json lock_state
  [[ -n ${PREFIX_ROOT:-} ]] && return 0

  set +e
  omarchy-hyprland-session-locked >/dev/null 2>&1
  compositor_status=$?
  set -e
  [[ $compositor_status -eq 1 ]] || {
    printf '%s: Omarchy session lock is active or undetermined; no live changes were made; retry after unlock\n' "$operation" >&2
    return 75
  }

  lock_json=$(omarchy-shell lock status 2>/dev/null) || {
    printf '%s: Omarchy session lock is active or undetermined; no live changes were made; retry after unlock\n' "$operation" >&2
    return 75
  }
  lock_state=$(python3 -c '
import json
import sys

d = json.load(sys.stdin)
names = ("requested", "pending", "sessionLocked", "secure")
if not isinstance(d, dict) or not all(type(d.get(name)) is bool for name in names):
    raise SystemExit(1)
print("blocked" if any(d[name] for name in names) else "unlocked")
' <<<"$lock_json") || lock_state=blocked
  [[ $lock_state == unlocked ]] || {
    printf '%s: Omarchy session lock is active or undetermined; no live changes were made; retry after unlock\n' "$operation" >&2
    return 75
  }
}

keyguide_wait_live_session_unlocked() {
  local operation=$1 attempt compositor_status lock_json lock_state
  [[ -n ${PREFIX_ROOT:-} ]] && return 0

  for ((attempt = 0; attempt < 50; attempt++)); do
    set +e
    omarchy-hyprland-session-locked >/dev/null 2>&1
    compositor_status=$?
    set -e
    [[ $compositor_status -eq 1 ]] || {
      printf '%s: Omarchy session lock is active or undetermined; no live changes were made; retry after unlock\n' "$operation" >&2
      return 75
    }

    if lock_json=$(omarchy-shell lock status 2>/dev/null); then
      lock_state=$(python3 -c '
import json
import sys

d = json.load(sys.stdin)
names = ("requested", "pending", "sessionLocked", "secure")
if not isinstance(d, dict) or not all(type(d.get(name)) is bool for name in names):
    raise SystemExit(1)
print("blocked" if any(d[name] for name in names) else "unlocked")
' <<<"$lock_json") || lock_state=unavailable
      if [[ $lock_state == unlocked ]]; then
        return 0
      fi
      if [[ $lock_state == blocked ]]; then
        printf '%s: Omarchy session lock is active or undetermined; no live changes were made; retry after unlock\n' "$operation" >&2
        return 75
      fi
    fi

    if ((attempt < 49)); then
      sleep 0.1
    fi
  done

  printf '%s: Omarchy session lock is active or undetermined; no live changes were made; retry after unlock\n' "$operation" >&2
  return 75
}
