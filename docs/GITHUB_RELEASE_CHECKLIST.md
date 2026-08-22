# GitHub publication checklist

This checklist prepares Omarchy Keyguide for publication. It does not authorize
or perform a GitHub push, release, live install, or Omarchy registry submission.

## Repository metadata

- Name: `omarchy-keyguide`
- English: Input-transparent shortcut HUD with safe shortcut editing for Omarchy.
- 한국어: Omarchy용 입력 비간섭 단축키 HUD와 안전한 단축키 편집기.
- 简体中文：面向 Omarchy 的输入透明快捷键 HUD 与安全快捷键编辑器。
- 日本語：Omarchy 用の入力透過ショートカット HUD と安全な編集機能。
- Suggested topics: `omarchy`, `hyprland`, `quickshell`, `wayland`,
  `keyboard-shortcuts`, `linux-desktop`
- License: MIT
- Current manifest version: `0.1.0`

## Files intended for publication

- Product documentation: `README.md`, `README.ko.md`, `README.zh-CN.md`,
  `README.ja.md`, `LICENSE`, `NOTICE`, and this checklist
- Plugin metadata: `manifest.json`, `src/plugin/manifest.json`
- Runtime source: `src/backend`, `src/observer`, `src/plugin`
- Lifecycle and packaging: `scripts`, `packaging`, `Makefile`, `.gitignore`
- Product asset: `assets/omarchy-keyguide.svg`
- Non-secret fixtures and automated tests: `tests`

## Files intentionally excluded

- `.git`, `.worktrees`, `.superpowers`, `build`, `__pycache__`
- Local state/configuration such as `.env`, `~/.config`, `~/.local`, logs,
  coverage output, temporary evidence, recovery files, and test sandboxes
- Credentials, API tokens, SSH/GPG private keys, cookies, session data, and
  machine-specific absolute paths
- Internal Codex plans, worker reports, and live-verification evidence

The tracked internal reports that contained `/home/<user>/...` and temporary
evidence paths were removed from the publication tree. They remain recoverable
from local Git history and are not product dependencies. Because deleted files
remain visible in Git history, **do not push the current development history to
the public repository**. Create the public repository from the sanitized current
tree as one new root commit, or use an equivalently reviewed squash/orphan
publication branch.

Recommended publication method after the final verification commit:

```sh
public_tree=$(mktemp -d)
git archive --format=tar HEAD | tar -xf - -C "$public_tree"
git -C "$public_tree" init -b main
git -C "$public_tree" add --all
git -C "$public_tree" commit -m "Initial public release"
```

Inspect that new repository before adding a GitHub remote. Do not copy the
working directory directly, because it also contains intentionally ignored
local reports and build output that `git archive` excludes.

## Required checks before push

```sh
make test
git diff --check
git status --short
git ls-files
git ls-files -s | awk '$1 == "120000" { print }'
```

Expected results:

- The complete test suite exits `0`.
- No whitespace errors, unexpected uncommitted files, or tracked symlinks.
- A dedicated credential/content scan returns no matches.
- Tracked files contain no machine-specific `/home/...` paths.
- The public branch starts from the sanitized tree and cannot reach the private
  development commits that previously contained internal reports.

## Omarchy registration readiness

- Root `manifest.json` uses repository-relative entry points for git-plugin mode.
- `src/plugin/manifest.json` uses installed-plugin-relative entry points.
- Plugin ID is consistently `mrai.keyguide` and `allowMultiple` is `false`.
- Settings and the HUD support English (default), Korean, Japanese, Simplified
  Chinese, and Spanish. General actions can be found by English or the selected
  language; installed applications and commands share the same live search.
- First enable builds the observer from checked-in source through
  `scripts/plugin-bootstrap.sh`; generated `build/` output is ignored.
- Source install/uninstall uses an authenticated ownership manifest and does not
  modify `/usr/share/omarchy/` or the user's `bindings.lua`.
- Replace `<github-owner>` in README installation examples after choosing the
  publishing account and creating the final repository.
- After publication, perform a disposable or review-approved live acceptance of
  `omarchy plugin add <url> --enable`, settings launch, shortcut conflict
  rejection, reset, and `omarchy plugin remove mrai.keyguide` before registry
  submission.

## Not performed in this preparation

- No GitHub repository, branch push, tag, release, issue, or pull request
- No Omarchy registry submission
- No live plugin add/remove, shell restart, Hyprland reload, or user config edit
