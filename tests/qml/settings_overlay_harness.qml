import QtQuick
import Quickshell

ShellRoot {
  id: testRoot

  property int phase: 0
  property int ticks: 0
  property var settingsOverlay: null
  property string pluginRoot: Quickshell.env("KEYGUIDE_TEST_PLUGIN_ROOT")

  Item { id: overlayHost }

  QtObject {
    id: fakeService

    property var settings: ({
      version: 2,
      enabled: true,
      position: "center",
      scale: 1.0,
      opacity: 0.94,
      groups: [
        "SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT",
        "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT",
        "SUPER+SHIFT+ALT", "SUPER+CTRL+SHIFT+ALT"
      ],
      hiddenBindingIds: [],
      followTheme: true,
      language: "en"
    })
    property var allBindings: [
      {
        id: "terminal-id", presentation_id: "terminal-visibility",
        modifiers: ["SUPER"], key: "RETURN", description: "Terminal",
        dispatcher: "exec", argument: "alacritty", mouse: false,
        editable: true, action_kind: "exec", action_argument: "alacritty",
        edit_reason: "", selection_kind: "action",
        selection_id: "action-terminal", label_key: "action.terminal",
        title_override: ""
      },
      {
        id: "launcher-id", presentation_id: "launcher-visibility",
        modifiers: ["SUPER"], key: "SPACE", description: "Launcher",
        dispatcher: "__lua", argument: "101", mouse: false,
        editable: false, action_kind: "", action_argument: "",
        edit_reason: "Action cannot be reconstructed", selection_kind: "",
        selection_id: "", label_key: "", title_override: ""
      },
      {
        id: "chatgpt-id", presentation_id: "action-chatgpt",
        modifiers: ["SUPER", "SHIFT"], key: "A", description: "ChatGPT",
        dispatcher: "exec", argument: "gtk-launch chatgpt.desktop", mouse: false,
        editable: true, action_kind: "exec",
        action_argument: "gtk-launch chatgpt.desktop", edit_reason: "",
        selection_kind: "application",
        selection_id: "application:chatgpt.desktop", label_key: "",
        title_override: ""
      }
    ]
    property var shortcutStatus: ({
      version: 3,
      managedCount: 1,
      managedBindingIds: ["terminal-id"],
      keyOptionsByGroup: {
        "SUPER": [
          {
            key: "RETURN", state: "assigned", title: "Terminal",
            bindingId: "terminal-id", actionId: "action-terminal",
            presentationId: "terminal-visibility", editable: true,
            editReason: "", removable: true, removeReason: ""
          },
          {
            key: "SPACE", state: "assigned", title: "Launcher",
            bindingId: "launcher-id", actionId: "",
            presentationId: "launcher-visibility", editable: false,
            editReason: "Action cannot be reconstructed",
            removable: true, removeReason: ""
          },
          {
            key: "N", state: "free", title: "", bindingId: "",
            actionId: "", presentationId: "", editable: true,
            editReason: "", removable: false,
            removeReason: "No shortcut assigned"
          }
        ],
        "SUPER+CTRL": [], "SUPER+SHIFT": [], "SUPER+ALT": [],
        "SUPER+CTRL+SHIFT": [], "SUPER+CTRL+ALT": [],
        "SUPER+SHIFT+ALT": [], "SUPER+CTRL+SHIFT+ALT": []
      },
      actions: [
        {
          id: "action-terminal", title: "Terminal",
          labelKey: "action.terminal", selectionKind: "action",
          selectionId: "action-terminal", titleOverride: "",
          actionKind: "exec", displayKind: "cmd", roleKind: "",
          targetName: "", modifiers: ["SUPER"], key: "RETURN"
        },
        {
          id: "action-screenshot", title: "Screenshot",
          labelKey: "action.screenshot", selectionKind: "action",
          selectionId: "action-screenshot", titleOverride: "",
          actionKind: "exec", modifiers: ["SUPER", "SHIFT"], key: "S"
        },
        {
          id: "action-chatgpt", title: "ChatGPT", labelKey: "",
          selectionKind: "application",
          selectionId: "application:chatgpt.desktop", titleOverride: "",
          actionKind: "exec", displayKind: "desktopApp", roleKind: "",
          targetId: "application:chatgpt.desktop", targetName: "ChatGPT",
          modifiers: ["SUPER", "SHIFT"], key: "A"
        }
      ],
      discoveryError: ""
    })
    property var actionCatalog: ({
      version: 1,
      fingerprint: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      items: [
        {
          kind: "application", id: "application:org.demo.App.desktop",
          title: "Demo App", englishTitle: "Demo App", summary: "Friendly app",
          icon: "application-x-executable", path: "", keywords: ["demo"]
        },
        {
          kind: "application", id: "application:chatgpt.desktop",
          title: "ChatGPT", englishTitle: "ChatGPT", summary: "AI assistant",
          icon: "chatgpt", path: "", keywords: ["ChatGPT"],
          targetId: "application:chatgpt.desktop", launchKind: "desktopApp"
        },
        {
          kind: "command", id: "command:true", title: "true",
          englishTitle: "true", summary: "", icon: "",
          path: "/usr/bin/true", keywords: ["true"]
        }
      ],
      warnings: []
    })
    property var actionCatalogWarnings: []
    property bool actionCatalogBusy: false
    property bool actionCatalogLoading: false
    property string actionCatalogError: ""
    property bool actionCatalogWatching: false
    property int actionCatalogWatchCalls: 0
    property bool shortcutMutationActive: false
    property string shortcutMutationError: ""
    property bool settingsSaveActive: false
    property string settingsSaveError: ""
    property string lastError: ""
    property int assignmentCalls: 0
    property var lastAssignmentRequest: null
    property int resetCalls: 0
    property int removeCalls: 0
    property var lastRemoveRequest: null
    property int saveCalls: 0
    property var lastPatch: null

    signal settingsSaveFinished(bool success, string errorMessage)
    signal shortcutMutationFinished(bool success, string errorMessage, string operation)

    function patchSettings(patch) {
      saveCalls += 1
      lastPatch = JSON.parse(JSON.stringify(patch))
      settingsSaveActive = true
      Qt.callLater(function() {
        const next = JSON.parse(JSON.stringify(fakeService.settings))
        Object.keys(patch).forEach(function(key) { next[key] = patch[key] })
        fakeService.settings = next
        fakeService.settingsSaveActive = false
        fakeService.settingsSaveFinished(true, "")
      })
      return true
    }

    function assignShortcut(request) {
      assignmentCalls += 1
      lastAssignmentRequest = JSON.parse(JSON.stringify(request))
      return true
    }

    function removeShortcut(request) {
      removeCalls += 1
      lastRemoveRequest = JSON.parse(JSON.stringify(request))
      return true
    }

    function resetAll() {
      resetCalls += 1
      return true
    }

    function setActionCatalogWatching(enabled) {
      actionCatalogWatchCalls += 1
      actionCatalogWatching = enabled === true
    }
  }

  QtObject {
    id: fakeShell
    property int hideCalls: 0

    function hide(pluginId) {
      if (pluginId !== "mrai.keyguide")
        return false
      hideCalls += 1
      if (testRoot.settingsOverlay)
        testRoot.settingsOverlay.close()
      return true
    }
  }

  function fail(message) {
    console.error("KEYGUIDE_SETTINGS_OVERLAY_TEST_FAIL: " + message)
    Qt.quit()
  }

  function sortedKeys(object) {
    return Object.keys(object || {}).sort().join(",")
  }

  function findNamed(object, name, depth) {
    if (!object || depth > 30)
      return null
    if (String(object.objectName || "") === name)
      return object
    const candidates = []
    const children = object.children || []
    const data = object.data || []
    for (let index = 0; index < children.length; index += 1)
      candidates.push(children[index])
    for (let index = 0; index < data.length; index += 1) {
      if (candidates.indexOf(data[index]) === -1)
        candidates.push(data[index])
    }
    if (object.contentItem && candidates.indexOf(object.contentItem) === -1)
      candidates.push(object.contentItem)
    for (let index = 0; index < candidates.length; index += 1) {
      const match = findNamed(candidates[index], name, depth + 1)
      if (match)
        return match
    }
    return null
  }

  function requireNamed(name) {
    const object = findNamed(testRoot.settingsOverlay, name, 0)
    if (!object)
      testRoot.fail("localized action search is missing " + name)
    return object
  }

  function assertRequiredSurface() {
    const required = [
      "settingsWindow", "settingsCard", "settingsKeyCatcher", "settingsContent",
      "settingsTitleText", "settingsSubtitleText", "settingsLanguagePicker",
      "settingsScalePreset75", "settingsScalePreset100",
      "settingsScalePreset125", "settingsScalePreset150", "settingsScaleInput",
      "settingsOpacityPreset50", "settingsOpacityPreset75",
      "settingsOpacityPreset90", "settingsOpacityPreset100", "settingsOpacityInput",
      "shortcutManagementTitle", "shortcutGroupPicker", "shortcutKeyPicker",
      "shortcutRegisteredFilter", "shortcutRegisteredSearchInput",
      "shortcutRegisteredGroup-SUPER",
      "shortcutActionSearch", "shortcutActionSearchInput",
      "shortcutAssignmentPopupScrim", "shortcutAssignmentPopup",
      "shortcutAssignmentTitle", "shortcutAssignmentPreview",
      "shortcutAssignmentArguments", "shortcutAssignmentApply",
      "shortcutAssignmentRemove", "shortcutAssignmentCancel", "shortcutResetButton",
      "settingsCancelButton", "settingsSaveButton"
    ]
    for (let index = 0; index < required.length; index += 1) {
      if (!requireNamed(required[index]))
        return false
    }
    const removed = [
      "shortcutActionPicker", "shortcutExecutablePath",
      "shortcutExecutablePickerButton", "shortcutExecutableDialog",
      "shortcutExecutablePicker", "shortcutExecutableShowHidden"
    ]
    for (let index = 0; index < removed.length; index += 1) {
      if (findNamed(testRoot.settingsOverlay, removed[index], 0)) {
        testRoot.fail("obsolete executable browser remains: " + removed[index])
        return false
      }
    }
    if (testRoot.settingsOverlay.defaultSettings().version !== 2
        || testRoot.settingsOverlay.defaultSettings().language !== "en"
        || "showHiddenFiles" in testRoot.settingsOverlay.defaultSettings()) {
      testRoot.fail("Settings does not use the exact version-2 language schema")
      return false
    }
    return true
  }

  function assertContextualAssignmentPopup() {
    const popup = requireNamed("shortcutAssignmentPopup")
    const scrim = requireNamed("shortcutAssignmentPopupScrim")
    const card = requireNamed("settingsCard")
    const popupHost = requireNamed("settingsKeyCatcher")
    const scroll = requireNamed("settingsScroll")
    if (!popup || !scrim || !card || !popupHost || !scroll)
      return false
    if (popup.visible || scrim.visible) {
      testRoot.fail("shortcut editor popup was visible before a key was selected")
      return false
    }

    const contentHeightBefore = scroll.contentHeight
    if (!testRoot.settingsOverlay.selectKey("N")
        || !popup.visible || !scrim.visible) {
      testRoot.fail("selecting a new key did not open the editor popup")
      return false
    }
    if (popup.parent !== popupHost
        || Math.abs(popup.x - (card.width - popup.width) / 2) > 2
        || Math.abs(popup.y - (card.height - popup.height) / 2) > 2) {
      testRoot.fail("new-key editor was not centered in the visible Settings card")
      return false
    }
    if (Math.abs(scroll.contentHeight - contentHeightBefore) > 1) {
      testRoot.fail("opening the popup still changed the scrollable document height")
      return false
    }
    testRoot.settingsOverlay.cancelAssignment()

    const row = requireNamed("shortcutBindingRow-terminal-id")
    if (!row)
      return false
    const rowInScroll = row.mapToItem(scroll, 0, 0)
    scroll.contentY = Math.max(0, Math.min(
      scroll.contentHeight - scroll.height,
      rowInScroll.y - scroll.height / 2))
    const scrollPosition = scroll.contentY
    const mapped = row.mapToItem(popupHost, 0, row.height / 2)
    if (!testRoot.settingsOverlay.openBinding("terminal-id", row)
        || !popup.visible
        || testRoot.settingsOverlay.assignmentPopupOrigin !== "row"
        || Math.abs(testRoot.settingsOverlay.assignmentPopupAnchorY - mapped.y) > 2) {
      testRoot.fail("registered-row Change did not anchor the popup to that row")
      return false
    }
    if (scroll.contentY !== scrollPosition
        || popup.y < 0 || popup.y + popup.height > card.height
        || testRoot.settingsOverlay.assignmentPopupAnchorY < popup.y
        || testRoot.settingsOverlay.assignmentPopupAnchorY > popup.y + popup.height) {
      testRoot.fail("row editor moved the list or opened outside the visible card"
        + " scroll=" + scroll.contentY + "/" + scrollPosition
        + " popup=" + popup.y + ".." + (popup.y + popup.height)
        + " card=" + card.height
        + " anchor=" + testRoot.settingsOverlay.assignmentPopupAnchorY)
      return false
    }
    testRoot.settingsOverlay.cancelAssignment()
    return !popup.visible && !scrim.visible
  }

  function assertRegisteredFiltering() {
    const searchInput = requireNamed("shortcutRegisteredSearchInput")
    const idle = requireNamed("shortcutRegisteredFilterIdle")
    if (!searchInput || !idle)
      return false
    if (testRoot.settingsOverlay.registeredSearchQuery !== ""
        || testRoot.settingsOverlay.registeredFilterGroup !== ""
        || testRoot.settingsOverlay.registeredBindings.length !== 0
        || findNamed(testRoot.settingsOverlay, "shortcutBindingRow-terminal-id", 0)) {
      testRoot.fail("registered shortcuts were visible before a filter was chosen")
      return false
    }

    testRoot.settingsOverlay.registeredSearchQuery = "terminal"
    if (testRoot.settingsOverlay.registeredBindings.length !== 1
        || testRoot.settingsOverlay.registeredBindings[0].id !== "terminal-id") {
      testRoot.fail("registered title search did not scan all modifier groups")
      return false
    }
    const row = requireNamed("shortcutBindingRow-terminal-id")
    const badge = row ? findNamed(row, "bindingTypeBadgeLabel", 0) : null
    if (!row || !badge || badge.text !== "CMD") {
      testRoot.fail("registered result did not show its shared CMD type badge")
      return false
    }

    testRoot.settingsOverlay.registeredSearchQuery = "chatgpt"
    if (testRoot.settingsOverlay.registeredBindings.length !== 1
        || testRoot.settingsOverlay.registeredBindings[0].id !== "chatgpt-id"
        || testRoot.settingsOverlay.registeredBindings[0].icon !== "chatgpt") {
      testRoot.fail("registered app did not resolve its exact catalog icon")
      return false
    }
    const appRow = requireNamed("shortcutBindingRow-chatgpt-id")
    const appIcon = appRow
      ? findNamed(appRow, "bindingPresentationIcon", 0) : null
    if (!appRow || !appIcon || String(appIcon.source || "") === "") {
      testRoot.fail("registered app icon did not reach the visible row")
      return false
    }

    testRoot.settingsOverlay.registeredSearchQuery = ""
    if (!testRoot.settingsOverlay.selectRegisteredGroup("SUPER")
        || testRoot.settingsOverlay.registeredBindings.length !== 2
        || testRoot.settingsOverlay.registeredBindings.map(function(binding) {
          return binding.id
        }).join(",") !== "launcher-id,terminal-id") {
      testRoot.fail("registered modifier chip did not show its exact group")
      return false
    }
    if (!testRoot.settingsOverlay.selectRegisteredGroup("SUPER")
        || testRoot.settingsOverlay.registeredFilterGroup !== ""
        || testRoot.settingsOverlay.registeredBindings.length !== 0) {
      testRoot.fail("selected registered modifier chip did not toggle off")
      return false
    }

    testRoot.settingsOverlay.registeredSearchQuery = "terminal"
    return true
  }

  function assertLocale(language, title, management, save, placeholder,
                        registeredTitle, typeRoleColumn) {
    if (!testRoot.settingsOverlay.updatePending("language", language)) {
      testRoot.fail("language could not be selected: " + language)
      return false
    }
    const titleText = requireNamed("settingsTitleText")
    const managementText = requireNamed("shortcutManagementTitle")
    const saveButton = requireNamed("settingsSaveButton")
    const searchInput = requireNamed("shortcutActionSearchInput")
    const registeredRow = requireNamed("shortcutBindingRow-terminal-id")
    const typeRoleHeader = requireNamed("shortcutTypeRoleHeader")
    const previewTitle = requireNamed("hudPreviewDescription-terminal-id")
    const previewIcon = requireNamed("hudPreviewPresentationIcon-terminal-id")
    if (!titleText || !managementText || !saveButton || !searchInput
        || !registeredRow || !typeRoleHeader || !previewTitle || !previewIcon)
      return false
    if (titleText.text !== title || managementText.text !== management
        || saveButton.text !== save || searchInput.placeholderText !== placeholder
        || String(registeredRow.bindingData.description || "")
          !== registeredTitle
        || String(typeRoleHeader.text || "") !== typeRoleColumn
        || String(previewTitle.text || "") !== registeredTitle
        || String(previewIcon.source || "") === "") {
      testRoot.fail("locale did not update the complete Settings surface: " + language
        + " title=" + titleText.text + " management=" + managementText.text
        + " save=" + saveButton.text + " search=" + searchInput.placeholderText
        + " registered=" + String(registeredRow.bindingData.description || "")
        + " typeRole=" + String(typeRoleHeader.text || "")
        + " preview=" + String(previewTitle.text || ""))
      return false
    }
    testRoot.settingsOverlay.shortcutEditorError = testRoot.settingsOverlay.t(
      "error.chooseAction", {})
    if (testRoot.settingsOverlay.displayedStatus
        !== testRoot.settingsOverlay.t("error.chooseAction", {})) {
      testRoot.fail("localized user error did not reach the Settings status")
      return false
    }
    testRoot.settingsOverlay.shortcutEditorError = ""
    return true
  }

  function assertEveryLocale() {
    return assertLocale(
      "ko", "Omarchy 키가이드", "단축키 관리", "저장",
      "앱 또는 행동 검색", "터미널", "유형 / 역할")
      && assertLocale(
        "ja", "Omarchy キーガイド", "ショートカット管理", "保存",
        "アプリまたは操作を検索", "ターミナル", "種類 / 役割")
      && assertLocale(
        "zh_CN", "Omarchy 快捷键指南", "快捷键管理", "保存",
        "搜索应用或操作", "终端", "类型 / 角色")
      && assertLocale(
        "es", "Guía de teclas de Omarchy", "Gestión de atajos", "Guardar",
        "Busca aplicaciones o acciones", "Terminal", "Tipo / Rol")
      && assertLocale(
        "en", "Omarchy Keyguide", "Shortcut management", "Save",
        "Search apps or actions", "Terminal", "Type / Role")
  }

  function assertVisibilityAndKeyCapture() {
    testRoot.settingsOverlay.beginPending()
    if (!testRoot.settingsOverlay.setBindingVisible("terminal-visibility", false)
        || testRoot.settingsOverlay.pendingSettings.hiddenBindingIds.indexOf(
          "terminal-visibility") === -1) {
      testRoot.fail("HUD visibility no longer uses stable presentation identity")
      return false
    }
    if (!testRoot.settingsOverlay.beginKeyCapture()
        || !testRoot.settingsOverlay.captureKey(Qt.Key_N, Qt.NoModifier)
        || testRoot.settingsOverlay.selectedKey !== "N") {
      testRoot.fail("beginner key capture did not choose the exact free key")
      return false
    }
    const keyLabels = testRoot.settingsOverlay.keyOptions.map(function(option) {
      return option.label
    }).join("|")
    if (keyLabels !== "RETURN · Assigned — Terminal|SPACE · Assigned — Launcher|N · Available") {
      testRoot.fail("localized key availability labels changed order: " + keyLabels)
      return false
    }
    return true
  }

  function exactRequest(request, kind, id, titleOverride, arguments, bindingId,
                        confirmReplace) {
    const keys = [
      "confirmReplace", "customArguments", "selectionId", "selectionKind",
      "targetBindingId", "targetKey", "targetModifiers", "titleOverride"
    ].join(",")
    return request && sortedKeys(request) === keys
      && request.targetModifiers.join("+") === "SUPER"
      && request.selectionKind === kind && request.selectionId === id
      && request.titleOverride === titleOverride
      && request.customArguments === arguments
      && request.targetBindingId === bindingId
      && request.confirmReplace === confirmReplace
  }

  function assertSearchAndAssignments() {
    testRoot.settingsOverlay.beginPending()
    testRoot.settingsOverlay.selectKey("N")
    const search = requireNamed("shortcutActionSearch")
    if (!search)
      return false
    search.openSearch()
    if (!fakeService.actionCatalogWatching) {
      testRoot.fail("opening search did not start live catalog watching")
      return false
    }

    testRoot.settingsOverlay.updatePending("language", "ko")
    search.query = "터미널"
    if (search.results.length < 1
        || search.results[0].id !== "action-terminal") {
      testRoot.fail("Korean action search did not find Terminal")
      return false
    }
    search.query = "terminal"
    if (search.results.length < 1
        || search.results[0].id !== "action-terminal") {
      testRoot.fail("English action search did not work in a localized chooser")
      return false
    }
    testRoot.settingsOverlay.updatePending("language", "en")

    testRoot.settingsOverlay.selectSearchResult({
      kind: "application", id: "application:org.demo.App.desktop",
      title: "Demo App", englishTitle: "Demo App"
    })
    let request = testRoot.settingsOverlay.buildAssignmentRequest()
    if (!exactRequest(
        request, "application", "application:org.demo.App.desktop", "", "", "", false)) {
      testRoot.fail("application selection did not emit the stable identity schema")
      return false
    }
    testRoot.settingsOverlay.assignmentTitle = "My Demo"
    request = testRoot.settingsOverlay.buildAssignmentRequest()
    if (!request || request.titleOverride !== "My Demo") {
      testRoot.fail("edited application title was not an explicit override")
      return false
    }

    testRoot.settingsOverlay.selectSearchResult(search.results[0])
    request = testRoot.settingsOverlay.buildAssignmentRequest()
    if (!exactRequest(
        request, "action", "action-terminal", "", "", "", false)) {
      testRoot.fail("general action selection did not preserve action identity")
      return false
    }

    testRoot.settingsOverlay.selectSearchResult({
      kind: "command", id: "command:true", title: "true",
      englishTitle: "true"
    })
    testRoot.settingsOverlay.assignmentArguments = "--version"
    request = testRoot.settingsOverlay.buildAssignmentRequest()
    if (!exactRequest(request, "command", "command:true", "", "--version", "", false)) {
      testRoot.fail("command selection did not preserve command identity and arguments")
      return false
    }

    testRoot.settingsOverlay.selectKey("RETURN")
    testRoot.settingsOverlay.selectSearchResult({
      kind: "command", id: "command:true", title: "true",
      englishTitle: "true"
    })
    const callsBefore = fakeService.assignmentCalls
    if (testRoot.settingsOverlay.submitAssignment()
        || !testRoot.settingsOverlay.replacementArmed
        || fakeService.assignmentCalls !== callsBefore) {
      testRoot.fail("occupied replacement did not require a second confirmation")
      return false
    }
    if (!testRoot.settingsOverlay.submitAssignment()
        || fakeService.assignmentCalls !== callsBefore + 1
        || !exactRequest(
          fakeService.lastAssignmentRequest, "command", "command:true", "", "",
          "terminal-id", true)) {
      testRoot.fail("confirmed replacement emitted the wrong stable request")
      return false
    }

    testRoot.settingsOverlay.cancelAssignment()
    if (!fakeService.actionCatalogWatching) {
      testRoot.fail("closing search stopped the Settings-wide catalog watcher")
      return false
    }
    return true
  }

  function assertResetAndLayout() {
    if (testRoot.settingsOverlay.requestResetAll()
        || !testRoot.settingsOverlay.resetConfirmationArmed
        || fakeService.resetCalls !== 0) {
      testRoot.fail("reset did not require explicit confirmation")
      return false
    }
    if (!testRoot.settingsOverlay.requestResetAll() || fakeService.resetCalls !== 1) {
      testRoot.fail("confirmed reset did not invoke reset-all exactly once")
      return false
    }
    testRoot.settingsOverlay.resetConfirmationArmed = false
    testRoot.settingsOverlay.shortcutEditorError = ""
    const card = requireNamed("settingsCard")
    const detail = requireNamed("settingsDetailLayout")
    const scroll = requireNamed("settingsScroll")
    if (!card || !detail || !scroll)
      return false
    card.width = 520
    card.height = 560
    if (detail.height < 0 || scroll.width < 0 || scroll.contentHeight <= 0) {
      testRoot.fail("localized Settings created invalid minimum layout bounds")
      return false
    }
    return true
  }

  function assertFriendlyPresentationControls() {
    const card = requireNamed("settingsCard")
    const header = requireNamed("shortcutListHeader")
    const row = requireNamed("shortcutBindingRow-terminal-id")
    const chordCell = row ? findNamed(row, "bindingChordCell", 0) : null
    const typeRoleHeader = requireNamed("shortcutTypeRoleHeader")
    const typeRoleCell = row ? findNamed(row, "bindingTypeRoleCell", 0) : null
    const visibility = row ? findNamed(row, "bindingVisibilityTarget", 0) : null
    if (!card || testRoot.settingsOverlay.settingsCardLogicalWidth !== 960
        || card.width > testRoot.settingsOverlay.settingsCardTargetWidth + 1) {
      testRoot.fail("Settings card does not use the five-column logical width")
      return false
    }
    if (!header || !chordCell || !typeRoleHeader || !typeRoleCell || !visibility
        || header.chordWidth !== 316
        || chordCell.width !== header.chordWidth) {
      testRoot.fail("registered header and rows do not share the reduced shortcut column")
      return false
    }
    const typeRoleX = typeRoleCell.mapToItem(row, 0, 0).x
    const hudX = visibility.mapToItem(row, 0, 0).x
    if (Math.abs(typeRoleHeader.x - typeRoleX) > 0.01
        || Math.abs(typeRoleHeader.width - typeRoleCell.width) > 0.01
        || Math.abs(hudX - typeRoleX - typeRoleCell.width - 24) > 0.01) {
      testRoot.fail("type/role header, row column, and HUD gutter are not aligned")
      return false
    }
    if (findNamed(testRoot.settingsOverlay, "settingsScaleSlider", 0)
        || findNamed(testRoot.settingsOverlay, "settingsOpacitySlider", 0)) {
      testRoot.fail("scale or opacity still uses a wheel-sensitive slider")
      return false
    }
    testRoot.settingsOverlay.beginPending()
    if (!testRoot.settingsOverlay.setScalePercent(125)
        || testRoot.settingsOverlay.pendingSettings.scale !== 1.25
        || !testRoot.settingsOverlay.setScalePercent(10)
        || testRoot.settingsOverlay.pendingSettings.scale !== 0.75
        || !testRoot.settingsOverlay.setOpacityPercent(75)
        || testRoot.settingsOverlay.pendingSettings.opacity !== 0.75
        || !testRoot.settingsOverlay.setOpacityPercent(101)
        || testRoot.settingsOverlay.pendingSettings.opacity !== 1.0
        || !testRoot.settingsOverlay.setOpacityPercent(3)
        || testRoot.settingsOverlay.pendingSettings.opacity !== 0.2) {
      testRoot.fail("preset or numeric percentage clamping is incorrect")
      return false
    }
    return true
  }

  function assertPerKeyRemoval() {
    testRoot.settingsOverlay.selectKey("SPACE")
    const apply = requireNamed("shortcutAssignmentApply")
    const remove = requireNamed("shortcutAssignmentRemove")
    if (!apply || !remove)
      return false
    if (apply.enabled || !remove.enabled || remove.text !== "Remove") {
      testRoot.fail("opaque shortcut was not removable independently of editing")
      return false
    }
    if (testRoot.settingsOverlay.requestRemoveShortcut()
        || !testRoot.settingsOverlay.removeConfirmationArmed
        || fakeService.removeCalls !== 0) {
      testRoot.fail("remove did not require a second confirmation")
      return false
    }
    testRoot.settingsOverlay.selectKey("RETURN")
    if (testRoot.settingsOverlay.removeConfirmationArmed) {
      testRoot.fail("changing the selected key did not clear remove confirmation")
      return false
    }
    testRoot.settingsOverlay.selectKey("SPACE")
    if (testRoot.settingsOverlay.requestRemoveShortcut()
        || !testRoot.settingsOverlay.requestRemoveShortcut()
        || fakeService.removeCalls !== 1) {
      testRoot.fail("confirmed remove did not invoke the service exactly once")
      return false
    }
    const request = fakeService.lastRemoveRequest
    const keys = [
      "argument", "confirmRemove", "dispatcher", "targetBindingId",
      "targetKey", "targetModifiers", "title"
    ].join(",")
    if (!request || sortedKeys(request) !== keys
        || request.targetModifiers.join("+") !== "SUPER"
        || request.targetKey !== "SPACE"
        || request.targetBindingId !== "launcher-id"
        || request.title !== "Launcher"
        || request.dispatcher !== "__lua" || request.argument !== "101"
        || request.confirmRemove !== true) {
      testRoot.fail("remove emitted the wrong stale-view identity")
      return false
    }
    testRoot.settingsOverlay.cancelAssignment()
    return true
  }

  Component.onCompleted: {
    const settingsUrl = testRoot.pluginRoot.length > 0
      ? "file://" + testRoot.pluginRoot + "/Settings.qml"
      : Qt.resolvedUrl("src/plugin/Settings.qml")
    const component = Qt.createComponent(settingsUrl, Component.PreferSynchronous)
    if (component.status !== Component.Ready) {
      fail("Settings failed to load: " + component.errorString())
      return
    }
    settingsOverlay = component.createObject(overlayHost, {
      shell: fakeShell,
      manifest: {id: "mrai.keyguide"},
      service: fakeService
    })
    if (!settingsOverlay || !settingsOverlay.open('{"mode":"settings"}')) {
      fail("Settings could not be created and opened")
      return
    }
  }

  Timer {
    interval: 25
    repeat: true
    running: true

    onTriggered: {
      testRoot.ticks += 1
      if (testRoot.ticks > 160) {
        testRoot.fail("phase " + testRoot.phase + " timed out")
        return
      }
      if (!testRoot.settingsOverlay)
        return

      if (testRoot.phase === 0) {
        if (!testRoot.settingsOverlay.keyboardFocusExclusive)
          return
        if (!fakeService.actionCatalogWatching) {
          testRoot.fail("opening Settings did not start catalog watching")
          return
        }
        if (!testRoot.assertRequiredSurface()
            || !testRoot.assertRegisteredFiltering()
            || !testRoot.assertContextualAssignmentPopup()
            || !testRoot.assertEveryLocale()
            || !testRoot.assertVisibilityAndKeyCapture()
            || !testRoot.assertSearchAndAssignments()
            || !testRoot.assertPerKeyRemoval()
            || !testRoot.assertFriendlyPresentationControls()
            || !testRoot.assertResetAndLayout())
          return

        testRoot.settingsOverlay.beginPending()
        testRoot.settingsOverlay.updatePending("language", "es")
        testRoot.settingsOverlay.updatePending("opacity", 0.72)
        const patch = testRoot.settingsOverlay.buildPatch()
        if (testRoot.sortedKeys(patch) !== "language,opacity") {
          testRoot.fail("language save was not batched into a minimal patch")
          return
        }
        if (!testRoot.settingsOverlay.save()) {
          testRoot.fail("localized settings save did not start")
          return
        }
        testRoot.phase = 1
        testRoot.ticks = 0
        return
      }

      if (testRoot.phase === 1 && !testRoot.settingsOverlay.opened) {
        if (fakeService.settings.language !== "es"
            || fakeService.settings.opacity !== 0.72
            || testRoot.sortedKeys(fakeService.lastPatch) !== "language,opacity") {
          testRoot.fail("saved language did not reach the committed v2 settings")
          return
        }
        testRoot.settingsOverlay.open('{"mode":"settings"}')
        testRoot.phase = 2
        testRoot.ticks = 0
        return
      }

      if (testRoot.phase === 2 && testRoot.settingsOverlay.opened) {
        const title = testRoot.requireNamed("settingsTitleText")
        const saveButton = testRoot.requireNamed("settingsSaveButton")
        if (!title || !saveButton)
          return
        if (testRoot.settingsOverlay.uiLanguage !== "es"
            || title.text !== "Guía de teclas de Omarchy"
            || saveButton.text !== "Guardar"
            || testRoot.settingsOverlay.registeredSearchQuery !== ""
            || testRoot.settingsOverlay.registeredFilterGroup !== ""
            || testRoot.settingsOverlay.registeredBindings.length !== 0) {
          testRoot.fail("reopening Settings restored a stale language")
          return
        }
        testRoot.settingsOverlay.close()
        if (fakeService.actionCatalogWatching
            || testRoot.settingsOverlay.keyboardFocusExclusive) {
          testRoot.fail("closing Settings retained watcher or keyboard focus")
          return
        }
        console.log("KEYGUIDE_SETTINGS_VISIBILITY_TEST_PASS")
        console.log("KEYGUIDE_SETTINGS_OVERLAY_TEST_PASS")
        Qt.quit()
      }
    }
  }
}
