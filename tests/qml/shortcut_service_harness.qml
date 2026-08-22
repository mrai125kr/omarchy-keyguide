import QtQuick
import Quickshell

ShellRoot {
  id: testRoot

  property int phase: 0
  property int phaseTicks: 0
  property var service: null
  readonly property var boundedProcessPrefix: [
    "/usr/bin/python3",
    String(Qt.resolvedUrl("src/backend/keyguide_backend/bounded_process.py")).replace("file://", "")
  ]
  property var results: []
  property string stableShortcutStatus: ""
  property string stableBindings: ""
  property string stableSettings: ""
  property int bindingsRefreshStarts: 0
  property int statusRefreshStarts: 0
  property int settingsRefreshStarts: 0
  property int successfulAssignmentBindingsBaseline: 0
  property int successfulAssignmentStatusBaseline: 0
  property int mutationDeferredBindingsBaseline: 0
  property int mutationDeferredSettingsBaseline: 0
  property int noncanonicalBindingsBaseline: 0
  property int noncanonicalStatusBaseline: 0
  property int acknowledgementBindingsBaseline: 0
  property int acknowledgementStatusBaseline: 0
  property int resetAcknowledgementSettingsBaseline: 0
  readonly property string helper: Quickshell.env("KEYGUIDE_TEST_SHORTCUT_HELPER")

  Item { id: serviceHost; visible: false }
  QtObject { id: lockService; property bool locked: false }
  QtObject {
    id: shellStub
    function serviceFor(pluginId) { return pluginId === "omarchy.lock" ? lockService : null }
  }

  function fail(message) {
    lockService.locked = true
    console.error("KEYGUIDE_SHORTCUT_SERVICE_TEST_FAIL: " + message)
    Qt.quit()
  }

  function assignmentRequest() {
    return {
      targetModifiers: ["SUPER"], targetKey: "N",
      selectionKind: "command",
      selectionId: "command:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      titleOverride: "My Notes", customArguments: "",
      targetBindingId: "", confirmReplace: false
    }
  }

  function removeRequest() {
    return {
      targetModifiers: ["SUPER"], targetKey: "N",
      targetBindingId: "binding-notes", title: "Notes",
      dispatcher: "exec", argument: "/usr/bin/true", confirmRemove: true
    }
  }

  function statusDocument(count) {
    const groups = ["SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT",
      "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT", "SUPER+SHIFT+ALT", "SUPER+CTRL+SHIFT+ALT"]
    const keyOptionsByGroup = {}
    for (const group of groups) keyOptionsByGroup[group] = []
    keyOptionsByGroup.SUPER = [{
      key: "N", state: count ? "assigned" : "free", title: count ? "Notes" : "",
      bindingId: count ? "binding-notes" : "", actionId: count ? "action-notes" : "",
      presentationId: count ? "presentation-notes" : "",
      editable: true, editReason: "",
      removable: count !== 0,
      removeReason: count ? "" : "No shortcut assigned"
    }]
    return {
      version: 3, managedCount: count,
      managedBindingIds: count ? ["binding-notes"] : [],
      keyOptionsByGroup: keyOptionsByGroup,
      actions: count ? [{
        id: "action-notes", title: "Notes", labelKey: "", selectionKind: "command",
        selectionId: "command:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        titleOverride: "My Notes", actionKind: "exec", launchKind: "webapp",
        modifiers: ["SUPER"], key: "N"
      }] : [],
      discoveryError: ""
    }
  }

  function bindingsDocument(count) {
    return count ? [
      { id: "binding-notes", presentation_id: "presentation-notes", modifiers: ["SUPER"], key: "N", description: "Notes",
        dispatcher: "exec", argument: "/usr/bin/true", mouse: false, editable: true,
        action_kind: "exec", action_argument: "/usr/bin/true", edit_reason: "",
        selection_kind: "command", selection_id: "command:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        label_key: "", title_override: "My Notes" },
      { id: "binding-ctrl", presentation_id: "presentation-ctrl", modifiers: ["CTRL"], key: "C", description: "Copy",
        dispatcher: "exec", argument: "copy", mouse: false, editable: true,
        action_kind: "exec", action_argument: "copy", edit_reason: "",
        selection_kind: "", selection_id: "", label_key: "", title_override: "" },
      { id: "binding-alt", presentation_id: "presentation-alt", modifiers: ["ALT"], key: "TAB", description: "Switch",
        dispatcher: "exec", argument: "switch", mouse: false, editable: true,
        action_kind: "exec", action_argument: "switch", edit_reason: "",
        selection_kind: "", selection_id: "", label_key: "", title_override: "" },
      { id: "binding-plain", presentation_id: "presentation-plain", modifiers: [], key: "F1", description: "Help",
        dispatcher: "exec", argument: "help", mouse: false, editable: true,
        action_kind: "exec", action_argument: "help", edit_reason: "",
        selection_kind: "", selection_id: "", label_key: "", title_override: "" }
    ] : []
  }

  Component.onCompleted: {
    const component = Qt.createComponent(Qt.resolvedUrl("src/plugin/Service.qml"), Component.PreferSynchronous)
    if (component.status !== Component.Ready) {
      fail("Service failed to load: " + component.errorString())
      return
    }
    service = component.createObject(serviceHost, {
      shell: shellStub, hudSource: "", settingsPath: "",
      boundedProcessCommandPrefix: boundedProcessPrefix,
      observerCommand: ["/usr/bin/python3", "-c", "import time; time.sleep(30)"],
      bindingsCommand: ["/usr/bin/printf", "[]"],
      settingsCommand: ["/usr/bin/printf", "{\"version\":2,\"enabled\":false,\"position\":\"top\",\"scale\":1.2,\"opacity\":0.7,\"groups\":[\"SUPER\"],\"hiddenBindingIds\":[],\"followTheme\":false,\"language\":\"en\"}"],
      shortcutsStatusCommand: ["/usr/bin/python3", helper, "status"],
      shortcutsMutationCommandPrefix: ["/usr/bin/python3", helper]
    })
    if (!service) fail("Service createObject returned null")
  }

  Connections {
    target: testRoot.service
    enabled: testRoot.service !== null

    function onShortcutMutationFinished(success, errorMessage, operation) {
      if (!success && operation === "reset-all"
          && (JSON.stringify(testRoot.service.shortcutStatus) !== testRoot.stableShortcutStatus
              || JSON.stringify(testRoot.service.settings) !== testRoot.stableSettings)) {
        testRoot.fail("malformed reset-all response partially changed client state")
        return
      }
      if (success && operation === "assign"
          && (testRoot.service.shortcutStatus.version !== 3
              || testRoot.service.allBindings.length !== 4
              || testRoot.service.allBindings.map(function(binding) {
                return binding.modifiers.join("+")
              }).join(",") !== "SUPER,CTRL,ALT,")) {
        testRoot.fail("assign completion fired before both response documents were installed")
        return
      }
      if (success && operation === "assign")
        testRoot.service.bindingsCommand = ["/usr/bin/printf", JSON.stringify(testRoot.bindingsDocument(1))]
      const next = testRoot.results.slice()
      next.push({ success: success, errorMessage: String(errorMessage || ""), operation: String(operation || "") })
      testRoot.results = next
    }

    function onBindingsAttemptActiveChanged() {
      if (testRoot.service.bindingsAttemptActive)
        testRoot.bindingsRefreshStarts += 1
    }

    function onShortcutStatusAttemptActiveChanged() {
      if (testRoot.service.shortcutStatusAttemptActive)
        testRoot.statusRefreshStarts += 1
    }

    function onSettingsAttemptActiveChanged() {
      if (testRoot.service.settingsAttemptActive)
        testRoot.settingsRefreshStarts += 1
    }
  }

  Timer {
    interval: 20
    repeat: true
    running: true

    onTriggered: {
      testRoot.phaseTicks += 1
      if (testRoot.phaseTicks > 120) {
        testRoot.fail("phase " + testRoot.phase + " timed out")
        return
      }
      if (!testRoot.service) return

      if (testRoot.phase === 0 && testRoot.service.shortcutStatus.version === 3
          && testRoot.bindingsRefreshStarts > 0
          && testRoot.statusRefreshStarts > 0
          && testRoot.settingsRefreshStarts > 0
          && !testRoot.service.bindingsAttemptActive
          && !testRoot.service.shortcutStatusAttemptActive
          && !testRoot.service.settingsAttemptActive) {
        if (!("assignShortcut" in testRoot.service) || !("removeShortcut" in testRoot.service)
            || !("mutateShortcut" in testRoot.service) || !("resetAll" in testRoot.service)) {
          testRoot.fail("shortcut assignment or legacy mutation API is missing")
          return
        }
        const priorSettings = testRoot.service.settings
        testRoot.service.settings = Object.assign({}, priorSettings, { language: "ko" })
        const localizedStale = testRoot.service.decodeUserError(JSON.stringify({
          version: 1, code: "catalog.selection_stale",
          message: "selected application is stale or unavailable",
          context: { kind: "application" }
        }))
        const unknownFallback = testRoot.service.decodeUserError(JSON.stringify({
          version: 1, code: "vendor.unknown", message: "Fallback guidance",
          context: {}
        }))
        testRoot.service.settings = priorSettings
        if (localizedStale !== "선택한 항목이 변경되었거나 제거되었습니다. 아무것도 수정하지 않았으니 다시 선택하세요."
            || unknownFallback !== "Fallback guidance") {
          testRoot.fail("structured user errors were not localized safely")
          return
        }
        let semanticStatus
        let semanticBindings
        try {
          semanticStatus = testRoot.service.parseShortcutStatus(testRoot.statusDocument(1))
          semanticBindings = testRoot.service.parseBindings(testRoot.bindingsDocument(1))
        } catch (error) {
          testRoot.fail("semantic binding metadata was rejected: " + error)
          return
        }
        if (semanticStatus.actions[0].selectionId !== "command:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            || semanticStatus.actions[0].launchKind !== "webapp"
            || semanticBindings[0].selection_kind !== "command"
            || semanticBindings[0].title_override !== "My Notes") {
          testRoot.fail("semantic binding metadata was discarded")
          return
        }
        const invalidActionKind = testRoot.statusDocument(1)
        invalidActionKind.actions[0].actionKind = "shell"
        let rejectedInvalidActionKind = false
        try {
          testRoot.service.parseShortcutStatus(invalidActionKind)
        } catch (error) {
          rejectedInvalidActionKind = true
        }
        if (!rejectedInvalidActionKind) {
          testRoot.fail("shortcut actionKind accepted a value outside exec/lua")
          return
        }
        testRoot.successfulAssignmentBindingsBaseline = testRoot.bindingsRefreshStarts
        testRoot.successfulAssignmentStatusBaseline = testRoot.statusRefreshStarts
        testRoot.mutationDeferredBindingsBaseline = testRoot.bindingsRefreshStarts
        testRoot.mutationDeferredSettingsBaseline = testRoot.settingsRefreshStarts
        if (!testRoot.service.assignShortcut(testRoot.assignmentRequest())) {
          testRoot.fail("valid shortcut assignment was rejected")
          return
        }
        const settingsGenerationBeforeCollision = testRoot.service.settingsWriteGeneration
        if (testRoot.service.patchSettings({ language: "ko" })
            || testRoot.service.settingsSaveActive
            || testRoot.service.settingsWriteGeneration !== settingsGenerationBeforeCollision
            || testRoot.service.settingsSaveError.indexOf("shortcut change") === -1) {
          testRoot.fail("settings write overlapped an active shortcut mutation")
          return
        }
        if (testRoot.service.shortcutMutationOperation !== "assign"
            || testRoot.service.assignShortcut(testRoot.assignmentRequest())) {
          testRoot.fail("assignment operation did not reject a concurrent request")
          return
        }
        testRoot.service.refreshBindings()
        testRoot.service.refreshSettings()
        if (testRoot.bindingsRefreshStarts !== testRoot.mutationDeferredBindingsBaseline
            || testRoot.settingsRefreshStarts !== testRoot.mutationDeferredSettingsBaseline
            || !testRoot.service.bindingsRefreshPending
            || !testRoot.service.settingsRefreshPending) {
          testRoot.fail("bindings or settings refresh started during shortcut mutation")
          return
        }
        testRoot.phase = 1
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 1 && testRoot.results.length === 1
          && testRoot.service.shortcutStatus.managedCount === 1
          && testRoot.service.allBindings.length === 4
          && testRoot.bindingsRefreshStarts > testRoot.successfulAssignmentBindingsBaseline
          && testRoot.statusRefreshStarts > testRoot.successfulAssignmentStatusBaseline
          && testRoot.settingsRefreshStarts > testRoot.mutationDeferredSettingsBaseline
          && !testRoot.service.bindingsAttemptActive
          && !testRoot.service.shortcutStatusAttemptActive
          && !testRoot.service.settingsAttemptActive) {
        if (!testRoot.results[0].success || testRoot.results[0].operation !== "assign"
            || testRoot.service.shortcutMutationActive || testRoot.service.shortcutMutationError
            || testRoot.service.bindingsRefreshPending
            || testRoot.service.settingsRefreshPending) {
          testRoot.fail("successful assignment did not publish clean confirmed state")
          return
        }
        testRoot.stableShortcutStatus = JSON.stringify(testRoot.service.shortcutStatus)
        testRoot.stableBindings = JSON.stringify(testRoot.service.allBindings)
        testRoot.stableSettings = JSON.stringify(testRoot.service.settings)
        testRoot.service.bindingsCommand = ["/usr/bin/printf", testRoot.stableBindings]
        testRoot.service.shortcutsMutationCommandPrefix = ["/usr/bin/python3", testRoot.helper, "malformed-options"]
        if (!testRoot.service.assignShortcut(testRoot.assignmentRequest())) {
          testRoot.fail("malformed payload probe was rejected before launch")
          return
        }
        testRoot.phase = 2
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 2 && testRoot.results.length === 2) {
        if (testRoot.results[1].success || testRoot.results[1].operation !== "assign"
            || JSON.stringify(testRoot.service.shortcutStatus) !== testRoot.stableShortcutStatus
            || JSON.stringify(testRoot.service.allBindings) !== testRoot.stableBindings) {
          testRoot.fail("malformed key options did not preserve the prior assignment state")
          return
        }
        testRoot.service.shortcutsMutationCommandPrefix = ["/usr/bin/python3", testRoot.helper, "duplicate-actions"]
        if (!testRoot.service.assignShortcut(testRoot.assignmentRequest())) {
          testRoot.fail("duplicate action probe was rejected before launch")
          return
        }
        testRoot.phase = 3
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 3 && testRoot.results.length === 3) {
        if (testRoot.results[2].success || testRoot.results[2].operation !== "assign"
            || JSON.stringify(testRoot.service.shortcutStatus) !== testRoot.stableShortcutStatus
            || JSON.stringify(testRoot.service.allBindings) !== testRoot.stableBindings) {
          testRoot.fail("duplicate action IDs did not preserve the prior assignment state")
          return
        }
        const noncanonicalStatus = testRoot.statusDocument(1)
        noncanonicalStatus.actions[0].modifiers = ["CTRL", "SUPER"]
        testRoot.service.shortcutsMutationCommandPrefix = ["/usr/bin/printf", JSON.stringify({
          shortcuts: noncanonicalStatus, bindings: testRoot.bindingsDocument(1)
        })]
        testRoot.noncanonicalBindingsBaseline = testRoot.bindingsRefreshStarts
        testRoot.noncanonicalStatusBaseline = testRoot.statusRefreshStarts
        if (!testRoot.service.assignShortcut(testRoot.assignmentRequest())) {
          testRoot.fail("noncanonical action probe was rejected before launch")
          return
        }
        testRoot.phase = 4
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 4 && testRoot.results.length === 4
          && testRoot.bindingsRefreshStarts > testRoot.noncanonicalBindingsBaseline
          && testRoot.statusRefreshStarts > testRoot.noncanonicalStatusBaseline
          && !testRoot.service.bindingsAttemptActive
          && !testRoot.service.shortcutStatusAttemptActive) {
        if (testRoot.results[3].success || testRoot.results[3].operation !== "assign"
            || JSON.stringify(testRoot.service.shortcutStatus) !== testRoot.stableShortcutStatus
            || JSON.stringify(testRoot.service.allBindings) !== testRoot.stableBindings) {
          testRoot.fail("noncanonical action modifiers did not preserve assignment state")
          return
        }
        const malformedBindings = testRoot.bindingsDocument(1)
        malformedBindings[1].modifiers = "CTRL"
        testRoot.service.shortcutsMutationCommandPrefix = ["/usr/bin/printf", JSON.stringify({
          shortcuts: testRoot.statusDocument(1), bindings: malformedBindings
        })]
        if (!testRoot.service.assignShortcut(testRoot.assignmentRequest())) {
          testRoot.fail("malformed bindings probe was rejected before launch")
          return
        }
        testRoot.service.bindingsCommand = ["/usr/bin/printf", JSON.stringify(testRoot.bindingsDocument(1))]
        testRoot.service.shortcutsStatusCommand = ["/usr/bin/printf", JSON.stringify(testRoot.statusDocument(1))]
        testRoot.acknowledgementBindingsBaseline = testRoot.bindingsRefreshStarts
        testRoot.acknowledgementStatusBaseline = testRoot.statusRefreshStarts
        testRoot.phase = 5
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 5 && testRoot.results.length === 5) {
        if (testRoot.results[4].success || testRoot.results[4].operation !== "assign"
            || testRoot.results[4].errorMessage.indexOf("could not confirm committed shortcut state") === -1
            || JSON.stringify(testRoot.service.shortcutStatus) !== testRoot.stableShortcutStatus
            || JSON.stringify(testRoot.service.allBindings) !== testRoot.stableBindings) {
          testRoot.fail("malformed binding payload did not preserve assignment state")
          return
        }
        if (testRoot.bindingsRefreshStarts <= testRoot.acknowledgementBindingsBaseline
            || testRoot.statusRefreshStarts <= testRoot.acknowledgementStatusBaseline) {
          testRoot.fail("uncertain assignment acknowledgement did not force a coherent refresh")
          return
        }
        testRoot.service.shortcutsMutationCommandPrefix = ["/usr/bin/python3", testRoot.helper, "fail"]
        if (!testRoot.service.assignShortcut(testRoot.assignmentRequest())) {
          testRoot.fail("failure probe was rejected before launch")
          return
        }
        testRoot.phase = 6
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 6 && testRoot.results.length === 6) {
        const friendlyFailure = "The shortcut could not be changed. Your previous shortcut is still active."
        if (testRoot.results[5].success || testRoot.results[5].operation !== "assign"
            || testRoot.results[5].errorMessage !== friendlyFailure
            || testRoot.service.shortcutMutationError !== friendlyFailure
            || JSON.stringify(testRoot.service.shortcutStatus) !== testRoot.stableShortcutStatus
            || JSON.stringify(testRoot.service.allBindings) !== testRoot.stableBindings) {
          testRoot.fail("failed assignment did not preserve status, bindings, and its diagnostic")
          return
        }
        testRoot.service.shortcutsMutationCommandPrefix = ["/usr/bin/printf", JSON.stringify({
          shortcuts: [],
          settings: { version: 2, enabled: true, position: "center", scale: 1.0, opacity: 0.94,
            groups: ["SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT", "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT", "SUPER+SHIFT+ALT", "SUPER+CTRL+SHIFT+ALT"],
            hiddenBindingIds: [], followTheme: true, language: "en" }
        })]
        testRoot.resetAcknowledgementSettingsBaseline = testRoot.settingsRefreshStarts
        if (!testRoot.service.resetAll()) {
          testRoot.fail("malformed reset shortcut probe was rejected")
          return
        }
        testRoot.phase = 7
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 7 && testRoot.results.length === 7) {
        if (testRoot.results[6].success || testRoot.results[6].operation !== "reset-all"
            || JSON.stringify(testRoot.service.shortcutStatus) !== testRoot.stableShortcutStatus
            || JSON.stringify(testRoot.service.settings) !== testRoot.stableSettings) {
          testRoot.fail("malformed reset shortcut response partially changed client state")
          return
        }
        if (testRoot.settingsRefreshStarts <= testRoot.resetAcknowledgementSettingsBaseline) {
          testRoot.fail("uncertain reset acknowledgement did not refresh settings")
          return
        }
        testRoot.service.shortcutsMutationCommandPrefix = ["/usr/bin/printf", JSON.stringify({
          shortcuts: testRoot.statusDocument(0),
          settings: []
        })]
        if (!testRoot.service.resetAll()) {
          testRoot.fail("malformed reset-all probe was rejected")
          return
        }
        testRoot.phase = 8
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 8 && testRoot.results.length === 8) {
        if (testRoot.results[7].success || testRoot.results[7].operation !== "reset-all"
            || JSON.stringify(testRoot.service.shortcutStatus) !== testRoot.stableShortcutStatus
            || JSON.stringify(testRoot.service.settings) !== testRoot.stableSettings) {
          testRoot.fail("malformed reset-all response partially changed client state")
          return
        }
        testRoot.service.shortcutsStatusCommand = ["/usr/bin/printf", JSON.stringify(testRoot.statusDocument(0))]
        testRoot.service.bindingsCommand = ["/usr/bin/printf", "[]"]
        testRoot.service.shortcutsMutationCommandPrefix = ["/usr/bin/printf", JSON.stringify({
          shortcuts: testRoot.statusDocument(0),
          settings: { version: 2, enabled: true, position: "center", scale: 1.0, opacity: 0.94,
            groups: ["SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT", "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT", "SUPER+SHIFT+ALT", "SUPER+CTRL+SHIFT+ALT"],
            hiddenBindingIds: [], followTheme: true, language: "en" }
        })]
        if (!testRoot.service.resetAll()) {
          testRoot.fail("reset-all was rejected")
          return
        }
        testRoot.phase = 9
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 9 && testRoot.results.length === 9
          && testRoot.service.shortcutStatus.managedCount === 0
          && testRoot.service.allBindings.length === 0) {
        if (!testRoot.results[8].success || testRoot.results[8].operation !== "reset-all"
            || testRoot.service.settings.enabled !== true || testRoot.service.settings.position !== "center"
            || testRoot.service.shortcutMutationError) {
          testRoot.fail("reset-all did not apply both confirmed default documents: "
            + JSON.stringify({ result: testRoot.results[8], settings: testRoot.service.settings,
              error: testRoot.service.shortcutMutationError }))
          return
        }
        testRoot.service.shortcutsMutationCommandPrefix = [
          "/usr/bin/printf", JSON.stringify({
            shortcuts: testRoot.statusDocument(0), bindings: []
          })
        ]
        if (!testRoot.service.removeShortcut(testRoot.removeRequest())) {
          testRoot.fail("remove operation was rejected")
          return
        }
        testRoot.phase = 10
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 10 && testRoot.results.length === 10) {
        if (!testRoot.results[9].success || testRoot.results[9].operation !== "remove"
            || testRoot.service.shortcutStatus.version !== 3
            || testRoot.service.allBindings.length !== 0) {
          testRoot.fail("remove response did not install confirmed status and bindings")
          return
        }
        lockService.locked = true
        console.log("KEYGUIDE_SHORTCUT_SERVICE_TEST_PASS")
        Qt.quit()
      }
    }
  }
}
