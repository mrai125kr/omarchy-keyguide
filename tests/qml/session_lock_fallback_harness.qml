import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
  id: testRoot

  property int phase: 0
  property int phaseTicks: 0
  property var service: null
  readonly property string statePath: Quickshell.env("KEYGUIDE_TEST_LOCK_STATE")
  readonly property var boundedProcessPrefix: [
    "/usr/bin/python3",
    String(Qt.resolvedUrl("src/backend/keyguide_backend/bounded_process.py")).replace("file://", "")
  ]

  Item {
    id: serviceHost
    visible: false
  }

  QtObject {
    id: isolatedShell

    function serviceFor(pluginId) {
      return null
    }
  }

  function fail(message) {
    console.error("KEYGUIDE_SESSION_LOCK_FALLBACK_TEST_FAIL: " + message)
    Qt.quit()
  }

  function advance(nextPhase) {
    phase = nextPhase
    phaseTicks = 0
  }

  function writeLockState(value, nextPhase) {
    if (stateWriter.running) {
      fail("lock-state writer overlapped")
      return
    }
    stateWriter.nextPhase = nextPhase
    stateWriter.command = [
      "/usr/bin/python3", "-c",
      "from pathlib import Path; import sys; Path(sys.argv[1]).write_text(sys.argv[2])",
      statePath, value
    ]
    stateWriter.running = true
  }

  Component.onCompleted: {
    const component = Qt.createComponent(
      Qt.resolvedUrl("src/plugin/Service.qml"), Component.PreferSynchronous)
    if (component.status !== Component.Ready) {
      fail("Service failed to load: " + component.errorString())
      return
    }
    service = component.createObject(serviceHost, {
      shell: isolatedShell,
      boundedProcessCommandPrefix: boundedProcessPrefix,
      hudSource: "",
      settingsPath: "",
      observerCommand: [
        "/usr/bin/python3", "-c",
        "import sys,time; print('{\"super\":true,\"ctrl\":false,\"shift\":false,\"alt\":false,\"actionPressed\":false,\"wheelPulse\":0}', flush=True); time.sleep(30)"
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

  Process {
    id: stateWriter
    property int nextPhase: -1

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        testRoot.fail("lock-state writer failed: " + exitCode)
        return
      }
      testRoot.advance(nextPhase)
    }
  }

  Timer {
    interval: 50
    repeat: true
    running: true

    onTriggered: {
      testRoot.phaseTicks += 1
      if (testRoot.phaseTicks > 100) {
        testRoot.fail("phase " + testRoot.phase + " timed out")
        return
      }
      if (!testRoot.service) return

      if (testRoot.phase === 0) {
        if (!testRoot.service.locked || testRoot.service.observerRunning) {
          testRoot.fail("undetermined fallback did not fail closed")
          return
        }
        if (testRoot.phaseTicks >= 4)
          testRoot.writeLockState("unlocked", 1)
        return
      }

      if (testRoot.phase === 1) {
        if (!testRoot.service.observerRunning || !testRoot.service.hudVisible)
          return
        testRoot.service.sessionLockCommand = [
          "/definitely/missing-omarchy-session-lock-probe"
        ]
        testRoot.advance(2)
        return
      }

      if (testRoot.phase === 2) {
        if (!testRoot.service.locked || testRoot.service.observerRunning)
          return
        if (testRoot.service.hudVisible
            || testRoot.service.modifierState.super !== false) {
          testRoot.fail("locking did not clear active input state")
          return
        }
        testRoot.service.sessionLockCommand = [
          "omarchy-hyprland-session-locked"
        ]
        testRoot.writeLockState("unlocked", 3)
        return
      }

      if (testRoot.phase === 3
          && testRoot.service.observerRunning
          && testRoot.service.hudVisible) {
        testRoot.writeLockState("unknown", 4)
        return
      }

      if (testRoot.phase === 4) {
        if (!testRoot.service.locked || testRoot.service.observerRunning)
          return
        testRoot.writeLockState("unlocked", 5)
        return
      }

      if (testRoot.phase === 5
          && testRoot.service.observerRunning
          && testRoot.service.hudVisible) {
        testRoot.writeLockState("locked", 6)
        return
      }

      if (testRoot.phase === 6) {
        if (!testRoot.service.locked || testRoot.service.observerRunning)
          return
        testRoot.writeLockState("unlocked", 7)
        return
      }

      if (testRoot.phase === 7
          && testRoot.service.observerRunning
          && testRoot.service.hudVisible) {
        console.log("KEYGUIDE_SESSION_LOCK_FALLBACK_TEST_PASS")
        Qt.quit()
      }
    }
  }
}
