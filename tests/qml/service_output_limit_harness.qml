import QtQuick
import Quickshell


ShellRoot {
  id: testRoot

  property int phase: 0
  property int phaseTicks: 0
  property var service: null
  property var runtimeService: null
  readonly property var boundedProcessPrefix: [
    "/usr/bin/python3",
    String(Qt.resolvedUrl("src/backend/keyguide_backend/bounded_process.py")).replace("file://", "")
  ]

  readonly property var validBindingsCommand: [
    "/usr/bin/printf",
    "[{\"id\":\"terminal\",\"presentation_id\":\"terminal\",\"modifiers\":[\"SUPER\"],\"key\":\"RETURN\",\"description\":\"Terminal\",\"dispatcher\":\"exec\",\"argument\":\"terminal\",\"mouse\":false,\"editable\":true,\"action_kind\":\"exec\",\"action_argument\":\"terminal\",\"edit_reason\":\"\"}]"
  ]
  readonly property var validSettingsCommand: [
    "/usr/bin/printf",
    "{\"version\":2,\"enabled\":true,\"position\":\"center\",\"scale\":1.0,\"opacity\":0.94,\"groups\":[\"SUPER\"],\"hiddenBindingIds\":[],\"followTheme\":true,\"language\":\"en\"}"
  ]
  readonly property string splitUtf8BindingsJson: "[{\"id\":\"terminal\",\"presentation_id\":\"terminal\",\"modifiers\":[\"SUPER\"],\"key\":\"RETURN\",\"description\":\"가\",\"dispatcher\":\"exec\",\"argument\":\"terminal\",\"mouse\":false,\"editable\":true,\"action_kind\":\"exec\",\"action_argument\":\"terminal\",\"edit_reason\":\"\"}]"
  readonly property var splitUtf8BindingsCommand: [
    "/usr/bin/python3", "-c",
    "import os,sys,time; data=sys.argv[1].encode(); marker='가'.encode(); index=data.index(marker); os.write(1,data[:index+1]); time.sleep(0.05); os.write(1,data[index+1:])",
    splitUtf8BindingsJson
  ]
  readonly property var validShortcutsStatusCommand: [
    "/usr/bin/printf",
    "{\"version\":3,\"managedCount\":0,\"managedBindingIds\":[],\"keyOptionsByGroup\":{\"SUPER\":[],\"SUPER+CTRL\":[],\"SUPER+SHIFT\":[],\"SUPER+ALT\":[],\"SUPER+CTRL+SHIFT\":[],\"SUPER+CTRL+ALT\":[],\"SUPER+SHIFT+ALT\":[],\"SUPER+CTRL+SHIFT+ALT\":[]},\"actions\":[],\"discoveryError\":\"\"}"
  ]
  readonly property var oversizedStdoutCommand: [
    "/usr/bin/python3", "-c",
    "import sys; sys.stdout.write('x' * (2 * 1024 * 1024)); sys.stdout.flush()"
  ]
  readonly property var oversizedStderrCommand: [
    "/usr/bin/python3", "-c",
    "import sys; sys.stderr.write('x' * (2 * 1024 * 1024)); sys.stderr.flush(); raise SystemExit(1)"
  ]

  Item {
    id: serviceHost
    visible: false
  }

  QtObject {
    id: lockService
    property bool locked: false
  }

  QtObject {
    id: shellStub

    function serviceFor(pluginId) {
      return pluginId === "omarchy.lock" ? lockService : null
    }
  }

  function fail(message) {
    lockService.locked = true
    console.error("KEYGUIDE_SERVICE_OUTPUT_LIMIT_TEST_FAIL: " + message)
    Qt.quit()
  }

  function advance(nextPhase) {
    phase = nextPhase
    phaseTicks = 0
  }

  Component.onCompleted: {
    const component = Qt.createComponent(
      Qt.resolvedUrl("src/plugin/Service.qml"), Component.PreferSynchronous)
    if (component.status !== Component.Ready) {
      fail("Service failed to load: " + component.errorString())
      return
    }
    service = component.createObject(serviceHost, {
      shell: shellStub,
      boundedProcessCommandPrefix: boundedProcessPrefix,
      hudSource: "",
      settingsPath: "",
      observerCommand: [
        "/usr/bin/python3", "-c",
        "import time; time.sleep(30)"
      ],
      bindingsCommand: validBindingsCommand,
      settingsCommand: validSettingsCommand,
      shortcutsStatusCommand: validShortcutsStatusCommand
    })
    if (!service) fail("Service createObject returned null")
  }

  Timer {
    interval: 25
    repeat: true
    running: true

    onTriggered: {
      testRoot.phaseTicks += 1
      if (testRoot.phaseTicks > 120) {
        testRoot.fail("phase " + testRoot.phase + " timed out")
        return
      }
      if (!testRoot.service) return

      if (testRoot.phase === 0
          && testRoot.service.allBindings.length === 1
          && !testRoot.service.settingsError
          && !testRoot.service.shortcutStatusError) {
        testRoot.service.bindingsCommand = testRoot.oversizedStdoutCommand
        testRoot.service.refreshBindings()
        testRoot.advance(1)
        return
      }

      if (testRoot.phase === 1 && !testRoot.service.bindingsAttemptActive) {
        if (testRoot.service.allBindings.length !== 0) {
          testRoot.fail("oversized stdout applied partial bindings")
          return
        }
        if (String(testRoot.service.bindingsError).indexOf(
              "output limit exceeded") === -1) {
          testRoot.fail("oversized stdout did not report the output limit")
          return
        }
        testRoot.service.bindingsCommand = testRoot.validBindingsCommand
        testRoot.service.refreshBindings()
        testRoot.advance(2)
        return
      }

      if (testRoot.phase === 2
          && testRoot.service.allBindings.length === 1
          && !testRoot.service.bindingsError) {
        testRoot.service.bindingsCommand = testRoot.oversizedStderrCommand
        testRoot.service.refreshBindings()
        testRoot.advance(3)
        return
      }

      if (testRoot.phase === 3 && !testRoot.service.bindingsAttemptActive) {
        if (testRoot.service.allBindings.length !== 0) {
          testRoot.fail("oversized stderr retained stale bindings")
          return
        }
        if (String(testRoot.service.bindingsError).indexOf(
              "output limit exceeded") === -1) {
          testRoot.fail("oversized stderr did not report the output limit")
          return
        }
        if (String(testRoot.service.bindingsError).length > 256) {
          testRoot.fail("oversized stderr leaked into the diagnostic")
          return
        }
        testRoot.service.bindingsCommand = testRoot.validBindingsCommand
        testRoot.service.refreshBindings()
        testRoot.advance(4)
        return
      }

      if (testRoot.phase === 4
          && testRoot.service.allBindings.length === 1
          && !testRoot.service.bindingsError) {
        testRoot.service.bindingsCommand = testRoot.splitUtf8BindingsCommand
        testRoot.service.refreshBindings()
        testRoot.advance(5)
        return
      }

      if (testRoot.phase === 5
          && testRoot.service.allBindings.length === 1
          && testRoot.service.allBindings[0].description === "가"
          && !testRoot.service.bindingsError) {
        const component = Qt.createComponent(
          Qt.resolvedUrl("src/plugin/Service.qml"), Component.PreferSynchronous)
        if (component.status !== Component.Ready) {
          testRoot.fail("runtime Service failed to load: " + component.errorString())
          return
        }
        testRoot.runtimeService = component.createObject(serviceHost, {
          shell: shellStub,
          boundedProcessCommandPrefix: boundedProcessPrefix,
          hudSource: "",
          settingsPath: ""
        })
        if (!testRoot.runtimeService) {
          testRoot.fail("runtime Service createObject returned null")
          return
        }
        testRoot.runtimeService.pluginBootstrapCommand = testRoot.oversizedStderrCommand
        testRoot.runtimeService.manifest = {
          entryPoints: { service: "src/plugin/Service.qml" },
          __sourceDir: "/tmp/keyguide-output-limit-test"
        }
        testRoot.advance(6)
        return
      }

      if (testRoot.phase === 6
          && testRoot.runtimeService
          && !testRoot.runtimeService.runtimeInitializationActive) {
        if (testRoot.runtimeService.runtimeReady) {
          testRoot.fail("oversized bootstrap stderr was treated as success")
          return
        }
        if (String(testRoot.runtimeService.runtimeInitializationError).indexOf(
              "output limit exceeded") === -1) {
          testRoot.fail("oversized bootstrap stderr did not report the output limit: "
            + String(testRoot.runtimeService.runtimeInitializationError))
          return
        }
        lockService.locked = true
        console.log("KEYGUIDE_SERVICE_OUTPUT_LIMIT_TEST_PASS")
        Qt.quit()
      }
    }
  }
}
