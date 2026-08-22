.PHONY: build test test-c test-qml test-static install uninstall

PYTHONPATH := src/backend
PREFIX_ROOT ?=
REMOVE_PREFERENCES ?= 0
CC ?= cc
CFLAGS ?= -std=c17 -O2 -Wall -Wextra -Wpedantic -Werror
CPPFLAGS ?=
QMLLINT ?= /usr/lib/qt6/bin/qmllint
RG ?= rg

OBSERVER_SOURCES := src/observer/keyguide-observer.c src/observer/modifier_state.c
OBSERVER_HEADERS := src/observer/modifier_state.h src/observer/input_codes.h
SHELL_SCRIPTS := $(wildcard scripts/*.sh)
QML_HARNESS_SCRIPTS := tests/qml/run_bar_widget_harness.sh tests/qml/run_plugin_runtime_harness.sh tests/qml/run_settings_installed_harness.sh tests/qml/run_settings_overlay_harness.sh tests/qml/run_settings_service_harness.sh tests/qml/run_shortcut_service_harness.sh

build: build/keyguide-observer
	python -m compileall -q src/backend

build/keyguide-observer: $(OBSERVER_SOURCES) $(OBSERVER_HEADERS)
	@mkdir -p build
	$(CC) $(CPPFLAGS) $(CFLAGS) -Isrc/observer $(OBSERVER_SOURCES) -o $@

build/test_modifier_state: tests/c/test_modifier_state.c src/observer/modifier_state.c $(OBSERVER_HEADERS)
	@mkdir -p build
	$(CC) $(CPPFLAGS) $(CFLAGS) -Isrc/observer tests/c/test_modifier_state.c src/observer/modifier_state.c -o $@

build/test_observer_capabilities: tests/c/test_observer_capabilities.c src/observer/keyguide-observer.c src/observer/modifier_state.c $(OBSERVER_HEADERS)
	@mkdir -p build
	$(CC) $(CPPFLAGS) $(CFLAGS) -Isrc/observer tests/c/test_observer_capabilities.c src/observer/modifier_state.c -o $@

test-c: build/test_modifier_state build/test_observer_capabilities
	./build/test_modifier_state
	./build/test_observer_capabilities

test-qml:
	QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/qml
	@mkdir -p build
	@harness="$$(mktemp ./qml-service-test.XXXXXX.qml)"; trap 'rm -f "$$harness"' EXIT; cp tests/qml/service_harness.qml "$$harness"; timeout 10s env QT_LOGGING_RULES='qt.qpa.services=false' quickshell --no-color -p "$$harness" > build/service-qml-test.log 2>&1 || { cat build/service-qml-test.log; exit 1; }
	@cat build/service-qml-test.log
	@rg -q 'KEYGUIDE_SERVICE_TEST_PASS' build/service-qml-test.log
	@! rg -q 'KEYGUIDE_SERVICE_TEST_FAIL' build/service-qml-test.log
	@harness="$$(mktemp ./qml-service-failure-test.XXXXXX.qml)"; trap 'rm -f "$$harness"' EXIT; cp tests/qml/service_failure_harness.qml "$$harness"; timeout 10s env QT_LOGGING_RULES='qt.qpa.services=false' quickshell --no-color -p "$$harness" > build/service-failure-qml-test.log 2>&1 || { cat build/service-failure-qml-test.log; exit 1; }
	@cat build/service-failure-qml-test.log
	@rg -q 'KEYGUIDE_SERVICE_FAILURE_TEST_PASS' build/service-failure-qml-test.log
	@! rg -q 'KEYGUIDE_SERVICE_FAILURE_TEST_FAIL' build/service-failure-qml-test.log
	@tests/qml/run_settings_service_harness.sh
	@tests/qml/run_shortcut_service_harness.sh
	@tests/qml/run_plugin_runtime_harness.sh
	@set -e; install_root="$$(mktemp -d "$$PWD/qml-backend-environment-install.XXXXXX")"; harness="$$(mktemp ./qml-backend-environment-test.XXXXXX.qml)"; runtime_root="$$install_root$$HOME/.local/lib/omarchy-keyguide"; service_path="$$install_root$$HOME/.config/omarchy/plugins/mrai.keyguide/Service.qml"; trap 'rm -rf "$$install_root"; rm -f "$$harness"' EXIT; PREFIX_ROOT="$$install_root" bash scripts/install.sh; cp tests/qml/backend_environment_harness.qml "$$harness"; timeout 10s env KEYGUIDE_TEST_RUNTIME_ROOT="$$runtime_root" KEYGUIDE_TEST_SERVICE_PATH="$$service_path" QT_LOGGING_RULES='qt.qpa.services=false' quickshell --no-color -p "$$harness" > build/backend-environment-qml-test.log 2>&1 || { cat build/backend-environment-qml-test.log; exit 1; }; cat build/backend-environment-qml-test.log; rg -q 'KEYGUIDE_BACKEND_ENVIRONMENT_TEST_PASS' build/backend-environment-qml-test.log; ! rg -q 'KEYGUIDE_BACKEND_ENVIRONMENT_TEST_FAIL' build/backend-environment-qml-test.log; test ! -e "$$runtime_root/keyguide_backend/__pycache__"; PREFIX_ROOT="$$install_root" bash scripts/uninstall.sh; test ! -e "$$runtime_root" && test ! -L "$$runtime_root"
	@test ! -e Commons && test ! -L Commons && test ! -e Ui && test ! -L Ui
	@tests/qml/run_settings_overlay_harness.sh
	@test ! -e Commons && test ! -L Commons && test ! -e Ui && test ! -L Ui
	@tests/qml/run_settings_installed_harness.sh
	@test ! -e Commons && test ! -L Commons && test ! -e Ui && test ! -L Ui
	@tests/qml/run_bar_widget_harness.sh
	@test ! -e Commons && test ! -L Commons && test ! -e Ui && test ! -L Ui
	@harness="$$(mktemp ./qml-hud-test.XXXXXX.qml)"; trap 'rm -f "$$harness" Commons Ui' EXIT; ln -s /usr/share/omarchy/shell/Commons Commons; ln -s /usr/share/omarchy/shell/Ui Ui; cp tests/qml/hud_harness.qml "$$harness"; timeout 10s env QT_LOGGING_RULES='qt.qpa.services=false' quickshell --no-color -p "$$harness" > build/hud-qml-test.log 2>&1 || { cat build/hud-qml-test.log; exit 1; }
	@cat build/hud-qml-test.log
	@rg -q 'KEYGUIDE_HUD_TEST_PASS' build/hud-qml-test.log
	@! rg -q 'KEYGUIDE_HUD_TEST_FAIL' build/hud-qml-test.log
	@test "$$(rg -c '^\s*WlrLayershell\.keyboardFocus:' src/plugin/Hud.qml)" -eq 1
	@rg -q '^\s*WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None\s*$$' src/plugin/Hud.qml
	@rg -q '^\s*mask:\s*Region \{\}\s*$$' src/plugin/Hud.qml
	@! rg 'MouseArea|TapHandler|HoverHandler|DragHandler|WheelHandler|PointerHandler|MultiPointTouchArea|Keys\.|Shortcut|FocusScope|forceActiveFocus|activeFocusOnTab:\s*true|focus:\s*true|keyboardFocus:.*(OnDemand|Exclusive)' src/plugin/Hud.qml

test-static:
	@command -v "$(QMLLINT)" >/dev/null 2>&1 || { printf 'error: qmllint not found: %s\n' "$(QMLLINT)" >&2; exit 127; }
	$(QMLLINT) src/plugin/*.qml src/plugin/components/*.qml
	@test -n "$(SHELL_SCRIPTS)" || { printf 'error: no shell scripts found under scripts/\n' >&2; exit 1; }
	bash -n $(SHELL_SCRIPTS) $(QML_HARNESS_SCRIPTS)
	@test "$$(find $(QML_HARNESS_SCRIPTS) -maxdepth 0 -type f -perm -u+x | wc -l)" -eq 6
	@command -v "$(RG)" >/dev/null 2>&1 || { printf 'error: ripgrep not found: %s\n' "$(RG)" >&2; exit 127; }
	@matches="$$($(RG) -n 'EVIOCGRAB|/dev/uinput' src scripts)"; status=$$?; \
	if test $$status -eq 0; then \
		printf 'error: input grabbing or synthesis is prohibited:\n%s\n' "$$matches" >&2; exit 1; \
	elif test $$status -ne 1; then \
		printf 'error: source scan failed with status %s\n' "$$status" >&2; exit "$$status"; \
	fi
	@matches="$$($(RG) -n 'bindings\.lua' src scripts)"; status=$$?; \
	if test $$status -eq 0; then \
		printf 'error: direct user bindings file access is prohibited:\n%s\n' "$$matches" >&2; exit 1; \
	elif test $$status -ne 1; then \
		printf 'error: source scan failed with status %s\n' "$$status" >&2; exit "$$status"; \
	fi
	@! $(RG) -n 'Components\.ExecutablePicker|filePicker|assignmentExecutable|showHiddenFiles|Browse…' src/plugin/Settings.qml
	@test "$$($(RG) -l '"version": "0\.1\.0"' manifest.json src/plugin/manifest.json | wc -l)" -eq 2

test: build test-c test-qml test-static
	PYTHONPATH=$(PYTHONPATH) python -m unittest discover -s tests/python -v

install: build
	PREFIX_ROOT="$(PREFIX_ROOT)" bash scripts/install.sh

uninstall:
	PREFIX_ROOT="$(PREFIX_ROOT)" REMOVE_PREFERENCES="$(REMOVE_PREFERENCES)" bash scripts/uninstall.sh
