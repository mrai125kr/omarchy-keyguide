import QtQuick
import Quickshell

ShellRoot {
  id: testRoot

  property var service: null
  property int ticks: 0
  property bool shortcutStatusAttemptObserved: false
  property bool catalogWatchStarted: false
  readonly property string repositoryRoot: Quickshell.env("KEYGUIDE_TEST_REPOSITORY_ROOT")

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
    console.error("KEYGUIDE_PLUGIN_RUNTIME_TEST_FAIL: " + message)
    Qt.quit()
  }

  Component.onCompleted: {
    if (!repositoryRoot) {
      fail("repository root is missing")
      return
    }
    const component = Qt.createComponent(
      "file://" + repositoryRoot + "/src/plugin/Service.qml",
      Component.PreferSynchronous
    )
    if (component.status !== Component.Ready) {
      fail("Service failed to load: " + component.errorString())
      return
    }
    service = component.createObject(serviceHost, {
      shell: shellStub,
      manifest: {
        "id": "mrai.keyguide",
        "__sourceDir": repositoryRoot,
        "entryPoints": { "service": "src/plugin/Service.qml" }
      },
      hudSource: "",
      settingsPath: "",
      pluginBootstrapCommand: ["/usr/bin/true"],
      bindingsCommand: [
        "/usr/bin/printf",
        "[{\"id\":\"demo-app\",\"presentation_id\":\"demo-app\",\"modifiers\":[\"SUPER\"],\"key\":\"D\",\"description\":\"Demo App\",\"dispatcher\":\"exec\",\"argument\":\"gtk-launch demo.desktop\",\"mouse\":false,\"editable\":true,\"action_kind\":\"exec\",\"action_argument\":\"gtk-launch demo.desktop\",\"edit_reason\":\"\",\"selection_kind\":\"application\",\"selection_id\":\"application:demo.desktop\",\"label_key\":\"\",\"title_override\":\"\"}]"
      ],
      settingsCommand: [
        "/usr/bin/printf",
        "{\"version\":2,\"enabled\":true,\"position\":\"center\",\"scale\":1.0,\"opacity\":0.94,\"groups\":[\"SUPER\"],\"hiddenBindingIds\":[],\"followTheme\":true,\"language\":\"ja\"}"
      ],
      shortcutsStatusCommand: [
        "/usr/bin/printf",
        "{\"version\":3,\"managedCount\":0,\"managedBindingIds\":[],\"keyOptionsByGroup\":{\"SUPER\":[],\"SUPER+CTRL\":[],\"SUPER+SHIFT\":[],\"SUPER+ALT\":[],\"SUPER+CTRL+SHIFT\":[],\"SUPER+CTRL+ALT\":[],\"SUPER+SHIFT+ALT\":[],\"SUPER+CTRL+SHIFT+ALT\":[]},\"actions\":[],\"discoveryError\":\"\"}"
      ],
      actionCatalogListCommandPrefix: [
        "/usr/bin/printf",
        "{\"version\":1,\"fingerprint\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"items\":[{\"kind\":\"application\",\"id\":\"application:demo.desktop\",\"title\":\"デモアプリ\",\"englishTitle\":\"Demo App\",\"summary\":\"\",\"icon\":\"demo\",\"path\":\"\",\"keywords\":[\"Demo App\",\"デモアプリ\"]}],\"warnings\":[]}"
      ],
      actionCatalogFingerprintCommand: [
        "/usr/bin/printf",
        "{\"version\":1,\"fingerprint\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}"
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
        testRoot.fail("repository runtime initialization timed out")
        return
      }
      if (!testRoot.service || !testRoot.service.runtimeReady
          || !testRoot.shortcutStatusAttemptObserved
          || testRoot.service.shortcutStatusAttemptActive) return
      if (!testRoot.catalogWatchStarted) {
        testRoot.catalogWatchStarted = true
        testRoot.service.setActionCatalogWatching(true)
        return
      }
      if (testRoot.service.actionCatalogBusy
          || testRoot.service.actionCatalogFingerprint === "") return
      if (testRoot.service.runtimeRoot !== testRoot.repositoryRoot + "/src/backend") {
        testRoot.fail("repository backend root was not selected")
        return
      }
      if (testRoot.service.observerCommand[0]
          !== testRoot.repositoryRoot + "/build/keyguide-observer") {
        testRoot.fail("repository observer was not selected")
        return
      }
      if (testRoot.service.runtimeInitializationError !== "") {
        testRoot.fail(testRoot.service.runtimeInitializationError)
        return
      }
      if (testRoot.service.shortcutStatus.version !== 3
          || testRoot.service.shortcutStatusError !== "") {
        testRoot.fail("repository shortcut status did not complete with exact v2 state")
        return
      }
      if (testRoot.service.settings.version !== 2
          || testRoot.service.settings.language !== "ja"
          || testRoot.service.allBindings.length !== 1
          || testRoot.service.allBindings[0].selection_kind !== "application"
          || testRoot.service.displayBindings.length !== 1
          || testRoot.service.displayBindings[0].description !== "デモアプリ") {
        testRoot.fail("repository runtime did not integrate v2 settings, semantic bindings, and catalog display")
        return
      }
      testRoot.service.setActionCatalogWatching(false)
      if (testRoot.service.actionCatalogWatchTimerRunning) {
        testRoot.fail("repository runtime left catalog polling active after close")
        return
      }
      console.log("KEYGUIDE_PLUGIN_RUNTIME_TEST_PASS")
      Qt.quit()
    }
  }
}
