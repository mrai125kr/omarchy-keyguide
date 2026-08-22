import QtQuick
import Quickshell

ShellRoot {
  id: testRoot

  property int phase: 0
  property int ticks: 0
  property var service: null
  property bool shortcutStatusAttemptObserved: false
  readonly property string runtimeRoot: Quickshell.env("KEYGUIDE_TEST_RUNTIME_ROOT")
  readonly property string servicePath: Quickshell.env("KEYGUIDE_TEST_SERVICE_PATH")

  Item {
    id: serviceHost
    visible: false
  }

  QtObject {
    id: lockService
    property bool locked: true
  }

  QtObject {
    id: shellStub

    function serviceFor(pluginId) {
      return pluginId === "omarchy.lock" ? lockService : null
    }
  }

  function fail(message) {
    console.error("KEYGUIDE_BACKEND_ENVIRONMENT_TEST_FAIL: " + message)
    Qt.quit()
  }

  Component.onCompleted: {
    if (!runtimeRoot || !servicePath) {
      fail("backend environment paths are missing")
      return
    }
    const component = Qt.createComponent(
      "file://" + servicePath, Component.PreferSynchronous
    )
    if (component.status !== Component.Ready) {
      fail("Service failed to load: " + component.errorString())
      return
    }
    service = component.createObject(serviceHost, {
      shell: shellStub,
      hudSource: "",
      runtimeRoot: runtimeRoot,
      settingsPath: "",
      bindingsCommand: [
        "/usr/bin/python3", "-c",
        "import keyguide_backend; print('[]')"
      ],
      settingsCommand: [
        "/usr/bin/python3", "-c",
        "import keyguide_backend; print('{\"version\":2,\"enabled\":true,\"position\":\"center\",\"scale\":1.0,\"opacity\":0.94,\"groups\":[\"SUPER\"],\"hiddenBindingIds\":[],\"followTheme\":true,\"language\":\"en\"}')"
      ],
      shortcutsStatusCommand: [
        "/usr/bin/python3", "-c",
        "import keyguide_backend; print('{\"version\":3,\"managedCount\":0,\"managedBindingIds\":[],\"keyOptionsByGroup\":{\"SUPER\":[],\"SUPER+CTRL\":[],\"SUPER+SHIFT\":[],\"SUPER+ALT\":[],\"SUPER+CTRL+SHIFT\":[],\"SUPER+CTRL+ALT\":[],\"SUPER+SHIFT+ALT\":[],\"SUPER+CTRL+SHIFT+ALT\":[]},\"actions\":[],\"discoveryError\":\"\"}')"
      ],
      settingsPatchCommandPrefix: [
        "/usr/bin/python3", "-c",
        "import keyguide_backend,json,sys; p=json.loads(sys.argv[1]); s={'version':2,'enabled':True,'position':'center','scale':1.0,'opacity':0.94,'groups':['SUPER'],'hiddenBindingIds':[],'followTheme':True,'language':'en'}; s.update(p); print(json.dumps(s))"
      ]
    })
    if (!service) fail("Service createObject returned null")
  }

  Connections {
    target: testRoot.service
    enabled: testRoot.service !== null

    function onShortcutStatusAttemptStartedChanged() {
      if (testRoot.service.shortcutStatusAttemptStarted)
        testRoot.shortcutStatusAttemptObserved = true
    }
  }

  Timer {
    interval: 25
    repeat: true
    running: true

    onTriggered: {
      testRoot.ticks += 1
      if (testRoot.ticks > 120) {
        testRoot.fail("phase " + testRoot.phase + " timed out")
        return
      }
      if (!testRoot.service) return

      if (testRoot.phase === 0
          && testRoot.service.settings.opacity === 0.94
          && testRoot.service.bindingsError === ""
          && testRoot.service.settingsError === ""
          && testRoot.shortcutStatusAttemptObserved
          && !testRoot.service.shortcutStatusAttemptActive) {
        if (testRoot.service.shortcutStatus.version !== 3
            || testRoot.service.shortcutStatusError !== "") {
          testRoot.fail("installed shortcut status did not complete with exact v2 state")
          return
        }
        if (!testRoot.service.saveSettingsPatch({ opacity: 0.57 })) {
          testRoot.fail("settings patch did not start")
          return
        }
        testRoot.phase = 1
        testRoot.ticks = 0
        return
      }

      if (testRoot.phase === 1 && !testRoot.service.settingsSaveActive) {
        if (testRoot.service.settingsSaveError) {
          testRoot.fail(testRoot.service.settingsSaveError)
          return
        }
        if (testRoot.service.settings.opacity !== 0.57) {
          testRoot.fail("settings patch result was not applied")
          return
        }
        console.log("KEYGUIDE_BACKEND_ENVIRONMENT_TEST_PASS")
        Qt.quit()
      }
    }
  }
}
