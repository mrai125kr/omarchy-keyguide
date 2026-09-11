#!/bin/bash
set -euo pipefail

state_file=${KEYGUIDE_TEST_LOCK_STATE:?KEYGUIDE_TEST_LOCK_STATE is required}

case "$(<"$state_file")" in
  locked) exit 0 ;;
  unlocked) exit 1 ;;
  *) exit 2 ;;
esac
