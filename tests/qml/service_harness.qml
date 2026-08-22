import QtQuick
import Quickshell


ShellRoot {
  id: testRoot

  property int phase: 0
  property int phaseTicks: 0
  property var service: null
  property bool localizationChecked: false
  readonly property var boundedProcessPrefix: [
    "/usr/bin/python3",
    String(Qt.resolvedUrl("src/backend/keyguide_backend/bounded_process.py")).replace("file://", "")
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
    property var availableLock: null

    function serviceFor(pluginId) {
      return pluginId === "omarchy.lock" ? availableLock : null
    }
  }

  function fail(message) {
    lockService.locked = true
    console.error("KEYGUIDE_SERVICE_TEST_FAIL: " + message)
    Qt.quit()
  }

  function advance(nextPhase) {
    phase = nextPhase
    phaseTicks = 0
  }

  function state(superPressed, actionPressed, wheelPulse) {
    return {
      super: superPressed,
      ctrl: false,
      shift: false,
      alt: false,
      actionPressed: actionPressed,
      wheelPulse: wheelPulse
    }
  }

  function superOnly(wheelPulse) {
    return state(true, false, wheelPulse)
  }

  function noModifiers(wheelPulse) {
    return state(false, false, wheelPulse)
  }

  function actionPressed(wheelPulse) {
    return state(true, true, wheelPulse)
  }

  function mouseButtonPressed(wheelPulse) {
    return state(true, true, wheelPulse)
  }

  function sendState(nextState) {
    service.acceptModifierLine(JSON.stringify(nextState))
  }

  Component.onCompleted: {
    const component = Qt.createComponent(Qt.resolvedUrl("src/plugin/Service.qml"), Component.PreferSynchronous)
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
        "/usr/bin/python3",
        "-c",
        "import sys,time; sys.stdout.write('{\"super\":tr'); sys.stdout.flush(); time.sleep(0.05); sys.stdout.write('ue,\"ctrl\":false,\"shift\":false,\"alt\":false,\"actionPressed\":false,\"wheelPulse\":0}\\n'); sys.stdout.flush(); time.sleep(30)"
      ],
      bindingsCommand: [
        "/usr/bin/printf",
        "[{\"id\":\"terminal\",\"presentation_id\":\"terminal\",\"modifiers\":[\"SUPER\"],\"key\":\"RETURN\",\"description\":\"Terminal\",\"dispatcher\":\"exec\",\"argument\":\"terminal\",\"mouse\":false,\"editable\":true,\"action_kind\":\"exec\",\"action_argument\":\"terminal\",\"edit_reason\":\"\"}]"
      ],
      settingsCommand: [
        "/usr/bin/printf",
        "{\"version\":2,\"enabled\":true,\"position\":\"center\",\"scale\":1.0,\"opacity\":0.94,\"groups\":[\"SUPER\"],\"hiddenBindingIds\":[],\"followTheme\":true,\"language\":\"en\"}"
      ],
      shortcutsStatusCommand: [
        "/usr/bin/printf",
        "{\"version\":3,\"managedCount\":0,\"managedBindingIds\":[],\"keyOptionsByGroup\":{\"SUPER\":[],\"SUPER+CTRL\":[],\"SUPER+SHIFT\":[],\"SUPER+ALT\":[],\"SUPER+CTRL+SHIFT\":[],\"SUPER+CTRL+ALT\":[],\"SUPER+SHIFT+ALT\":[],\"SUPER+CTRL+SHIFT+ALT\":[]},\"actions\":[],\"discoveryError\":\"\"}"
      ]
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
        testRoot.fail("phase " + testRoot.phase + " timed out: "
          + String(testRoot.service ? testRoot.service.lastError : "no service"))
        return
      }

      if (!testRoot.service) return

      if (testRoot.phase === 0) {
        if (!testRoot.service.locked || testRoot.service.observerRunning) {
          testRoot.fail("missing lock service did not fail closed")
          return
        }
        if (testRoot.phaseTicks < 4) return
        shellStub.availableLock = lockService
        testRoot.phase = 1
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 1 && testRoot.service.observerRunning
          && testRoot.service.modifierState.super && testRoot.service.hudVisible) {
        if (!testRoot.localizationChecked) {
          const rawBindings = [
            { id: "terminal-localized", presentation_id: "terminal-localized",
              modifiers: ["SUPER"], key: "RETURN", description: "Terminal",
              mouse: false, label_key: "action.terminal", selection_kind: "action",
              selection_id: "action:terminal", title_override: "" },
            { id: "brightness-localized", presentation_id: "brightness-localized",
              modifiers: ["SUPER"], key: "B", description: "Brightness down",
              mouse: false, label_key: "action.brightnessDown", selection_kind: "action",
              selection_id: "action:brightness", title_override: "" },
            { id: "workspace-localized", presentation_id: "workspace-localized",
              modifiers: ["SUPER"], key: "0", description: "Switch to workspace 10",
              mouse: false, label_key: "action.switchWorkspace", selection_kind: "action",
              selection_id: "action:workspace-10", title_override: "" },
            { id: "application-localized", presentation_id: "application-localized",
              modifiers: ["SUPER"], key: "D", description: "Demo App",
              mouse: false, label_key: "", selection_kind: "application",
              selection_id: "application:demo", title_override: "" },
            { id: "unknown-localized", presentation_id: "unknown-localized",
              modifiers: ["SUPER"], key: "V", description: "Vendor Tool",
              mouse: false, label_key: "vendor.unknown", selection_kind: "",
              selection_id: "", title_override: "" },
            { id: "override-localized", presentation_id: "override-localized",
              modifiers: ["SUPER"], key: "N", description: "Original name",
              mouse: false, label_key: "action.browser", selection_kind: "action",
              selection_id: "action:browser", title_override: "내 이름" }
          ]
          testRoot.service.allBindings = rawBindings
          testRoot.service.actionCatalog = {
            version: 1,
            fingerprint: "display-test",
            warnings: [],
            items: [
              { id: "application:demo", kind: "application", title: "デモアプリ" }
            ]
          }
          testRoot.service.settings = Object.assign(
            {}, testRoot.service.settings, { language: "ja" })
          if (!("displayBindings" in testRoot.service)
              || testRoot.service.displayBindings.map(function(binding) {
                return binding.description
              }).join("|") !== "ターミナル|画面の明るさを下げる|ワークスペース10に切り替え|デモアプリ|Vendor Tool|내 이름") {
            testRoot.fail("display-time binding descriptions did not follow locale precedence")
            return
          }
          if (rawBindings.map(function(binding) {
                return binding.description
              }).join("|") !== "Terminal|Brightness down|Switch to workspace 10|Demo App|Vendor Tool|Original name") {
            testRoot.fail("display-time localization mutated canonical bindings")
            return
          }
          testRoot.localizationChecked = true
        }
        testRoot.sendState(testRoot.actionPressed(0))
        testRoot.advance(2)
        return
      }

      if (testRoot.phase === 2) {
        if (!testRoot.service.hudVisible) {
          testRoot.sendState(testRoot.superOnly(0))
          testRoot.advance(3)
          return
        }
        if (testRoot.phaseTicks >= 4) {
          testRoot.fail("shortcut action did not dismiss the HUD")
        }
        return
      }

      if (testRoot.phase === 3) {
        if (testRoot.phaseTicks < 8) return
        if (testRoot.service.hudVisible) {
          testRoot.fail("HUD reappeared after shortcut action in the same Super cycle")
          return
        }
        testRoot.sendState(testRoot.noModifiers(0))
        testRoot.sendState(testRoot.superOnly(0))
        testRoot.advance(4)
        return
      }

      if (testRoot.phase === 4) {
        if (!testRoot.service.hudVisible) return
        testRoot.sendState(testRoot.superOnly(1))
        testRoot.advance(5)
        return
      }

      if (testRoot.phase === 5) {
        if (!testRoot.service.hudVisible) {
          testRoot.sendState(testRoot.superOnly(1))
          testRoot.advance(6)
          return
        }
        if (testRoot.phaseTicks >= 4) {
          testRoot.fail("wheel pulse did not dismiss the HUD")
        }
        return
      }

      if (testRoot.phase === 6) {
        if (testRoot.phaseTicks < 8) return
        if (testRoot.service.hudVisible) {
          testRoot.fail("HUD reappeared after wheel pulse in the same Super cycle")
          return
        }
        testRoot.sendState(testRoot.noModifiers(1))
        testRoot.sendState(testRoot.superOnly(1))
        testRoot.advance(7)
        return
      }

      if (testRoot.phase === 7) {
        if (!testRoot.service.hudVisible) return
        testRoot.sendState(testRoot.mouseButtonPressed(1))
        testRoot.advance(8)
        return
      }

      if (testRoot.phase === 8) {
        if (!testRoot.service.hudVisible) {
          testRoot.sendState(testRoot.superOnly(1))
          testRoot.advance(9)
          return
        }
        if (testRoot.phaseTicks >= 4) {
          testRoot.fail("mouse button did not dismiss the HUD")
        }
        return
      }

      if (testRoot.phase === 9) {
        if (testRoot.phaseTicks < 8) return
        if (testRoot.service.hudVisible) {
          testRoot.fail("HUD reappeared after mouse button in the same Super cycle")
          return
        }
        testRoot.sendState(testRoot.noModifiers(1))
        testRoot.sendState(testRoot.superOnly(1))
        testRoot.advance(10)
        return
      }

      if (testRoot.phase === 10 && testRoot.service.hudVisible) {
        lockService.locked = true
        testRoot.advance(11)
        return
      }

      if (testRoot.phase === 11 && !testRoot.service.observerRunning) {
        if (testRoot.service.hudVisible || testRoot.service.actionSuppressed) {
          testRoot.fail("HUD state remained active while locked")
          return
        }
        lockService.locked = false
        testRoot.advance(12)
        return
      }

      if (testRoot.phase === 12 && testRoot.service.observerRunning
          && testRoot.service.modifierState.super && testRoot.service.hudVisible) {
        lockService.locked = true
        testRoot.advance(13)
        return
      }

      if (testRoot.phase === 13 && !testRoot.service.observerRunning) {
        console.log("KEYGUIDE_SERVICE_TEST_PASS")
        Qt.quit()
      }
    }
  }
}
