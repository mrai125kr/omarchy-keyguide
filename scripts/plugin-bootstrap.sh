#!/usr/bin/env bash

set -euo pipefail
umask 077

fail() {
  echo "plugin-bootstrap: $*" >&2
  exit 1
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repository_root=$(cd -- "$script_dir/.." && pwd -P)
manifest_path="$repository_root/manifest.json"
build_dir="$repository_root/build"
observer_path="$build_dir/keyguide-observer"
stamp_path="$build_dir/plugin-runtime.sha256"

[[ -f $manifest_path && ! -L $manifest_path ]] ||
  fail "repository manifest is unavailable"
jq -e '
  .schemaVersion == 1
  and .id == "mrai.keyguide"
  and .entryPoints.service == "src/plugin/Service.qml"
' "$manifest_path" >/dev/null || fail "repository manifest does not describe Keyguide"
command -v cc >/dev/null 2>&1 ||
  fail "a C compiler is required; install base-devel or use make install"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"

if [[ -e $build_dir || -L $build_dir ]]; then
  [[ -d $build_dir && ! -L $build_dir ]] ||
    fail "build path is not a regular directory"
else
  mkdir -m 700 -- "$build_dir"
fi
[[ $(stat -c '%u' -- "$build_dir") == "$(id -u)" ]] ||
  fail "build directory is not owned by the current user"
chmod 700 -- "$build_dir"

sources=(
  "$repository_root/src/observer/keyguide-observer.c"
  "$repository_root/src/observer/modifier_state.c"
  "$repository_root/src/observer/modifier_state.h"
  "$repository_root/src/observer/input_codes.h"
)
for source_path in "${sources[@]}"; do
  [[ -f $source_path && ! -L $source_path ]] ||
    fail "observer source is unavailable: $source_path"
done

source_fingerprint() {
  {
    printf '%s\n' 'keyguide-plugin-runtime-v1' \
      '-std=c17 -O2 -Wall -Wextra -Wpedantic -Werror'
    cc --version | head -n 1
    sha256sum -- "${sources[@]}"
  } | sha256sum | cut -d ' ' -f 1
}

fingerprint=$(source_fingerprint)
if [[ -e $observer_path || -L $observer_path ]]; then
  [[ -f $observer_path && ! -L $observer_path ]] ||
    fail "observer build path is not a regular file"
  [[ $(stat -c '%u' -- "$observer_path") == "$(id -u)" ]] ||
    fail "observer build is not owned by the current user"
fi
if [[ -e $stamp_path || -L $stamp_path ]]; then
  [[ -f $stamp_path && ! -L $stamp_path ]] ||
    fail "runtime stamp path is not a regular file"
  [[ $(stat -c '%u' -- "$stamp_path") == "$(id -u)" ]] ||
    fail "runtime stamp is not owned by the current user"
fi

if [[ -x $observer_path && -f $stamp_path ]] &&
  [[ $(<"$stamp_path") == "$fingerprint" ]]; then
  exit 0
fi

candidate=$(mktemp --tmpdir="$build_dir" .keyguide-observer.XXXXXXXX)
stamp_candidate=$(mktemp --tmpdir="$build_dir" .plugin-runtime.XXXXXXXX)
cleanup() {
  rm -f -- "$candidate" "$stamp_candidate"
}
trap cleanup EXIT

cc -std=c17 -O2 -Wall -Wextra -Wpedantic -Werror \
  -I"$repository_root/src/observer" \
  "$repository_root/src/observer/keyguide-observer.c" \
  "$repository_root/src/observer/modifier_state.c" \
  -o "$candidate"
[[ $(source_fingerprint) == "$fingerprint" ]] ||
  fail "observer source changed while it was being compiled"
chmod 700 -- "$candidate"
printf '%s\n' "$fingerprint" > "$stamp_candidate"
chmod 600 -- "$stamp_candidate"
mv -f -- "$candidate" "$observer_path"
candidate=
mv -f -- "$stamp_candidate" "$stamp_path"
stamp_candidate=
