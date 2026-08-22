import QtQuick
import Quickshell


ShellRoot {
  id: testRoot

  property int phase: 0
  property int phaseTicks: 0
  property var service: null
  property string expectedError: ""

  readonly property var validBindingsCommand: [
    "/usr/bin/printf",
    "[{\"id\":\"terminal\",\"presentation_id\":\"terminal\",\"modifiers\":[\"SUPER\"],\"key\":\"RETURN\",\"description\":\"Terminal\",\"dispatcher\":\"exec\",\"argument\":\"terminal\",\"mouse\":false,\"editable\":true,\"action_kind\":\"exec\",\"action_argument\":\"terminal\",\"edit_reason\":\"\"}]"
  ]
  readonly property var validSettingsCommand: [
    "/usr/bin/printf",
    "{\"version\":2,\"enabled\":true,\"position\":\"center\",\"scale\":1.0,\"opacity\":0.94,\"groups\":[\"SUPER\"],\"hiddenBindingIds\":[],\"followTheme\":true,\"language\":\"en\"}"
  ]
  readonly property var validShortcutsStatusCommand: [
    "/usr/bin/printf",
    "{\"version\":3,\"managedCount\":0,\"managedBindingIds\":[],\"keyOptionsByGroup\":{\"SUPER\":[],\"SUPER+CTRL\":[],\"SUPER+SHIFT\":[],\"SUPER+ALT\":[],\"SUPER+CTRL+SHIFT\":[],\"SUPER+CTRL+ALT\":[],\"SUPER+SHIFT+ALT\":[],\"SUPER+CTRL+SHIFT+ALT\":[]},\"actions\":[],\"discoveryError\":\"\"}"
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
    console.error("KEYGUIDE_SERVICE_FAILURE_TEST_FAIL: " + message)
    Qt.quit()
  }

  function advance(nextPhase) {
    phase = nextPhase
    phaseTicks = 0
  }

  Component.onCompleted: {
    const component = Qt.createComponent(Qt.resolvedUrl("src/plugin/Service.qml"), Component.PreferSynchronous)
    if (component.status !== Component.Ready) {
      fail("Service failed to load: " + component.errorString())
      return
    }
    service = component.createObject(serviceHost, {
      shell: shellStub,
      hudSource: "",
      settingsPath: "",
      observerCommand: [
        "/usr/bin/python3",
        "-c",
        "import sys,time; print('{\"super\":true,\"ctrl\":false,\"shift\":false,\"alt\":false,\"actionPressed\":false,\"wheelPulse\":0}', flush=True); time.sleep(30)"
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
      if (testRoot.phaseTicks > 80) {
        testRoot.fail("phase " + testRoot.phase + " timed out")
        return
      }
      if (!testRoot.service) return

      if (testRoot.phase === 0 && testRoot.service.hudVisible
          && testRoot.service.allBindings.length === 1) {
        testRoot.service.bindingsCommand = ["/definitely/missing/omarchy-keyguide-bindings"]
        testRoot.service.refreshBindings()
        testRoot.service.refreshBindings()
        testRoot.advance(1)
        return
      }

      if (testRoot.phase === 1) {
        if (testRoot.phaseTicks < 8) return
        if (testRoot.service.allBindings.length !== 0) {
          testRoot.fail("failed binding start retained stale runtime bindings")
          return
        }
        if (testRoot.service.hudVisible) {
          testRoot.fail("HUD remained visible after binding command failed to start")
          return
        }
        if (testRoot.service.bindingsRefreshPending) {
          testRoot.fail("binding refresh remained pending after failed start")
          return
        }
        if (String(testRoot.service.lastError).indexOf("bindings") === -1) {
          testRoot.fail("binding failed start did not publish a binding diagnostic")
          return
        }
        if (!testRoot.service.bindingsError || testRoot.service.settingsError) {
          testRoot.fail("binding failed start did not isolate its source diagnostic")
          return
        }
        testRoot.expectedError = String(testRoot.service.lastError)
        testRoot.service.refreshSettings()
        testRoot.advance(2)
        return
      }

      if (testRoot.phase === 2) {
        if (testRoot.phaseTicks < 8) return
        if (String(testRoot.service.lastError) !== testRoot.expectedError) {
          testRoot.fail("settings success erased the active binding diagnostic")
          return
        }
        if (String(testRoot.service.bindingsError) !== testRoot.expectedError) {
          testRoot.fail("settings success changed the binding source diagnostic")
          return
        }
        testRoot.service.bindingsCommand = testRoot.validBindingsCommand
        testRoot.service.refreshBindings()
        testRoot.advance(3)
        return
      }

      if (testRoot.phase === 3 && testRoot.service.allBindings.length === 1) {
        if (String(testRoot.service.lastError).indexOf("bindings") !== -1) {
          testRoot.fail("binding success did not clear its own diagnostic")
          return
        }
        testRoot.service.settingsCommand = ["/definitely/missing/omarchy-keyguide-settings"]
        testRoot.service.refreshSettings()
        testRoot.service.refreshSettings()
        testRoot.advance(4)
        return
      }

      if (testRoot.phase === 4) {
        if (testRoot.phaseTicks < 8) return
        if (testRoot.service.settingsRefreshPending) {
          testRoot.fail("settings refresh remained pending after failed start")
          return
        }
        if (String(testRoot.service.lastError).indexOf("settings") === -1) {
          testRoot.fail("settings failed start did not publish a settings diagnostic")
          return
        }
        if (!testRoot.service.settingsError || testRoot.service.bindingsError) {
          testRoot.fail("settings failed start did not isolate its source diagnostic")
          return
        }
        testRoot.expectedError = String(testRoot.service.lastError)
        testRoot.service.refreshBindings()
        testRoot.advance(5)
        return
      }

      if (testRoot.phase === 5) {
        if (testRoot.phaseTicks < 8) return
        if (String(testRoot.service.lastError) !== testRoot.expectedError) {
          testRoot.fail("binding success erased the active settings diagnostic")
          return
        }
        testRoot.service.settingsCommand = testRoot.validSettingsCommand
        testRoot.service.refreshSettings()
        testRoot.advance(6)
        return
      }

      if (testRoot.phase === 6 && !testRoot.service.settingsError) {
        testRoot.service.acceptModifierLine(
          "{\"super\":true,\"ctrl\":false,\"shift\":false,\"alt\":false,\"actionPressed\":true,\"wheelPulse\":0}"
        )
        if (!testRoot.service.modifierState.actionPressed) {
          testRoot.fail("valid action state was not accepted")
          return
        }
        testRoot.service.acceptModifierLine(
          "{\"super\":true,\"ctrl\":false,\"shift\":false,\"alt\":false}"
        )
        if (!testRoot.service.observerError
            || testRoot.service.modifierState.super
            || testRoot.service.modifierState.actionPressed) {
          testRoot.fail("missing action protocol fields did not fail closed")
          return
        }
        testRoot.service.acceptModifierLine("not-json")
        if (!testRoot.service.observerError) {
          testRoot.fail("invalid observer state did not set its source diagnostic")
          return
        }
        testRoot.expectedError = String(testRoot.service.observerError)
        testRoot.service.refreshBindings()
        testRoot.advance(7)
        return
      }

      if (testRoot.phase === 7) {
        if (testRoot.phaseTicks < 8) return
        if (String(testRoot.service.lastError) !== testRoot.expectedError
            || String(testRoot.service.observerError) !== testRoot.expectedError) {
          testRoot.fail("binding success erased the active observer diagnostic")
          return
        }
        testRoot.service.acceptModifierLine(
          "{\"super\":true,\"ctrl\":false,\"shift\":false,\"alt\":false,\"actionPressed\":false,\"wheelPulse\":0}"
        )
        if (testRoot.service.observerError || testRoot.service.lastError) {
          testRoot.fail("observer success did not clear only its own diagnostic")
          return
        }
        lockService.locked = true
        testRoot.advance(8)
        return
      }

      if (testRoot.phase === 8 && !testRoot.service.observerRunning) {
        console.log("KEYGUIDE_SERVICE_FAILURE_TEST_PASS")
        Qt.quit()
      }
    }
  }
}
