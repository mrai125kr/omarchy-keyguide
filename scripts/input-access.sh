#!/usr/bin/env bash

set -euo pipefail
umask 022

fail() {
  echo "input-access: $*" >&2
  exit 1
}

[[ $EUID -eq 0 ]] || fail "administrator privileges are required"

project_root=$(realpath -m -- "$(dirname -- "${BASH_SOURCE[0]}")/..")
source_rule="$project_root/packaging/70-omarchy-keyguide.rules"
[[ -f $source_rule && ! -L $source_rule ]] || fail "packaged udev rule is unavailable"

target_root=${KEYGUIDE_UDEV_ROOT:-}
if [[ -n $target_root ]]; then
  [[ $target_root == /* && $target_root != / ]] ||
    fail "KEYGUIDE_UDEV_ROOT must be an absolute directory other than /"
  target_root=$(realpath -m -- "$target_root")
fi
rule_directory="$target_root/etc/udev/rules.d"
destination="$rule_directory/70-omarchy-keyguide.rules"
managed_marker='# Managed by Omarchy Keyguide. Grants the active local seat input access.'

reload_live_rules() {
  [[ -n $target_root ]] && return 0
  command -v udevadm >/dev/null 2>&1 || fail "udevadm is required"
  udevadm control --reload-rules
  udevadm trigger --action=change --subsystem-match=input
  udevadm settle
}

install_rule() {
  if [[ -e $destination || -L $destination ]]; then
    [[ -f $destination && ! -L $destination ]] ||
      fail "refusing to replace a non-regular udev rule"
    IFS= read -r first_line < "$destination" || true
    [[ ${first_line:-} == "$managed_marker" ]] ||
      fail "refusing to replace a rule not owned by Omarchy Keyguide"
  fi
  install -d -m 0755 -- "$rule_directory"
  install -m 0644 -o root -g root -- "$source_rule" "$destination"
  reload_live_rules
  echo "Installed Omarchy Keyguide input access."
}

remove_rule() {
  if [[ ! -e $destination && ! -L $destination ]]; then
    echo "Omarchy Keyguide input access is already absent."
    return 0
  fi
  [[ -f $destination && ! -L $destination ]] ||
    fail "refusing to remove a non-regular udev rule"
  cmp -s -- "$source_rule" "$destination" ||
    fail "refusing to remove a changed udev rule"
  rm -- "$destination"
  reload_live_rules
  echo "Removed Omarchy Keyguide input access."
}

case ${1:-} in
  install) install_rule ;;
  remove) remove_rule ;;
  *) fail "usage: $0 install|remove" ;;
esac
