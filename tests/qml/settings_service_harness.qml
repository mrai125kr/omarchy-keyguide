import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
  id: testRoot

  property int phase: 0
  property int phaseTicks: 0
  property var service: null
  property string confirmedBeforeFailure: ""
  property var batchSaveResults: []
  property var batchBusyTransitions: []
  property bool batchTracking: false
  property bool batchBusyDroppedEarly: false
  property bool finalBatchConfirmed: false
  property bool staleWatcherSnapshotApplied: false
  property bool watcherReadStartedDuringSave: false
  property bool watcherRefreshDeferredDuringSave: false
  property bool releaseReadRequested: false
  property bool postBatchRefreshStarted: false
  property bool postBatchRefreshFinished: false
  property bool deferralSaveFinished: false
  property bool deferralRefreshStarted: false
  property bool deferralRefreshFinished: false
  property bool releasePatchRequested: false

  readonly property string raceHelper: Quickshell.env("KEYGUIDE_TEST_RACE_HELPER")
  readonly property string capturedMarker: Quickshell.env("KEYGUIDE_TEST_CAPTURED_MARKER")
  readonly property string releaseReadMarker: Quickshell.env("KEYGUIDE_TEST_RELEASE_READ_MARKER")
  readonly property string writeDoneMarker: Quickshell.env("KEYGUIDE_TEST_WRITE_DONE_MARKER")
  readonly property string releasePatchMarker: Quickshell.env("KEYGUIDE_TEST_RELEASE_PATCH_MARKER")
  readonly property string catalogHelper: Quickshell.env("KEYGUIDE_TEST_CATALOG_HELPER")
  readonly property string fingerprintOne: "1111111111111111111111111111111111111111111111111111111111111111"
  readonly property string fingerprintTwo: "2222222222222222222222222222222222222222222222222222222222222222"
  readonly property string fingerprintThree: "3333333333333333333333333333333333333333333333333333333333333333"
  readonly property string fingerprintFour: "4444444444444444444444444444444444444444444444444444444444444444"
  property string stableCatalog: ""

  function catalogDocument(fingerprint, title) {
    return JSON.stringify({
      version: 1,
      fingerprint: fingerprint,
      items: [{
        kind: "application", id: "application:demo.desktop",
        title: title, englishTitle: "Demo", summary: "A demo app",
        icon: "demo-icon", path: "", keywords: ["Demo", title]
      }],
      warnings: []
    })
  }

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
    console.error("KEYGUIDE_SETTINGS_SERVICE_TEST_FAIL: " + message)
    Qt.quit()
  }

  function startGenerationBatch() {
    if (!service.settingsAttemptActive) {
      fail("external patch exited before the watcher read was active")
      return
    }
    service.settingsPatchCommandPrefix = [
      "/usr/bin/python3", raceHelper, "patch", service.settingsPath
    ]
    batchTracking = true
    if (!service.patchSettings({ enabled: false })
        || !service.patchSettings({ opacity: 0.55 })
        || !service.patchSettings({ opacity: 0.63 })
        || !service.patchSettings({ language: "ja" })
        || !service.patchSettings({ followTheme: false })) {
      fail("serialized presentation patches were rejected")
      return
    }
    phase = 2
    phaseTicks = 0
  }

  function startDeferralProbe() {
    batchTracking = false
    watcherReadStartedDuringSave = false
    watcherRefreshDeferredDuringSave = false
    service.settingsCommand = [
      "python3", "-m", "keyguide_backend", "settings", "get"
    ]
    service.settingsPatchCommandPrefix = [
      "/usr/bin/python3", raceHelper, "hold-patch", service.settingsPath,
      writeDoneMarker, releasePatchMarker
    ]
    if (!service.patchSettings({ opacity: 0.71 })) {
      fail("deferral probe patch was rejected")
      return
    }
    phase = 3
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
      settingsPath: Quickshell.env("KEYGUIDE_TEST_SETTINGS_PATH"),
      observerCommand: ["/usr/bin/python3", "-c", "import time; print('{\"super\":false,\"ctrl\":false,\"shift\":false,\"alt\":false,\"actionPressed\":false,\"wheelPulse\":0}', flush=True); time.sleep(30)"],
      bindingsCommand: ["/usr/bin/printf", "[]"],
      settingsCommand: ["python3", "-m", "keyguide_backend", "settings", "get"],
      shortcutsStatusCommand: [
        "/usr/bin/printf",
        "{\"version\":3,\"managedCount\":0,\"managedBindingIds\":[],\"keyOptionsByGroup\":{\"SUPER\":[],\"SUPER+CTRL\":[],\"SUPER+SHIFT\":[],\"SUPER+ALT\":[],\"SUPER+CTRL+SHIFT\":[],\"SUPER+CTRL+ALT\":[],\"SUPER+SHIFT+ALT\":[],\"SUPER+CTRL+SHIFT+ALT\":[]},\"actions\":[],\"discoveryError\":\"\"}"
      ],
      backendEnvironment: ({
        "PYTHONPATH": Quickshell.env("KEYGUIDE_TEST_PYTHONPATH"),
        "XDG_DATA_HOME": Quickshell.env("KEYGUIDE_TEST_DATA_HOME"),
        "HOME": Quickshell.env("HOME"),
        "PYTHONDONTWRITEBYTECODE": "1"
      })
    })
    if (!service)
      fail("Service createObject returned null")
    const expectedGroups = [
      "SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT",
      "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT",
      "SUPER+SHIFT+ALT", "SUPER+CTRL+SHIFT+ALT"
    ]
    if (JSON.stringify(service.defaultSettings().groups) !== JSON.stringify(expectedGroups)) {
      fail("Service fresh defaults are not the exact canonical eight")
      return
    }
    const languagePatch = service.presentationSettingsPatch({ language: "ko" })
    if (!languagePatch || languagePatch.language !== "ko"
        || service.defaultSettings().language !== "en"
        || service.defaultSettings().version !== 2
        || "showHiddenFiles" in service.defaultSettings()) {
      fail("Service does not expose the version-2 language setting")
      return
    }
  }

  Process {
    id: externalPatchProcess
    environment: testRoot.service ? testRoot.service.backendEnvironment : ({})
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        testRoot.fail("external atomic patch failed")
        return
      }
      testRoot.startGenerationBatch()
    }
  }

  Process {
    id: releaseReadProcess
    environment: testRoot.service ? testRoot.service.backendEnvironment : ({})
    command: [
      "/usr/bin/python3", testRoot.raceHelper, "release",
      testRoot.releaseReadMarker
    ]
    onExited: function(exitCode) {
      if (exitCode !== 0)
        testRoot.fail("could not release the stale watcher read")
    }
  }

  Process {
    id: releasePatchProcess
    environment: testRoot.service ? testRoot.service.backendEnvironment : ({})
    command: [
      "/usr/bin/python3", testRoot.raceHelper, "release",
      testRoot.releasePatchMarker
    ]
    onExited: function(exitCode) {
      if (exitCode !== 0)
        testRoot.fail("could not release the held settings patch")
    }
  }

  Connections {
    target: testRoot.service
    enabled: testRoot.service !== null

    function onSettingsSaveActiveChanged() {
      if (!testRoot.batchTracking)
        return
      const transitions = testRoot.batchBusyTransitions.slice()
      transitions.push(testRoot.service.settingsSaveActive)
      testRoot.batchBusyTransitions = transitions
      if (!testRoot.service.settingsSaveActive
          && testRoot.service.settings.opacity !== 0.63) {
        testRoot.batchBusyDroppedEarly = true
      }
    }

    function onSettingsSaveFinished(success, errorMessage) {
      if (testRoot.phase === 3) {
        if (!success) {
          testRoot.fail("held settings patch failed: " + errorMessage)
          return
        }
        testRoot.deferralSaveFinished = true
        return
      }
      if (!testRoot.batchTracking)
        return
      const results = testRoot.batchSaveResults.slice()
      results.push({ success: success, errorMessage: String(errorMessage || "") })
      testRoot.batchSaveResults = results
      if (success) {
        testRoot.finalBatchConfirmed = true
        if (!testRoot.releaseReadRequested) {
          testRoot.releaseReadRequested = true
          releaseReadProcess.running = true
        }
      }
    }

    function onSettingsChanged() {
      if (testRoot.phase === 2 && testRoot.finalBatchConfirmed
          && testRoot.service.settings.opacity !== 0.63) {
        testRoot.staleWatcherSnapshotApplied = true
      }
    }

    function onSettingsAttemptActiveChanged() {
      if (testRoot.service.settingsSaveActive
          && testRoot.service.settingsAttemptActive) {
        testRoot.watcherReadStartedDuringSave = true
      }
      if (testRoot.phase === 2 && testRoot.finalBatchConfirmed) {
        if (testRoot.service.settingsAttemptActive)
          testRoot.postBatchRefreshStarted = true
        else if (testRoot.postBatchRefreshStarted)
          testRoot.postBatchRefreshFinished = true
      }
      if (testRoot.phase === 3 && testRoot.deferralSaveFinished) {
        if (testRoot.service.settingsAttemptActive)
          testRoot.deferralRefreshStarted = true
        else if (testRoot.deferralRefreshStarted)
          testRoot.deferralRefreshFinished = true
      }
    }

    function onSettingsRefreshPendingChanged() {
      if (testRoot.service.settingsSaveActive
          && testRoot.service.settingsRefreshPending) {
        testRoot.watcherRefreshDeferredDuringSave = true
        if (testRoot.phase === 3 && !testRoot.releasePatchRequested) {
          testRoot.releasePatchRequested = true
          Qt.callLater(function() { releasePatchProcess.running = true })
        }
      }
    }
  }

  Timer {
    interval: 20
    repeat: true
    running: true

    onTriggered: {
      testRoot.phaseTicks += 1
      if (testRoot.phaseTicks > 200) {
        testRoot.fail("phase " + testRoot.phase + " timed out")
        return
      }
      if (!testRoot.service)
        return
      if (testRoot.phase === 0 && testRoot.service.settings.opacity === 0.94) {
        if (!("patchSettings" in testRoot.service) || !("settingsPatchCommandPrefix" in testRoot.service)) {
          testRoot.fail("settings patch API is missing")
          return
        }
        testRoot.service.settingsCommand = [
          "/usr/bin/python3", testRoot.raceHelper, "read",
          testRoot.service.settingsPath, testRoot.capturedMarker,
          testRoot.releaseReadMarker
        ]
        if (testRoot.service.patchSettings({
          shortcut: "SUPER+X"
        })) {
          testRoot.fail("unsupported shortcut field was accepted")
          return
        }
        if (testRoot.service.settings.opacity !== 0.94) {
          testRoot.fail("rejected patch changed settings")
          return
        }
        externalPatchProcess.command = [
          "/usr/bin/python3", testRoot.raceHelper, "external-patch",
          testRoot.service.settingsPath, testRoot.capturedMarker,
          '{"opacity":0.41}'
        ]
        externalPatchProcess.running = true
        testRoot.phase = 1
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 2 && testRoot.postBatchRefreshFinished) {
        if (testRoot.batchBusyDroppedEarly) {
          testRoot.fail("settings save busy state dropped between queued writes")
          return
        }
        if (testRoot.batchSaveResults.length !== 1
            || testRoot.batchSaveResults[0].success !== true
            || testRoot.batchSaveResults[0].errorMessage !== "") {
          testRoot.fail("queued writes emitted a non-final or failed save result: "
            + JSON.stringify(testRoot.batchSaveResults))
          return
        }
        if (JSON.stringify(testRoot.batchBusyTransitions) !== "[true,false]") {
          testRoot.fail("queued writes did not remain continuously busy: "
            + JSON.stringify(testRoot.batchBusyTransitions))
          return
        }
        if (testRoot.service.settingsSaveError) {
          testRoot.fail("valid patch failed: " + testRoot.service.settingsSaveError)
          return
        }
        if (testRoot.service.settings.opacity !== 0.63
            || testRoot.service.settings.enabled !== false
            || testRoot.service.settings.language !== "ja"
            || testRoot.service.settings.followTheme !== false) {
          testRoot.fail("rapid patches lost a latest value or a distinct field")
          return
        }
        if (testRoot.service.settings.position !== "center") {
          testRoot.fail("valid patch changed an unsaved setting")
          return
        }
        if (testRoot.staleWatcherSnapshotApplied) {
          testRoot.fail("an in-flight watcher snapshot replaced confirmed settings")
          return
        }
        testRoot.startDeferralProbe()
        return
      }

      if (testRoot.phase === 3 && testRoot.deferralRefreshFinished) {
        if (testRoot.watcherReadStartedDuringSave) {
          testRoot.fail("the file watcher launched a settings read during a save")
          return
        }
        if (!testRoot.watcherRefreshDeferredDuringSave) {
          testRoot.fail("the file watcher did not coalesce a refresh during a save")
          return
        }
        if (testRoot.service.settings.opacity !== 0.71) {
          testRoot.fail("the drained watcher refresh lost the held patch")
          return
        }
        testRoot.confirmedBeforeFailure = JSON.stringify(testRoot.service.settings)
        testRoot.service.settingsPatchCommandPrefix = ["/definitely/missing/omarchy-keyguide-settings"]
        if (!testRoot.service.patchSettings({ opacity: 0.31 })) {
          testRoot.fail("failure probe patch was rejected before launch")
          return
        }
        testRoot.phase = 4
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 4 && !testRoot.service.settingsSaveActive) {
        if (JSON.stringify(testRoot.service.settings) !== testRoot.confirmedBeforeFailure) {
          testRoot.fail("failed write changed confirmed settings")
          return
        }
        if (testRoot.service.settingsSaveError === ""
            || testRoot.service.lastError.indexOf(testRoot.service.settingsSaveError) === -1) {
          testRoot.fail("write failure is not visible through the service error surface")
          return
        }
        lockService.locked = true
        testRoot.phase = 5
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 5 && !testRoot.service.observerRunning) {
        testRoot.service.settings = Object.assign(
          {}, testRoot.service.settings, { language: "ko" })
        testRoot.service.actionCatalogListCommandPrefix = [
          "/usr/bin/python3", testRoot.catalogHelper, "list",
          testRoot.catalogDocument(testRoot.fingerprintOne, "__LANG__"), "0"
        ]
        testRoot.service.actionCatalogFingerprintCommand = [
          "/usr/bin/python3", testRoot.catalogHelper, "fingerprint",
          testRoot.fingerprintOne, "0"
        ]
        testRoot.service.setActionCatalogWatching(true)
        if (testRoot.service.actionCatalogLoading !== true) {
          testRoot.fail("initial empty catalog load is not exposed as loading")
          return
        }
        testRoot.phase = 6
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 6 && !testRoot.service.actionCatalogBusy
          && testRoot.service.actionCatalogFingerprint === testRoot.fingerprintOne) {
        if (!testRoot.service.actionCatalogWatchEnabled
            || !testRoot.service.actionCatalogWatchTimerRunning
            || testRoot.service.actionCatalog.items[0].title !== "ko") {
          testRoot.fail("catalog did not load in the selected language when watching started")
          return
        }
        testRoot.stableCatalog = JSON.stringify(testRoot.service.actionCatalog)
        testRoot.service.actionCatalogListCommandPrefix = [
          "/definitely/missing/omarchy-keyguide-catalog"
        ]
        testRoot.service.actionCatalogFingerprintCommand = [
          "/usr/bin/python3", testRoot.catalogHelper, "fingerprint",
          testRoot.fingerprintOne, "0.15"
        ]
        testRoot.service.refreshActionCatalog(false)
        if (!testRoot.service.actionCatalogBusy
            || testRoot.service.actionCatalogLoading !== false) {
          testRoot.fail("background fingerprint probe is exposed as visible loading")
          return
        }
        testRoot.phase = 7
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 7 && testRoot.phaseTicks > 2
          && !testRoot.service.actionCatalogBusy) {
        if (testRoot.service.actionCatalogError
            || JSON.stringify(testRoot.service.actionCatalog) !== testRoot.stableCatalog) {
          testRoot.fail("unchanged fingerprint triggered a full catalog reload")
          return
        }
        testRoot.service.actionCatalogListCommandPrefix = [
          "/usr/bin/python3", testRoot.catalogHelper, "list",
          testRoot.catalogDocument(testRoot.fingerprintTwo, "Changed"), "0"
        ]
        testRoot.service.actionCatalogFingerprintCommand = [
          "/usr/bin/python3", testRoot.catalogHelper, "fingerprint",
          testRoot.fingerprintTwo, "0"
        ]
        testRoot.service.refreshActionCatalog(false)
        testRoot.phase = 8
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 8 && !testRoot.service.actionCatalogBusy
          && testRoot.service.actionCatalogFingerprint === testRoot.fingerprintTwo) {
        if (testRoot.service.actionCatalog.items[0].title !== "Changed") {
          testRoot.fail("changed fingerprint did not refresh the catalog")
          return
        }
        testRoot.stableCatalog = JSON.stringify(testRoot.service.actionCatalog)
        testRoot.service.actionCatalogListCommandPrefix = [
          "/usr/bin/python3", testRoot.catalogHelper, "fail"
        ]
        testRoot.service.refreshActionCatalog(true)
        testRoot.phase = 9
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 9 && !testRoot.service.actionCatalogBusy
          && testRoot.service.actionCatalogError) {
        if (JSON.stringify(testRoot.service.actionCatalog) !== testRoot.stableCatalog) {
          testRoot.fail("failed catalog command replaced the last good catalog")
          return
        }
        testRoot.service.actionCatalogListCommandPrefix = [
          "/usr/bin/python3", testRoot.catalogHelper, "malformed"
        ]
        testRoot.service.refreshActionCatalog(true)
        testRoot.phase = 10
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 10 && !testRoot.service.actionCatalogBusy
          && testRoot.service.actionCatalogError) {
        if (JSON.stringify(testRoot.service.actionCatalog) !== testRoot.stableCatalog) {
          testRoot.fail("malformed catalog response replaced the last good catalog")
          return
        }
        testRoot.service.actionCatalogListCommandPrefix = [
          "/usr/bin/python3", testRoot.catalogHelper, "list",
          testRoot.catalogDocument(testRoot.fingerprintThree, "__LANG__"), "0.15"
        ]
        testRoot.service.settings = Object.assign(
          {}, testRoot.service.settings, { language: "en" })
        testRoot.service.refreshActionCatalog(true)
        testRoot.service.settings = Object.assign(
          {}, testRoot.service.settings, { language: "ja" })
        testRoot.phase = 11
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 11 && !testRoot.service.actionCatalogBusy
          && testRoot.service.actionCatalogFingerprint === testRoot.fingerprintThree
          && testRoot.service.actionCatalog.items[0].title === "ja") {
        testRoot.stableCatalog = JSON.stringify(testRoot.service.actionCatalog)
        testRoot.service.actionCatalogListCommandPrefix = [
          "/usr/bin/python3", testRoot.catalogHelper, "list",
          testRoot.catalogDocument(testRoot.fingerprintFour, "must-not-apply"), "0.2"
        ]
        testRoot.service.refreshActionCatalog(true)
        testRoot.service.setActionCatalogWatching(false)
        testRoot.phase = 12
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 12 && testRoot.phaseTicks > 3
          && !testRoot.service.actionCatalogBusy) {
        if (testRoot.service.actionCatalogWatchTimerRunning
            || JSON.stringify(testRoot.service.actionCatalog) !== testRoot.stableCatalog) {
          testRoot.fail("closing catalog watch left work active or published a stale result")
          return
        }
        console.log("KEYGUIDE_SETTINGS_SERVICE_TEST_PASS")
        Qt.quit()
      }
    }
  }
}
