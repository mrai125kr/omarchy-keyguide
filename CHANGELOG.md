# Changelog

All notable changes to Omarchy Keyguide are documented in this file.

## [Unreleased]

### Documentation

- Clarified that active-seat `uaccess` grants the logged-in user account—not
  only the Keyguide process—read access to the selected input event nodes.

### Infrastructure

- Added read-only GitHub Actions CI for portable C, Python, shell, and safety
  checks while retaining the full Omarchy/Quickshell suite for release testing
  on a supported Omarchy host.
- Kept observer builds compatible with older Linux input headers that do not
  yet name the newest gamepad button codes.

## [0.1.1] - 2026-09-12

### Fixed

- Restored the Super-key HUD on Omarchy 4.0.3 by using Omarchy's public
  session-lock probe when cross-plugin lock-service access is unavailable.
- Kept the keyboard observer fail-closed while the session is locked, the lock
  state is unknown, or the lock probe cannot start.
- Reported the real operating-system error when no keyboard input device is
  readable, instead of displaying `errno: 0`.
- Reconciled application shortcuts by stable target identity and preserved
  correct web-app labels.

### Added

- Added an active-seat udev rule and `make install-input-access` /
  `make uninstall-input-access` commands for persistent keyboard read access.
- Added localized, actionable input-access guidance in every supported
  language.
- Added regression coverage for Omarchy's capability-scoped plugin API,
  lock/unlock transitions, indeterminate lock state, and lock-probe failures.

### Improved

- Unified shortcut discovery and presentation across the HUD, action search,
  and shortcut settings.
- Added localized action names, application icons, and consistent action,
  command, desktop-app, web-app, browser, editor, and agent badges.
- Bounded helper-process output to prevent untrusted command output from
  exhausting shell memory.
- Expanded the multilingual user guides and added the product preview.

## [0.1.0] - 2026-08-22

- Initial public release.

[Unreleased]: https://github.com/mrai125kr/omarchy-keyguide/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/mrai125kr/omarchy-keyguide/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/mrai125kr/omarchy-keyguide/releases/tag/v0.1.0
