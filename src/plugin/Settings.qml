pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "components" as Components
import "I18n.js" as I18n
import "VisibilityModel.js" as VisibilityModel

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null

  property bool opened: false
  property bool awaitingSave: false
  property var savedSnapshot: defaultSettings()
  property var pendingSettings: defaultSettings()
  property var dirtyKeys: ({})
  property string saveError: ""
  property string selectedGroup: "SUPER"
  property string selectedKey: ""
  property string previewGroup: "SUPER"
  property bool keyCaptureActive: false
  property string assignmentSelectionKind: ""
  property string assignmentSelectionId: ""
  property string assignmentDefaultTitle: ""
  property string assignmentTitle: ""
  property string assignmentArguments: ""
  property string assignmentSearchQuery: ""
  property bool assignmentPopupOpen: false
  property string assignmentPopupOrigin: ""
  property real assignmentPopupAnchorY: 0
  property bool replacementArmed: false
  property bool removeConfirmationArmed: false
  property string shortcutEditorError: ""
  property bool resetConfirmationArmed: false
  property string registeredSearchQuery: ""
  property string registeredFilterGroup: ""

  readonly property var presentationSettingKeys: [
    "enabled", "position", "scale", "opacity", "followTheme", "groups",
    "hiddenBindingIds", "language"
  ]
  readonly property var groupOptions: [
    "SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT",
    "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT",
    "SUPER+SHIFT+ALT", "SUPER+CTRL+SHIFT+ALT"
  ]
  readonly property bool dirty: Object.keys(root.dirtyKeys).length > 0
  readonly property string uiLanguage: String(
    root.pendingSettings && root.pendingSettings.language || "en")
  readonly property bool keyboardFocusExclusive: settingsWindow.exclusiveKeyboardFocus
  readonly property var shortcutStatus: root.service ? root.service.shortcutStatus : null
  readonly property var registeredBindingCandidates: VisibilityModel.registeredBindings(
    root.service ? root.service.allBindings : [],
    root.shortcutStatus ? root.shortcutStatus.actions : [],
    root.registeredSearchQuery, root.registeredFilterGroup, root.uiLanguage,
    root.service && root.service.actionCatalog
      ? root.service.actionCatalog.items : [])
  property var registeredBindings: []
  readonly property var previewBindings: VisibilityModel.presentedBindings(
    root.service ? root.service.allBindings : [],
    root.shortcutStatus ? root.shortcutStatus.actions : [],
    root.service && root.service.actionCatalog
      ? root.service.actionCatalog.items : [],
    root.uiLanguage)
  readonly property int registeredBindingTotal: root.service
    ? root.arrayFrom(root.service.allBindings).length : 0
  readonly property bool registeredFilterActive:
    root.registeredSearchQuery.trim() !== "" || root.registeredFilterGroup !== ""
  readonly property var keyOptions: VisibilityModel.keyOptions(
    root.shortcutStatus, root.selectedGroup, root.uiLanguage)
  readonly property var selectedKeyOption: VisibilityModel.keyOption(
    root.shortcutStatus, root.selectedGroup, root.selectedKey, root.uiLanguage)
  readonly property var actionOptions: VisibilityModel.actionOptions(
    root.shortcutStatus, root.selectedKeyOption, root.uiLanguage)
  readonly property var selectedBinding: root.selectedKeyOption
    ? root.shortcutBindingById(root.selectedKeyOption.bindingId) : null
  readonly property var selectedAction: root.selectedKeyOption
    ? root.actionById(root.selectedKeyOption.actionId) : null
  readonly property bool shortcutBusy: root.service
    ? root.service.shortcutMutationActive === true : false
  readonly property bool settingsWriteBusy: root.service
    ? root.service.settingsSaveActive === true : false
  readonly property string serviceError: root.service ? String(root.service.lastError || "") : ""
  readonly property string shortcutDiscoveryError: root.shortcutStatus
    && root.shortcutStatus.discoveryError
      ? I18n.text(root.uiLanguage, "error.shortcutUnavailable", {}) : ""
  readonly property string displayedStatus: root.shortcutEditorError
    || root.saveError
    || root.shortcutDiscoveryError
    || root.serviceError
    || (root.shortcutBusy
      ? I18n.text(root.uiLanguage,
          root.service && root.service.shortcutMutationOperation === "remove"
            ? "shortcut.removing" : "shortcut.applying", {})
      : (root.awaitingSave
        ? I18n.text(root.uiLanguage, "common.saving", {})
        : (root.dirty
          ? I18n.text(root.uiLanguage, "common.unsavedChanges", {}) : "")))

  readonly property color background: Color.menu.background
  readonly property color foreground: Color.menu.text
  readonly property color accent: Color.accent
  readonly property color scrim: Color.menu.scrim
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
  readonly property string fontFamily: Style.font.menuFamily
  readonly property int contentMargin: Style.spacing.panelPadding
  readonly property int contentSpacing: Style.spacing.lg
  readonly property int settingsCardLogicalWidth: 960
  readonly property real settingsCardTargetWidth: Style.space(settingsCardLogicalWidth)
  readonly property url keyguideIconSource: Quickshell.iconPath("omarchy-keyguide", true)

  function defaultSettings() {
    return {
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
    }
  }

  function localeName(value) {
    const locales = {
      en: "en_US", ko: "ko_KR", ja: "ja_JP",
      zh_CN: "zh_CN", es: "es_ES"
    }
    return locales[String(value || "")] || "en_US"
  }

  function refreshRegisteredBindingOrder() {
    const source = root.registeredBindingCandidates || []
    registeredSortSource.clear()
    for (let index = 0; index < source.length; index += 1) {
      const binding = source[index]
      registeredSortSource.append({
        sourceIndex: index,
        title: String(binding && binding.description || ""),
        group: VisibilityModel.bindingGroup(binding),
        key: String(binding && binding.key || ""),
        bindingId: String(binding && binding.id || "")
      })
    }
    registeredSortProxy.invalidateSorter()
    const ordered = []
    for (let row = 0; row < registeredSortProxy.rowCount(); row += 1) {
      const proxyIndex = registeredSortProxy.index(row, 0)
      const sourceIndex = registeredSortProxy.mapToSource(proxyIndex).row
      if (sourceIndex >= 0 && sourceIndex < source.length)
        ordered.push(source[sourceIndex])
    }
    root.registeredBindings = ordered
  }

  function t(key, parameters) {
    return I18n.text(root.uiLanguage, key, parameters || {})
  }

  function languageIndex(language) {
    const choices = I18n.languages()
    for (let index = 0; index < choices.length; index += 1) {
      if (choices[index].id === String(language || ""))
        return index
    }
    return 0
  }

  function positionOptions() {
    return ["center", "top", "bottom", "left", "right"].map(function(value) {
      return {
        value: value,
        label: root.t("settings.position." + value, {})
      }
    })
  }

  function boundedPercent(value, minimum, maximum) {
    const parsed = Number(value)
    if (!Number.isFinite(parsed))
      return null
    return Math.max(minimum, Math.min(maximum, Math.round(parsed)))
  }

  function setScalePercent(value) {
    const percent = root.boundedPercent(value, 75, 150)
    if (percent === null)
      return false
    return root.updatePending("scale", percent / 100)
  }

  function setOpacityPercent(value) {
    const percent = root.boundedPercent(value, 20, 100)
    if (percent === null)
      return false
    return root.updatePending("opacity", percent / 100)
  }

  function assignmentPreviewText() {
    if (!root.assignmentSelectionId || !String(root.assignmentTitle || "").trim())
      return ""
    return root.t("shortcut.summary", {
      chord: root.groupLabel(root.selectedGroup) + " + " + root.selectedKey,
      action: root.assignmentDefaultTitle,
      title: String(root.assignmentTitle || "").trim()
    })
  }

  function deepCopy(value) {
    return JSON.parse(JSON.stringify(value))
  }

  function arrayFrom(value) {
    if (!value || typeof value.length !== "number" || typeof value === "string")
      return []
    const result = []
    for (let index = 0; index < value.length; index += 1)
      result.push(value[index])
    return result
  }

  function beginPending() {
    const source = root.service && root.service.settings ? root.service.settings : root.defaultSettings()
    root.savedSnapshot = root.deepCopy(source)
    root.pendingSettings = root.deepCopy(source)
    root.dirtyKeys = ({})
    root.saveError = ""
    root.awaitingSave = false
  }

  function updatePending(key, value) {
    if (root.presentationSettingKeys.indexOf(key) === -1)
      return false

    const next = root.deepCopy(root.pendingSettings)
    next[key] = root.deepCopy(value)
    root.pendingSettings = next

    const dirty = root.deepCopy(root.dirtyKeys)
    if (JSON.stringify(next[key]) === JSON.stringify(root.savedSnapshot[key])) {
      delete dirty[key]
    } else {
      dirty[key] = true
    }
    root.dirtyKeys = dirty
    root.saveError = ""
    return true
  }

  function setGroupEnabled(group, enabled) {
    if (root.groupOptions.indexOf(group) === -1)
      return false
    const patch = VisibilityModel.toggleGroup(
      root.pendingSettings,
      root.service ? root.service.allBindings : [],
      group,
      enabled
    )
    root.updatePending("groups", patch.groups)
    root.updatePending("hiddenBindingIds", patch.hiddenBindingIds)
    return true
  }

  function groupLabel(group) {
    return root.groupParts(group).join(" + ")
  }

  function groupParts(group) {
    return String(group || "").split("+").filter(function (modifier) {
      return modifier.length > 0
    }).map(function (modifier) {
      return I18n.modifier(root.uiLanguage, modifier)
    })
  }

  function groupEnabled(group) {
    return root.arrayFrom(root.pendingSettings.groups).indexOf(group) !== -1
  }

  function setBindingVisible(bindingId, visibleInHud) {
    const id = String(bindingId || "")
    if (!id)
      return false
    const patch = VisibilityModel.toggleBinding(
      root.pendingSettings,
      root.service ? root.service.allBindings : [],
      id,
      visibleInHud
    )
    root.updatePending("groups", patch.groups)
    root.updatePending("hiddenBindingIds", patch.hiddenBindingIds)
    return true
  }

  function shortcutBindingById(bindingId) {
    const bindings = root.service ? root.arrayFrom(root.service.allBindings) : []
    for (let index = 0; index < bindings.length; index += 1) {
      if (String(bindings[index].id || "") === String(bindingId || ""))
        return bindings[index]
    }
    return null
  }

  function managedBinding(bindingId) {
    const status = root.service ? root.service.shortcutStatus : null
    const ids = status ? root.arrayFrom(status.managedBindingIds) : []
    return ids.indexOf(String(bindingId || "")) !== -1
  }

  function actionById(actionId) {
    const actions = root.shortcutStatus
      ? root.arrayFrom(root.shortcutStatus.actions) : []
    for (let index = 0; index < actions.length; index += 1) {
      if (String(actions[index].id || "") === String(actionId || ""))
        return actions[index]
    }
    return null
  }

  function assignedContextText(option, action) {
    if (!option || option.state !== "assigned" || !action)
      return ""
    const chord = VisibilityModel.chordLabel(
      root.arrayFrom(action.modifiers), String(action.key || ""), root.uiLanguage)
    return root.t("shortcut.currentKey", {chord: chord}) + " · "
      + (root.managedBinding(String(option.bindingId || ""))
        ? root.t("shortcut.managedByKeyguide", {})
        : root.t("shortcut.omarchyDefault", {}))
  }

  function bindingGroup(binding) {
    const group = binding ? root.arrayFrom(binding.modifiers).join("+") : ""
    return root.groupOptions.indexOf(group) === -1 ? "" : group
  }

  function keyOptionForBinding(binding) {
    if (!binding)
      return null
    return VisibilityModel.keyOption(
      root.shortcutStatus, root.bindingGroup(binding), String(binding.key || ""),
      root.uiLanguage)
  }

  function bindingEditable(binding) {
    const option = root.keyOptionForBinding(binding)
    return option ? option.editable === true : binding && binding.editable === true
  }

  function bindingEditReason(binding) {
    const option = root.keyOptionForBinding(binding)
    return option ? String(option.editReason || "")
      : String(binding && binding.edit_reason || "")
  }

  function resetAssignmentDraft() {
    root.assignmentSelectionKind = ""
    root.assignmentSelectionId = ""
    root.assignmentDefaultTitle = ""
    root.assignmentTitle = ""
    root.assignmentArguments = ""
    root.assignmentSearchQuery = ""
    root.replacementArmed = false
    root.removeConfirmationArmed = false
    root.shortcutEditorError = ""
    if (actionSearch) {
      actionSearch.selectedId = ""
      actionSearch.selectionWasRemoved = false
      actionSearch.query = ""
    }
  }

  function cancelAssignment() {
    if (actionSearch)
      actionSearch.closeSearch()
    root.assignmentPopupOpen = false
    root.assignmentPopupOrigin = ""
    root.assignmentPopupAnchorY = 0
    root.selectedKey = ""
    root.keyCaptureActive = false
    root.resetAssignmentDraft()
    return true
  }

  function selectGroup(group) {
    const nextGroup = String(group || "")
    if (root.groupOptions.indexOf(nextGroup) === -1)
      return false
    root.cancelAssignment()
    root.selectedGroup = nextGroup
    root.previewGroup = nextGroup
    root.resetConfirmationArmed = false
    return true
  }

  function selectRegisteredGroup(group) {
    const nextGroup = String(group || "")
    if (root.groupOptions.indexOf(nextGroup) === -1)
      return false
    root.registeredFilterGroup = root.registeredFilterGroup === nextGroup
      ? "" : nextGroup
    return true
  }

  function resetRegisteredFilter() {
    root.registeredSearchQuery = ""
    root.registeredFilterGroup = ""
  }

  function catalogItemById(id) {
    const items = root.service && root.service.actionCatalog
      ? root.arrayFrom(root.service.actionCatalog.items) : []
    for (let index = 0; index < items.length; index += 1) {
      if (String(items[index].id || "") === String(id || ""))
        return items[index]
    }
    return null
  }

  function defaultTitleForSelection(kind, id, fallback) {
    if (kind === "action") {
      const action = root.actionById(id)
      if (action) {
        const original = String(action.title || fallback || "")
        const labelKey = String(action.labelKey || I18n.actionKey(original) || "")
        return I18n.actionTitle(root.uiLanguage, labelKey, original)
      }
    } else {
      const item = root.catalogItemById(id)
      if (item)
        return String(item.title || fallback || "")
    }
    return String(fallback || "")
  }

  function selectSearchResult(result) {
    const kind = String(result && result.kind || "")
    const id = String(result && result.id || "")
    if (["action", "application", "command"].indexOf(kind) === -1 || !id)
      return false
    const defaultTitle = String(result.title || result.englishTitle || "").trim()
    if (!defaultTitle)
      return false
    root.replacementArmed = false
    root.removeConfirmationArmed = false
    root.shortcutEditorError = ""
    root.assignmentSelectionKind = kind
    root.assignmentSelectionId = id
    root.assignmentDefaultTitle = defaultTitle
    root.assignmentTitle = defaultTitle
    if (kind !== "command")
      root.assignmentArguments = ""
    return true
  }

  function refreshAssignmentDefaultTitle() {
    if (!root.assignmentSelectionId)
      return
    const previousDefault = root.assignmentDefaultTitle
    const nextDefault = root.defaultTitleForSelection(
      root.assignmentSelectionKind, root.assignmentSelectionId, previousDefault)
    if (!nextDefault)
      return
    if (String(root.assignmentTitle || "").trim()
        === String(previousDefault || "").trim())
      root.assignmentTitle = nextDefault
    root.assignmentDefaultTitle = nextDefault
  }

  function setCatalogWatching(enabled) {
    if (root.service
        && typeof root.service.setActionCatalogWatching === "function")
      root.service.setActionCatalogWatching(enabled === true)
  }

  function openAssignmentPopup(anchorItem) {
    if (anchorItem) {
      const point = anchorItem.mapToItem(keyCatcher, 0, anchorItem.height / 2)
      root.assignmentPopupOrigin = "row"
      root.assignmentPopupAnchorY = point.y
    } else {
      root.assignmentPopupOrigin = "center"
      root.assignmentPopupAnchorY = card.height / 2
    }
    root.assignmentPopupOpen = true
    return true
  }

  function selectKey(key, anchorItem) {
    const option = VisibilityModel.keyOption(
      root.shortcutStatus, root.selectedGroup, String(key || ""), root.uiLanguage)
    if (!option)
      return false
    root.selectedKey = String(option.key || "")
    root.keyCaptureActive = false
    root.resetAssignmentDraft()
    if (option.state === "assigned") {
      if (option.editable === true && option.actionId) {
        const action = root.actionById(option.actionId)
        if (action) {
          const kind = String(action.selectionKind || "action")
          const id = String(action.selectionId || action.id || "")
          const defaultTitle = root.defaultTitleForSelection(
            kind, id, String(action.title || option.title || ""))
          root.assignmentSelectionKind = kind
          root.assignmentSelectionId = id
          root.assignmentDefaultTitle = defaultTitle
          root.assignmentTitle = String(action.titleOverride || defaultTitle)
        }
      }
    }
    root.openAssignmentPopup(anchorItem)
    Qt.callLater(function() {
      if (root.selectedKey === String(option.key || "")) {
        actionSearch.query = root.assignmentSearchQuery
        actionSearch.selectedId = root.assignmentSelectionId
        actionSearch.openSearch()
      }
    })
    return true
  }

  function openBinding(bindingId, anchorItem) {
    const binding = root.shortcutBindingById(bindingId)
    const group = root.bindingGroup(binding)
    if (!binding || !group)
      return false
    if (root.selectedGroup !== group && !root.selectGroup(group))
      return false
    return root.selectKey(String(binding.key || ""), anchorItem)
  }

  function beginKeyCapture() {
    if (root.shortcutBusy || root.awaitingSave)
      return false
    root.cancelAssignment()
    root.keyCaptureActive = true
    return true
  }

  function canonicalCapturedKey(key) {
    if (key >= Qt.Key_A && key <= Qt.Key_Z)
      return String.fromCharCode(key)
    if (key >= Qt.Key_0 && key <= Qt.Key_9)
      return String.fromCharCode(key)
    if (key >= Qt.Key_F1 && key <= Qt.Key_F12)
      return "F" + String(key - Qt.Key_F1 + 1)
    const names = ({})
    names[Qt.Key_Space] = "SPACE"
    names[Qt.Key_Return] = "RETURN"
    names[Qt.Key_Enter] = "RETURN"
    names[Qt.Key_Escape] = "ESCAPE"
    names[Qt.Key_Tab] = "TAB"
    names[Qt.Key_Backspace] = "BACKSPACE"
    names[Qt.Key_Delete] = "DELETE"
    names[Qt.Key_Home] = "HOME"
    names[Qt.Key_End] = "END"
    names[Qt.Key_Left] = "LEFT"
    names[Qt.Key_Right] = "RIGHT"
    names[Qt.Key_Up] = "UP"
    names[Qt.Key_Down] = "DOWN"
    names[Qt.Key_Comma] = "COMMA"
    names[Qt.Key_Period] = "PERIOD"
    names[Qt.Key_Slash] = "SLASH"
    names[Qt.Key_Minus] = "MINUS"
    names[Qt.Key_Equal] = "EQUAL"
    names[Qt.Key_Print] = "PRINT"
    return names[key] || ""
  }

  function captureKey(key, modifiers) {
    if (!root.keyCaptureActive)
      return false
    if (key === Qt.Key_Escape) {
      root.keyCaptureActive = false
      root.shortcutEditorError = ""
      return true
    }
    if (modifiers !== Qt.NoModifier)
      return false
    const captured = root.canonicalCapturedKey(key)
    if (!captured || !root.selectKey(captured))
      return false
    return true
  }

  function buildAssignmentRequest() {
    const option = root.selectedKeyOption
    const title = String(root.assignmentTitle || "").trim()
    const selectionKind = String(root.assignmentSelectionKind || "")
    const selectionId = String(root.assignmentSelectionId || "")
    if (!option || !title || !selectionId
        || ["action", "application", "command"].indexOf(selectionKind) === -1)
      return null
    const custom = title === String(root.assignmentDefaultTitle || "").trim()
      ? "" : title
    return {
      targetModifiers: root.selectedGroup.split("+"),
      targetKey: root.selectedKey,
      selectionKind: selectionKind,
      selectionId: selectionId,
      titleOverride: custom,
      customArguments: selectionKind === "command"
        ? String(root.assignmentArguments || "") : "",
      targetBindingId: option.state === "assigned"
        ? String(option.bindingId || "") : "",
      confirmReplace: option.state === "assigned" && root.replacementArmed
    }
  }

  function buildRemoveRequest() {
    const option = root.selectedKeyOption
    const binding = root.selectedBinding
    if (!option || option.state !== "assigned" || option.removable !== true
        || !binding || !root.removeConfirmationArmed)
      return null
    return {
      targetModifiers: root.selectedGroup.split("+"),
      targetKey: root.selectedKey,
      targetBindingId: String(option.bindingId || ""),
      title: String(binding.description || ""),
      dispatcher: String(binding.dispatcher || ""),
      argument: String(binding.argument || ""),
      confirmRemove: true
    }
  }

  function requestRemoveShortcut() {
    const option = root.selectedKeyOption
    if (root.shortcutBusy || root.settingsWriteBusy || root.awaitingSave
        || !option || option.state !== "assigned")
      return false
    if (option.removable !== true || !root.selectedBinding) {
      root.shortcutEditorError = root.t("error.removeUnavailable", {})
      return false
    }
    if (!root.removeConfirmationArmed) {
      root.removeConfirmationArmed = true
      root.replacementArmed = false
      root.shortcutEditorError = root.t("shortcut.removeConfirm", {
        title: String(option.title || root.t("common.action", {})),
        chord: VisibilityModel.chordLabel(
          root.selectedGroup.split("+"), root.selectedKey, root.uiLanguage)
      }) + " " + root.t("shortcut.removeAgain", {})
      return false
    }
    const request = root.buildRemoveRequest()
    if (!request || !root.service
        || typeof root.service.removeShortcut !== "function") {
      root.shortcutEditorError = root.t("error.shortcutUnavailable", {})
      return false
    }
    root.shortcutEditorError = ""
    if (!root.service.removeShortcut(request)) {
      root.shortcutEditorError = String(
        root.service.shortcutMutationError || root.t("error.removeFailed", {})
      )
      return false
    }
    return true
  }

  function submitAssignment() {
    const option = root.selectedKeyOption
    if (root.shortcutBusy || root.settingsWriteBusy || root.awaitingSave || !option)
      return false
    if (option.editable !== true) {
      root.shortcutEditorError = String(option.editReason
        || root.t("error.shortcutNotEditable", {}))
      return false
    }
    const request = root.buildAssignmentRequest()
    if (!request) {
      root.shortcutEditorError = root.t("error.chooseAction", {})
      return false
    }
    if (option.state === "assigned" && !root.replacementArmed) {
      root.replacementArmed = true
      root.shortcutEditorError = root.t("shortcut.replace", {
        oldTitle: String(option.title || root.t("common.action", {})),
        newTitle: root.assignmentTitle
      }) + " " + root.t("shortcut.replaceAgain", {})
      return false
    }
    if (!root.service || typeof root.service.assignShortcut !== "function") {
      root.shortcutEditorError = root.t("error.shortcutUnavailable", {})
      return false
    }
    root.shortcutEditorError = ""
    if (!root.service.assignShortcut(request)) {
      root.shortcutEditorError = String(
        root.service.shortcutMutationError || root.t("error.applyFailed", {})
      )
      return false
    }
    return true
  }

  function requestResetAll() {
    if (root.shortcutBusy || root.settingsWriteBusy || root.awaitingSave)
      return false
    if (!root.resetConfirmationArmed) {
      root.resetConfirmationArmed = true
      root.shortcutEditorError = root.t("settings.resetHelp", {})
      return false
    }
    if (!root.service || typeof root.service.resetAll !== "function") {
      root.shortcutEditorError = root.t("error.shortcutUnavailable", {})
      return false
    }
    root.shortcutEditorError = ""
    if (!root.service.resetAll()) {
      root.shortcutEditorError = String(
        root.service.shortcutMutationError || root.t("error.resetFailed", {})
      )
      return false
    }
    return true
  }

  function bindingVisible(bindingId) {
    return root.arrayFrom(root.pendingSettings.hiddenBindingIds).indexOf(String(bindingId || "")) === -1
  }

  function buildPatch() {
    const patch = {}
    for (const key in root.dirtyKeys)
      patch[key] = root.deepCopy(root.pendingSettings[key])
    return patch
  }

  function open(payloadJson) {
    let payload = ({})
    try {
      payload = JSON.parse(payloadJson || "{}") || ({})
    } catch (error) {
      payload = ({})
    }
    if (payload.mode !== undefined && payload.mode !== "settings")
      return false

    root.beginPending()
    root.selectGroup("SUPER")
    root.resetRegisteredFilter()
    root.opened = true
    root.setCatalogWatching(true)
    Qt.callLater(function () {
      keyCatcher.forceActiveFocus()
    })
    return true
  }

  function close() {
    root.setCatalogWatching(false)
    root.opened = false
    root.selectGroup("SUPER")
    root.resetRegisteredFilter()
    root.beginPending()
  }

  function dismiss() {
    if (root.shortcutBusy)
      return
    root.setCatalogWatching(false)
    root.opened = false
    root.selectGroup("SUPER")
    root.resetRegisteredFilter()
    root.beginPending()
    if (root.shell && typeof root.shell.hide === "function") {
      root.shell.hide((root.manifest && root.manifest.id) || "mrai.keyguide")
    }
  }

  function save() {
    if (root.shortcutBusy)
      return false
    if (!root.dirty) {
      root.dismiss()
      return true
    }
    if (!root.service || typeof root.service.patchSettings !== "function") {
      root.saveError = root.t("error.settingsUnavailable", {})
      return false
    }
    root.awaitingSave = true
    root.saveError = ""
    if (!root.service.patchSettings(root.buildPatch())) {
      root.awaitingSave = false
      root.saveError = String(root.service.settingsSaveError
        || root.t("error.settingsSave", {}))
      return false
    }
    return true
  }

  function handleKeyPress(key, modifiers) {
    if (root.awaitingSave || root.shortcutBusy)
      return false
    if ((modifiers & Qt.ControlModifier) && key === Qt.Key_S) {
      root.save()
      return true
    }
    if (key === Qt.Key_Escape) {
      if (root.keyCaptureActive)
        return root.captureKey(key, modifiers)
      if (root.selectedKey) {
        root.cancelAssignment()
        return true
      }
      root.dismiss()
      return true
    }
    if (root.keyCaptureActive)
      return root.captureKey(key, modifiers)
    return false
  }

  onServiceChanged: if (!root.opened)
    root.beginPending()
  onRegisteredBindingCandidatesChanged: root.refreshRegisteredBindingOrder()
  onUiLanguageChanged: {
    root.refreshAssignmentDefaultTitle()
    root.refreshRegisteredBindingOrder()
  }
  Component.onCompleted: {
    root.beginPending()
    root.refreshRegisteredBindingOrder()
  }

  ListModel {
    id: registeredSortSource
  }

  SortFilterProxyModel {
    id: registeredSortProxy

    model: registeredSortSource
    sorters: [
      StringSorter {
        roleName: "title"
        locale: Qt.locale(root.localeName(root.uiLanguage))
        caseSensitivity: Qt.CaseInsensitive
        numericMode: true
        priority: 0
      },
      StringSorter {
        roleName: "group"
        locale: Qt.locale("en_US")
        caseSensitivity: Qt.CaseInsensitive
        numericMode: true
        priority: 1
      },
      StringSorter {
        roleName: "key"
        locale: Qt.locale("en_US")
        caseSensitivity: Qt.CaseInsensitive
        numericMode: true
        priority: 2
      },
      StringSorter {
        roleName: "bindingId"
        locale: Qt.locale("en_US")
        caseSensitivity: Qt.CaseInsensitive
        numericMode: true
        priority: 3
      }
    ]
  }

  component ShortcutChord: Item {
    id: chordRoot

    property var parts: []
    property color foreground: root.foreground
    property color mutedForeground: Qt.darker(root.foreground, 1.45)
    property string fontFamily: root.fontFamily

    implicitWidth: chordRow.implicitWidth
    implicitHeight: 28

    Row {
      id: chordRow

      objectName: "shortcutChordParts"
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Repeater {
        model: chordRoot.parts

        delegate: Row {
          id: chordPart

          required property int index
          required property var modelData
          height: 28
          spacing: 4

          Rectangle {
            width: Math.max(34, chordText.implicitWidth + 16)
            height: 28
            color: "#18ffffff"
            border.color: "#45ffffff"
            border.width: 1
            radius: 6

            Text {
              id: chordText

              anchors.centerIn: parent
              text: String(chordPart.modelData || "")
              color: chordRoot.foreground
              font.family: chordRoot.fontFamily
              font.pixelSize: 11
              font.bold: true
            }
          }

          Text {
            visible: chordPart.index < chordRoot.parts.length - 1
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            color: chordRoot.mutedForeground
            font.family: chordRoot.fontFamily
            font.pixelSize: 11
            font.bold: true
          }
        }
      }
    }
  }

  Connections {
    target: root.service
    enabled: root.service !== null

    function onSettingsSaveFinished(success, errorMessage) {
      if (!root.awaitingSave)
        return
      root.awaitingSave = false
      if (!success) {
        root.saveError = String(errorMessage || root.t("error.settingsSave", {}))
        return
      }
      root.dismiss()
    }

    function onShortcutMutationFinished(success, errorMessage, operation) {
      if (!success) {
        root.shortcutEditorError = String(errorMessage
          || root.t("error.applyFailed", {}))
        return
      }
      root.shortcutEditorError = ""
      root.resetConfirmationArmed = false
      root.cancelAssignment()
      if (operation === "reset-all")
        root.beginPending()
    }

    function onActionCatalogChanged() {
      root.refreshAssignmentDefaultTitle()
    }
  }

  PanelWindow {
    id: settingsWindow

    objectName: "settingsWindow"

    readonly property bool exclusiveKeyboardFocus: WlrLayershell.keyboardFocus === WlrKeyboardFocus.Exclusive

    visible: root.opened
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    WlrLayershell.namespace: "mrai-keyguide-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened
      ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.opened && !root.awaitingSave && !root.shortcutBusy
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card

      objectName: "settingsCard"
      width: Math.min(root.settingsCardTargetWidth,
        settingsWindow.width - Style.gapsOut * 2)
      height: Math.min(Style.space(760), settingsWindow.height - Style.gapsOut * 2)
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      radius: Style.cornerRadius
      padding: root.contentMargin
      clip: true

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Item {
        id: keyCatcher

        objectName: "settingsKeyCatcher"
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function (event) {
          if (root.handleKeyPress(event.key, event.modifiers))
            event.accepted = true
        }

        Column {
          id: content

          objectName: "settingsContent"
          x: card.contentLeftInset
          y: card.contentTopInset
          width: card.width - card.contentLeftInset - card.contentRightInset
          height: card.height - card.contentTopInset - card.contentBottomInset
          spacing: root.contentSpacing

          Row {
            width: parent.width
            height: Math.max(Style.space(44), titleColumn.implicitHeight)
            spacing: Style.spacing.md

            Item {
              width: parent.height
              height: parent.height

              Image {
                id: keyguideSettingsIcon
                objectName: "keyguideSettingsIcon"
                anchors.fill: parent
                source: root.keyguideIconSource
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
              }

              Text {
                objectName: "keyguideSettingsIconFallback"
                anchors.fill: parent
                visible: keyguideSettingsIcon.status !== Image.Ready
                text: "⌨"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }

            Column {
              id: titleColumn
              width: parent.width - hudTab.width - parent.height - parent.spacing * 2
              spacing: Style.spacing.xs

              Text {
                objectName: "settingsTitleText"
                width: parent.width
                text: root.t("settings.title", {})
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                objectName: "settingsSubtitleText"
                width: parent.width
                text: root.t("settings.subtitle", {})
                color: Qt.darker(root.foreground, 1.45)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Button {
              id: hudTab
              text: root.t("settings.hud", {})
              selected: true
              bordered: true
              foreground: root.foreground
              background: root.background
              accent: root.accent
              fontFamily: root.fontFamily
            }
          }

          Item {
            id: settingsDetailLayout

            objectName: "settingsDetailLayout"
            width: parent.width
            height: Math.max(0, parent.height - y - footer.height - parent.spacing)

            Flickable {
              id: settingsScroll

              objectName: "settingsScroll"
              width: parent.width
              height: parent.height
              contentWidth: width
              contentHeight: settingsColumn.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              QQC.ScrollBar.vertical: QQC.ScrollBar {}

              Column {
                id: settingsColumn
                objectName: "settingsColumn"
                width: settingsScroll.width - Style.spacing.md
                spacing: Style.spacing.md

                Column {
                  width: parent.width
                  spacing: Style.spacing.xs

                  Text {
                    width: parent.width
                    text: root.t("language.label", {})
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }

                  Text {
                    width: parent.width
                    text: root.t("language.help", {})
                    color: Qt.darker(root.foreground, 1.45)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    wrapMode: Text.WordWrap
                  }

                  QQC.ComboBox {
                    id: settingsLanguagePicker
                    objectName: "settingsLanguagePicker"
                    width: Math.min(parent.width, 320)
                    model: I18n.languages()
                    textRole: "name"
                    currentIndex: root.languageIndex(root.uiLanguage)
                    enabled: !root.awaitingSave && !root.shortcutBusy
                    onActivated: function(index) {
                      const choices = I18n.languages()
                      if (index >= 0 && index < choices.length)
                        root.updatePending("language", choices[index].id)
                    }
                  }
                }

                Toggle {
                  width: parent.width
                  label: root.t("common.enabled", {})
                  description: root.t("settings.hudEnabledHelp", {})
                  checked: root.pendingSettings.enabled === true
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                  onClicked: root.updatePending("enabled", !root.pendingSettings.enabled)
                }

                Column {
                  width: parent.width
                  spacing: Style.spacing.sm

                  Text {
                    text: root.t("settings.position", {})
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }

                  ButtonGroup {
                    options: root.positionOptions()
                    value: String(root.pendingSettings.position || "center")
                    foreground: root.foreground
                    background: root.background
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onChanged: function (value) {
                      root.updatePending("position", value)
                    }
                  }
                }

                Column {
                  width: parent.width
                  spacing: Style.spacing.sm

                  Text {
                    text: root.t("settings.scale", {})
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }

                  Row {
                    width: parent.width
                    spacing: Style.spacing.sm

                    Repeater {
                      model: [75, 100, 125, 150]

                      Button {
                        required property int modelData

                        objectName: "settingsScalePreset" + modelData
                        text: modelData + "%"
                        selected: Math.round(
                          Number(root.pendingSettings.scale || 1) * 100) === modelData
                        bordered: true
                        enabled: !root.awaitingSave && !root.shortcutBusy
                        foreground: root.foreground
                        background: root.background
                        accent: root.accent
                        fontFamily: root.fontFamily
                        onClicked: root.setScalePercent(modelData)
                      }
                    }

                    QQC.TextField {
                      id: settingsScaleInput

                      objectName: "settingsScaleInput"
                      width: 84
                      text: String(Math.round(
                        Number(root.pendingSettings.scale || 1) * 100))
                      horizontalAlignment: TextInput.AlignHCenter
                      inputMethodHints: Qt.ImhDigitsOnly
                      validator: IntValidator { bottom: 1; top: 999 }
                      enabled: !root.awaitingSave && !root.shortcutBusy
                      onEditingFinished: {
                        if (!root.setScalePercent(text))
                          text = String(Math.round(
                            Number(root.pendingSettings.scale || 1) * 100))
                      }
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "%"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }
                  }
                }

                Column {
                  width: parent.width
                  spacing: Style.spacing.sm

                  Text {
                    text: root.t("settings.opacity", {})
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.bold: true
                  }

                  Row {
                    width: parent.width
                    spacing: Style.spacing.sm

                    Repeater {
                      model: [50, 75, 90, 100]

                      Button {
                        required property int modelData

                        objectName: "settingsOpacityPreset" + modelData
                        text: modelData + "%"
                        selected: Math.round(
                          Number(root.pendingSettings.opacity || 0.94) * 100) === modelData
                        bordered: true
                        enabled: !root.awaitingSave && !root.shortcutBusy
                        foreground: root.foreground
                        background: root.background
                        accent: root.accent
                        fontFamily: root.fontFamily
                        onClicked: root.setOpacityPercent(modelData)
                    }
                    }

                    QQC.TextField {
                      id: settingsOpacityInput

                      objectName: "settingsOpacityInput"
                      width: 84
                      text: String(Math.round(
                        Number(root.pendingSettings.opacity || 0.94) * 100))
                      horizontalAlignment: TextInput.AlignHCenter
                      inputMethodHints: Qt.ImhDigitsOnly
                      validator: IntValidator { bottom: 1; top: 999 }
                      enabled: !root.awaitingSave && !root.shortcutBusy
                      onEditingFinished: {
                        if (!root.setOpacityPercent(text))
                          text = String(Math.round(
                            Number(root.pendingSettings.opacity || 0.94) * 100))
                      }
                    }

                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      text: "%"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                    }
                  }
                }

                Toggle {
                  width: parent.width
                  label: root.t("settings.followTheme", {})
                  description: root.t("settings.followThemeHelp", {})
                  checked: root.pendingSettings.followTheme !== false
                  foreground: root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                  onClicked: root.updatePending("followTheme", !root.pendingSettings.followTheme)
                }

                Rectangle {
                  id: settingsPreviewPanel

                  objectName: "settingsPreviewPanel"
                  width: parent.width
                  height: previewPanelColumn.implicitHeight + Style.spacing.md * 2
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.045)
                  border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                  border.width: 1
                  radius: Style.cornerRadius

                  Column {
                    id: previewPanelColumn

                    x: Style.spacing.md
                    y: Style.spacing.md
                    width: parent.width - Style.spacing.md * 2
                    spacing: Style.spacing.sm

                    Text {
                      width: parent.width
                      text: root.t("settings.previewTitle", {})
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.subtitle
                      font.bold: true
                      horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                      width: parent.width
                      text: root.t("settings.previewHelp", {})
                      color: Qt.darker(root.foreground, 1.45)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignHCenter
                      wrapMode: Text.WordWrap
                    }

                    Components.HudPreview {
                      id: settingsHudPreview

                      objectName: "settingsHudPreview"
                      width: parent.width
                      height: settingsHudPreview.previewAnnotationHeight + Math.max(Style.space(220),
                        Math.min(Style.space(340), Math.round(width * 0.46)))
                      settings: root.pendingSettings
                      language: root.uiLanguage
                      bindings: root.previewBindings
                      previewModifiers: root.previewGroup.split("+")
                      themeBackground: Color.popups.background
                      themeForeground: Color.popups.text
                      themeAccent: root.accent
                      themeBorder: Color.popups.border
                      fontFamily: root.fontFamily
                      iconResolver: function(iconName) {
                        return Quickshell.iconPath(iconName, true)
                      }
                    }
                  }
                }

                Item {
                  objectName: "shortcutSectionGap"
                  width: 1
                  height: Style.spacing.huge
                }

                Rectangle {
                  id: shortcutManagementPanel

                  objectName: "shortcutManagementPanel"
                  width: parent.width
                  height: shortcutManagementContent.implicitHeight + Style.spacing.md * 2
                  color: Qt.rgba(root.foreground.r, root.foreground.g,
                    root.foreground.b, 0.025)
                  border.color: Qt.rgba(root.accent.r, root.accent.g,
                    root.accent.b, 0.34)
                  border.width: 1
                  radius: Style.cornerRadius

                  Column {
                    id: shortcutManagementContent

                    objectName: "shortcutManagementContent"
                    x: Style.spacing.md
                    y: Style.spacing.md
                    width: parent.width - Style.spacing.md * 2
                    spacing: Style.spacing.sm

                    Text {
                      objectName: "shortcutManagementTitle"
                      width: parent.width
                      text: root.t("shortcut.management", {})
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.subtitle
                      font.bold: true
                    }

                    Text {
                      width: parent.width
                      text: root.t("shortcut.managementHelp", {})
                      color: Qt.darker(root.foreground, 1.45)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    Item {
                      id: shortcutChooser

                      objectName: "shortcutChooser"
                      width: parent.width
                      height: compactLayout
                        ? shortcutGroupField.height + gap
                          + Math.max(shortcutKeyField.height,
                            shortcutCaptureField.height)
                        : Math.max(shortcutGroupField.height,
                            shortcutKeyField.height,
                            shortcutCaptureField.height)
                      readonly property bool compactLayout: width < 720
                      readonly property real gap: Style.spacing.sm
                      readonly property real fieldGap: Style.spacing.controlGap
                      readonly property real controlHeight: Style.space(44)

                      Item {
                        id: shortcutGroupField

                        objectName: "shortcutGroupField"
                        x: 0
                        y: 0
                        width: Math.min(280, Math.max(120,
                          shortcutGroupWidthProbe.implicitWidth + 46))
                        height: shortcutGroupFieldLabel.implicitHeight
                          + shortcutChooser.fieldGap + shortcutGroupPicker.height

                        ShortcutChord {
                          id: shortcutGroupWidthProbe

                          visible: false
                          parts: root.groupParts(root.selectedGroup)
                          foreground: root.foreground
                          fontFamily: root.fontFamily
                        }

                        Text {
                          id: shortcutGroupFieldLabel

                          objectName: "shortcutGroupFieldLabel"
                          width: parent.width
                          text: root.t("shortcut.modifierGroup", {})
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        QQC.ComboBox {
                          id: shortcutGroupPicker

                          objectName: "shortcutGroupPicker"
                          x: 0
                          y: shortcutGroupFieldLabel.implicitHeight
                            + shortcutChooser.fieldGap
                          width: parent.width
                          height: shortcutChooser.controlHeight
                          leftPadding: Style.spacing.controlPaddingX
                          rightPadding: Style.spacing.controlPaddingX + Style.space(18)
                          model: root.groupOptions
                          currentIndex: root.groupOptions.indexOf(root.selectedGroup)
                          displayText: root.groupLabel(root.selectedGroup)
                          enabled: !root.shortcutBusy && !root.awaitingSave
                          popup.width: 280
                          contentItem: ShortcutChord {
                            objectName: "shortcutGroupPickerChord"
                            clip: true
                            parts: root.groupParts(root.selectedGroup)
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                          }
                          background: Rectangle {
                            color: Qt.rgba(root.accent.r, root.accent.g,
                              root.accent.b, 0.1)
                            border.color: Qt.rgba(root.accent.r, root.accent.g,
                              root.accent.b, 0.8)
                            border.width: 2
                            radius: 7
                          }
                          delegate: QQC.ItemDelegate {
                            id: groupDelegate

                            required property int index
                            required property var modelData
                            width: Math.min(272, Math.max(112,
                              groupDelegateChord.implicitWidth + 34))
                            height: shortcutChooser.controlHeight
                            leftPadding: Style.spacing.controlPaddingX
                            rightPadding: Style.spacing.controlPaddingX
                            contentItem: ShortcutChord {
                              id: groupDelegateChord

                              clip: true
                              parts: root.groupParts(String(groupDelegate.modelData || ""))
                              foreground: root.foreground
                              fontFamily: root.fontFamily
                            }
                            background: Rectangle {
                              color: groupDelegate.highlighted
                                ? Qt.rgba(root.accent.r, root.accent.g,
                                    root.accent.b, 0.18)
                                : "transparent"
                              border.color: groupDelegate.highlighted
                                ? Qt.rgba(root.accent.r, root.accent.g,
                                    root.accent.b, 0.55)
                                : "transparent"
                              border.width: 1
                              radius: 6
                            }
                            highlighted: shortcutGroupPicker.highlightedIndex === index
                          }
                          onActivated: function(index) {
                            root.selectGroup(String(root.groupOptions[index] || ""))
                          }
                        }
                      }

                      Item {
                        id: shortcutKeyField

                        objectName: "shortcutKeyField"
                        x: shortcutChooser.compactLayout ? 0
                          : shortcutGroupField.width + shortcutChooser.gap
                        y: shortcutChooser.compactLayout
                          ? shortcutGroupField.height + shortcutChooser.gap : 0
                        width: shortcutChooser.compactLayout
                          ? Math.round((parent.width - shortcutChooser.gap) * 0.62)
                          : Math.max(1, parent.width - shortcutGroupField.width
                              - 200 - shortcutChooser.gap * 2)
                        height: shortcutKeyFieldLabel.implicitHeight
                          + shortcutChooser.fieldGap + shortcutKeyPicker.height

                        Text {
                          id: shortcutKeyFieldLabel

                          objectName: "shortcutKeyFieldLabel"
                          width: parent.width
                          text: root.t("shortcut.key", {})
                          color: Qt.darker(root.foreground, 1.35)
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        QQC.ComboBox {
                          id: shortcutKeyPicker

                          objectName: "shortcutKeyPicker"
                          x: 0
                          y: shortcutKeyFieldLabel.implicitHeight
                            + shortcutChooser.fieldGap
                          width: parent.width
                          height: shortcutChooser.controlHeight
                          model: root.keyOptions
                          textRole: "label"
                          valueRole: "key"
                          currentIndex: root.selectedKey
                            ? shortcutKeyPicker.indexOfValue(root.selectedKey) : -1
                          displayText: root.selectedKeyOption
                            ? String(root.selectedKeyOption.label || "") : ""
                          enabled: !root.shortcutBusy && !root.awaitingSave
                          onActivated: function(index) {
                            const option = root.keyOptions[index]
                            if (option)
                              root.selectKey(String(option.key || ""))
                          }
                        }
                      }

                      Item {
                        id: shortcutCaptureField

                        objectName: "shortcutCaptureField"
                        x: shortcutKeyField.x + shortcutKeyField.width
                          + shortcutChooser.gap
                        y: shortcutKeyField.y
                        width: shortcutChooser.compactLayout
                          ? Math.max(1, parent.width - x) : 200
                        height: shortcutCaptureFieldLabel.implicitHeight
                          + shortcutChooser.fieldGap
                          + shortcutKeyCaptureField.height

                        Text {
                          id: shortcutCaptureFieldLabel

                          objectName: "shortcutCaptureFieldLabel"
                          width: parent.width
                          text: root.t("shortcut.keyCapture", {})
                          color: Qt.darker(root.foreground, 1.35)
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                        }

                        QQC.TextField {
                          id: shortcutKeyCaptureField

                          objectName: "shortcutKeyCaptureField"
                          x: 0
                          y: shortcutCaptureFieldLabel.implicitHeight
                            + shortcutChooser.fieldGap
                          width: parent.width
                          height: shortcutChooser.controlHeight
                          readOnly: true
                          enabled: !root.shortcutBusy && !root.awaitingSave
                          placeholderText: root.t("shortcut.pressKey", {})
                          text: root.keyCaptureActive
                            ? root.t("shortcut.pressKey", {}) : root.selectedKey

                          TapHandler {
                            onTapped: {
                              root.beginKeyCapture()
                              shortcutKeyCaptureField.forceActiveFocus()
                            }
                          }
                        }
                      }
                    }
                  }
                }

                Rectangle {
                  id: assignmentPopupScrim

                  objectName: "shortcutAssignmentPopupScrim"
                  parent: keyCatcher
                  anchors.fill: parent
                  z: 100
                  visible: root.assignmentPopupOpen
                  color: Qt.rgba(0, 0, 0, 0.48)

                  MouseArea {
                    anchors.fill: parent
                    enabled: assignmentPopupScrim.visible
                    onClicked: root.cancelAssignment()
                  }
                }

                Rectangle {
                  id: shortcutAssignmentPanel

                  objectName: "shortcutAssignmentPopup"
                  parent: keyCatcher
                  z: 101
                  readonly property real popupMargin: Style.spacing.lg
                  readonly property real popupPadding: Style.spacing.md
                  width: Math.min(Style.space(840),
                    card.width - popupMargin * 2)
                  height: Math.min(
                    assignmentColumn.implicitHeight + popupPadding * 2,
                    card.height - popupMargin * 2)
                  x: Math.round((card.width - width) / 2)
                  y: root.assignmentPopupOrigin === "row"
                    ? Math.max(popupMargin, Math.min(
                        card.height - height - popupMargin,
                        root.assignmentPopupAnchorY - height / 2))
                    : Math.round((card.height - height) / 2)
                  visible: root.assignmentPopupOpen && root.selectedKey !== ""
                  clip: true
                  color: root.background
                  border.color: Qt.rgba(root.accent.r, root.accent.g,
                    root.accent.b, 0.75)
                  border.width: 1
                  radius: Style.cornerRadius

                  Flickable {
                    id: assignmentPopupScroll

                    objectName: "shortcutAssignmentPopupScroll"
                    x: shortcutAssignmentPanel.popupPadding
                    y: shortcutAssignmentPanel.popupPadding
                    width: parent.width - shortcutAssignmentPanel.popupPadding * 2
                    height: parent.height - shortcutAssignmentPanel.popupPadding * 2
                    contentWidth: width
                    contentHeight: assignmentColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    QQC.ScrollBar.vertical: QQC.ScrollBar {}

                    Column {
                      id: assignmentColumn
                      objectName: "shortcutAssignmentColumn"
                      width: assignmentPopupScroll.width - Style.spacing.sm
                      spacing: Style.spacing.sm

                    Text {
                      objectName: "shortcutAssignmentHeading"
                      width: parent.width
                      text: root.t("shortcut.assignmentHeading", {})
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.subtitle
                      font.bold: true
                    }

                    Row {
                      width: parent.width
                      height: 30
                      spacing: Style.spacing.sm

                      ShortcutChord {
                        objectName: "shortcutSelectedChord"
                        parts: root.groupParts(root.selectedGroup).concat(
                          root.selectedKey ? [root.selectedKey] : [])
                        foreground: root.foreground
                        fontFamily: root.fontFamily
                      }

                      Text {
                        visible: root.selectedKeyOption
                          && root.selectedKeyOption.state === "free"
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.t("common.available", {})
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    Text {
                      width: parent.width
                      visible: root.selectedKeyOption
                        && root.selectedKeyOption.state === "assigned"
                      text: {
                        const binding = root.selectedBinding
                        const kind = String(binding && binding.action_kind || binding && binding.dispatcher || "Action")
                        const argument = String(binding && binding.action_argument || binding && binding.argument || "")
                        return kind.toUpperCase() + (argument ? " · " + argument : "")
                      }
                      color: Qt.darker(root.foreground, 1.35)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle
                    }

                    Text {
                      width: parent.width
                      visible: root.selectedKeyOption
                        && root.selectedKeyOption.state === "assigned"
                        && root.selectedAction !== null
                      text: root.assignedContextText(
                        root.selectedKeyOption, root.selectedAction)
                      color: Qt.darker(root.foreground, 1.35)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width
                      visible: root.selectedKeyOption
                        && root.selectedKeyOption.editable !== true
                      text: root.selectedKeyOption
                        ? String(root.selectedKeyOption.editReason
                          || root.t("error.shortcutNotEditable", {})) : ""
                      color: Color.urgent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    Text {
                      width: parent.width
                      text: root.t("shortcut.actionTitle", {})
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    Text {
                      width: parent.width
                      text: root.t("shortcut.actionTitleHelp", {})
                      color: Qt.darker(root.foreground, 1.45)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    QQC.TextField {
                      id: shortcutAssignmentTitle
                      objectName: "shortcutAssignmentTitle"
                      width: parent.width
                      enabled: root.selectedKeyOption
                        && root.selectedKeyOption.editable === true
                        && !root.shortcutBusy && !root.awaitingSave
                      placeholderText: root.t("shortcut.actionTitle", {})
                      text: root.assignmentTitle
                      onTextEdited: {
                        root.assignmentTitle = text
                        root.replacementArmed = false
                        root.removeConfirmationArmed = false
                      }
                    }

                    Components.ActionSearch {
                      id: actionSearch

                      objectName: "shortcutActionSearch"
                      width: parent.width
                      height: 360
                      language: root.uiLanguage
                      actions: root.shortcutStatus
                        ? root.shortcutStatus.actions : []
                      catalogItems: root.service && root.service.actionCatalog
                        ? root.service.actionCatalog.items : []
                      busy: root.service
                        ? root.service.actionCatalogLoading === true : false
                      errorText: root.service
                        ? String(root.service.actionCatalogError || "") : ""
                      warningCount: root.service
                        ? root.arrayFrom(root.service.actionCatalogWarnings).length : 0
                      enabled: root.selectedKeyOption
                        && root.selectedKeyOption.editable === true
                        && !root.shortcutBusy && !root.awaitingSave
                      keyboardFocusOwned: root.keyboardFocusExclusive
                      foreground: root.foreground
                      mutedForeground: Qt.darker(root.foreground, 1.45)
                      surface: root.background
                      accent: root.accent
                      errorForeground: Color.urgent
                      fontFamily: root.fontFamily
                      iconResolver: function(iconName) {
                        return Quickshell.iconPath(iconName, true)
                      }
                      onQueryChanged: root.assignmentSearchQuery = query
                      onSelected: function(result) {
                        root.selectSearchResult(result)
                      }
                      onWatchingChanged: function(watching) {
                        if (watching)
                          root.setCatalogWatching(true)
                      }
                      onSelectionWasRemovedChanged: {
                        if (selectionWasRemoved && root.assignmentSelectionId) {
                          root.assignmentSelectionKind = ""
                          root.assignmentSelectionId = ""
                          root.assignmentDefaultTitle = ""
                          root.assignmentTitle = ""
                          root.assignmentArguments = ""
                          root.replacementArmed = false
                          root.removeConfirmationArmed = false
                        }
                      }
                    }

                    Text {
                      width: parent.width
                      visible: root.assignmentSelectionKind === "command"
                      text: root.t("search.commandHelp", {})
                      color: Qt.darker(root.foreground, 1.45)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    QQC.TextField {
                      id: shortcutAssignmentArguments

                      objectName: "shortcutAssignmentArguments"
                      width: parent.width
                      visible: root.assignmentSelectionKind === "command"
                      enabled: !root.shortcutBusy && !root.awaitingSave
                      placeholderText: root.t("shortcut.arguments", {})
                      text: root.assignmentArguments
                      onTextEdited: {
                        root.assignmentArguments = text
                        root.replacementArmed = false
                        root.removeConfirmationArmed = false
                      }
                    }

                    Text {
                      objectName: "shortcutAssignmentPreview"
                      width: parent.width
                      visible: root.assignmentPreviewText() !== ""
                      text: root.assignmentPreviewText()
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    Text {
                      width: parent.width
                      visible: root.shortcutEditorError !== ""
                      text: root.shortcutEditorError
                      color: Color.urgent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    Row {
                      width: parent.width
                      spacing: Style.spacing.sm

                      Button {
                        id: shortcutAssignmentApply
                        objectName: "shortcutAssignmentApply"
                        text: root.selectedKeyOption
                          && root.selectedKeyOption.state === "assigned"
                          ? (root.replacementArmed
                            ? root.t("common.confirm", {})
                            : root.t("common.change", {}))
                          : root.t("common.register", {})
                        selected: true
                        bordered: true
                        enabled: root.selectedKeyOption
                          && root.selectedKeyOption.editable === true
                          && !root.shortcutBusy && !root.settingsWriteBusy
                          && !root.awaitingSave
                        foreground: root.foreground
                        background: root.background
                        accent: root.accent
                        fontFamily: root.fontFamily
                        onClicked: root.submitAssignment()
                      }

                      Button {
                        id: shortcutAssignmentRemove

                        objectName: "shortcutAssignmentRemove"
                        text: root.t("common.remove", {})
                        selected: root.removeConfirmationArmed
                        bordered: true
                        enabled: root.selectedKeyOption
                          && root.selectedKeyOption.state === "assigned"
                          && root.selectedKeyOption.removable === true
                          && root.selectedBinding !== null
                          && !root.shortcutBusy && !root.settingsWriteBusy
                          && !root.awaitingSave
                        foreground: root.foreground
                        background: root.background
                        accent: Color.urgent
                        fontFamily: root.fontFamily
                        onClicked: root.requestRemoveShortcut()
                      }

                      Button {
                        id: shortcutAssignmentCancel

                        objectName: "shortcutAssignmentCancel"
                        text: root.t("common.cancel", {})
                        bordered: true
                        enabled: !root.shortcutBusy && !root.awaitingSave
                        foreground: root.foreground
                        background: root.background
                        accent: root.accent
                        fontFamily: root.fontFamily
                        onClicked: root.cancelAssignment()
                      }
                    }
                  }
                }

                }

                Item {
                  objectName: "shortcutRegisteredGap"
                  width: 1
                  height: Style.spacing.md
                }

                Rectangle {
                  id: registeredFilterCard

                  objectName: "shortcutRegisteredFilter"
                  width: parent.width
                  height: registeredFilterColumn.implicitHeight
                    + Style.spacing.md * 2
                  color: Qt.rgba(root.foreground.r, root.foreground.g,
                    root.foreground.b, 0.025)
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g,
                    root.foreground.b, 0.18)
                  border.width: 1
                  radius: Style.cornerRadius

                  Column {
                    id: registeredFilterColumn

                    x: Style.spacing.md
                    y: Style.spacing.md
                    width: parent.width - Style.spacing.md * 2
                    spacing: Style.spacing.sm

                    Text {
                      width: parent.width
                      text: root.t("shortcut.filterTitle", {})
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.subtitle
                      font.bold: true
                    }

                    Text {
                      width: parent.width
                      text: root.t("shortcut.filterHelp", {})
                      color: Qt.darker(root.foreground, 1.45)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    QQC.TextField {
                      id: registeredSearchInput

                      objectName: "shortcutRegisteredSearchInput"
                      width: parent.width
                      height: Style.space(44)
                      enabled: !root.shortcutBusy && !root.awaitingSave
                      placeholderText: root.t("shortcut.filterPlaceholder", {})
                      placeholderTextColor: Qt.darker(root.foreground, 1.55)
                      text: root.registeredSearchQuery
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      leftPadding: Style.spacing.controlPaddingX + Style.space(24)
                      rightPadding: Style.spacing.controlPaddingX
                      verticalAlignment: TextInput.AlignVCenter
                      selectByMouse: true
                      onTextEdited: root.registeredSearchQuery = text
                      background: Rectangle {
                        radius: height / 2
                        color: Qt.rgba(root.foreground.r, root.foreground.g,
                          root.foreground.b, 0.045)
                        border.width: registeredSearchInput.activeFocus ? 1.5 : 1
                        border.color: registeredSearchInput.activeFocus
                          ? root.accent
                          : Qt.rgba(root.foreground.r, root.foreground.g,
                              root.foreground.b, 0.18)

                        Text {
                          anchors.left: parent.left
                          anchors.leftMargin: Style.spacing.controlPaddingX
                          anchors.verticalCenter: parent.verticalCenter
                          text: "\u2315"
                          color: registeredSearchInput.activeFocus
                            ? root.accent : Qt.darker(root.foreground, 1.45)
                          font.family: root.fontFamily
                          font.pixelSize: 21
                        }
                      }
                    }

                    Flow {
                      width: parent.width
                      height: childrenRect.height
                      spacing: Style.spacing.sm

                      Repeater {
                        model: root.groupOptions

                        delegate: Button {
                          required property var modelData

                          objectName: "shortcutRegisteredGroup-"
                            + String(modelData || "")
                          text: root.groupLabel(String(modelData || ""))
                          selected: root.registeredFilterGroup
                            === String(modelData || "")
                          focusable: true
                          bordered: true
                          enabled: !root.shortcutBusy && !root.awaitingSave
                          foreground: root.foreground
                          background: root.background
                          accent: root.accent
                          fontFamily: root.fontFamily
                          fontSize: Style.font.caption
                          verticalPadding: Style.spacing.xs
                          onClicked: root.selectRegisteredGroup(
                            String(modelData || ""))
                        }
                      }
                    }
                  }
                }

                Item {
                  width: 1
                  height: Style.spacing.md
                }

                Rectangle {
                  id: selectedGroupCard

                  objectName: "shortcutSelectedGroupCard"
                  width: parent.width
                  height: selectedGroupColumn.implicitHeight + Style.spacing.md * 2
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.05)
                  border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.45)
                  border.width: 1
                  radius: Style.cornerRadius

                  Column {
                    id: selectedGroupColumn

                    x: Style.spacing.md
                    y: Style.spacing.md
                    width: parent.width - Style.spacing.md * 2
                    spacing: Style.spacing.xs

                    Row {
                      width: parent.width
                      height: Math.max(selectedGroupTitle.implicitHeight,
                        selectedGroupCount.implicitHeight)

                      Text {
                        id: selectedGroupTitle

                        width: parent.width - selectedGroupCount.width
                        text: root.t("shortcut.registered", {})
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                        elide: Text.ElideRight
                      }

                      Text {
                        id: selectedGroupCount

                        text: root.t("shortcut.filterResultCount", {
                          count: root.registeredBindings.length,
                          total: root.registeredBindingTotal
                        })
                        color: Qt.darker(root.foreground, 1.4)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }

                    Text {
                      width: parent.width
                      text: root.t("hud.visibilityHelp", {})
                      color: Qt.darker(root.foreground, 1.45)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    ShortcutChord {
                      objectName: "shortcutSelectedGroupChord"
                      visible: root.registeredFilterGroup !== ""
                      parts: root.groupParts(root.registeredFilterGroup)
                      foreground: root.foreground
                      fontFamily: root.fontFamily
                    }

                    Toggle {
                      visible: root.registeredFilterGroup !== ""
                      width: parent.width
                      label: root.t("common.enabled", {})
                      description: root.t("shortcut.groupEnabledHelp", {})
                      checked: root.groupEnabled(root.registeredFilterGroup)
                      foreground: root.foreground
                      accent: root.accent
                      fontFamily: root.fontFamily
                      onClicked: root.setGroupEnabled(
                        root.registeredFilterGroup,
                        !root.groupEnabled(root.registeredFilterGroup))
                    }

                    Item {
                      id: shortcutListHeader

                      objectName: "shortcutListHeader"
                      width: parent.width
                      height: 24
                      visible: width >= 900 && root.registeredBindings.length > 0
                      readonly property real chordWidth: 316
                      readonly property real visibilityX: width - 208
                      readonly property real editX: width - 116
                      readonly property real typeRoleWidth: 224
                      readonly property real titleTypeGap: 16
                      readonly property real typeHudGap: 24
                      readonly property real typeRoleX: visibilityX
                        - typeHudGap - typeRoleWidth

                      Text {
                        x: 12
                        width: shortcutListHeader.chordWidth
                        text: root.t("shortcut.shortcutColumn", {})
                        color: Qt.darker(root.foreground, 1.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Text {
                        x: 12 + shortcutListHeader.chordWidth + 12
                        width: Math.max(0, shortcutListHeader.typeRoleX - x
                          - shortcutListHeader.titleTypeGap)
                        text: root.t("shortcut.titleColumn", {})
                        color: Qt.darker(root.foreground, 1.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }

                      Text {
                        objectName: "shortcutTypeRoleHeader"
                        x: shortcutListHeader.typeRoleX
                        width: shortcutListHeader.typeRoleWidth
                        text: root.t("shortcut.typeRoleColumn", {})
                        color: Qt.darker(root.foreground, 1.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        horizontalAlignment: Text.AlignHCenter
                      }

                      Text {
                        x: shortcutListHeader.visibilityX
                        width: 84
                        text: root.t("shortcut.hudColumn", {})
                        color: Qt.darker(root.foreground, 1.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        horizontalAlignment: Text.AlignHCenter
                      }

                      Text {
                        x: shortcutListHeader.editX
                        width: 104
                        text: root.t("shortcut.actionColumn", {})
                        color: Qt.darker(root.foreground, 1.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        horizontalAlignment: Text.AlignHCenter
                      }
                    }

                    Text {
                      objectName: "shortcutRegisteredFilterIdle"
                      width: parent.width
                      visible: root.registeredBindings.length === 0
                      text: root.t(root.registeredFilterActive
                        ? "shortcut.filterNoResults" : "shortcut.filterIdle", {})
                      color: Qt.darker(root.foreground, 1.45)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      wrapMode: Text.WordWrap
                    }

                    Repeater {
                      model: root.registeredBindings

                      delegate: Components.BindingRow {
                        required property var modelData

                        objectName: "shortcutBindingRow-" + String(modelData.id || "")
                        width: selectedGroupColumn.width
                        height: implicitHeight
                        bindingData: modelData
                        language: root.uiLanguage
                        interactive: root.groupEnabled(root.bindingGroup(modelData))
                          && !root.shortcutBusy && !root.awaitingSave
                        editable: root.bindingEditable(modelData)
                        editReason: root.bindingEditReason(modelData)
                        visibleInHud: root.groupEnabled(root.bindingGroup(modelData))
                          && root.bindingVisible(
                            modelData.presentation_id || modelData.id)
                        foreground: root.foreground
                        mutedForeground: Qt.darker(root.foreground, 1.55)
                        accent: root.accent
                        surface: root.background
                        fontFamily: root.fontFamily
                        iconResolver: function(iconName) {
                          return Quickshell.iconPath(iconName, true)
                        }
                        onVisibilityChangeRequested: function (bindingId, visibleInHud) {
                          root.setBindingVisible(bindingId, visibleInHud)
                        }
                        onEditRequested: function(bindingId, anchorItem) {
                          root.openBinding(bindingId, anchorItem)
                        }
                      }
                    }
                  }
                }
              }
            }

          }

          Flow {
            id: footer
            objectName: "settingsFooter"
            width: parent.width
            height: childrenRect.height
            spacing: Style.spacing.md
            readonly property bool statusNeedsOwnLine: statusText.implicitWidth
              + shortcutResetButton.implicitWidth + cancelButton.implicitWidth
              + saveButton.implicitWidth + spacing * 3 > width

            Text {
              id: statusText
              objectName: "settingsStatusText"
              width: footer.statusNeedsOwnLine ? parent.width : Math.max(0,
                parent.width - saveButton.implicitWidth - cancelButton.implicitWidth
                - shortcutResetButton.implicitWidth - parent.spacing * 3)
              text: root.displayedStatus
              color: (root.saveError || root.serviceError) ? Color.urgent : Qt.darker(root.foreground, 1.35)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Button {
              id: shortcutResetButton
              objectName: "shortcutResetButton"
              text: root.resetConfirmationArmed
                ? root.t("settings.confirmReset", {})
                : root.t("settings.resetAll", {})
              focusable: true
              bordered: true
              enabled: !root.awaitingSave && !root.shortcutBusy
                && !root.settingsWriteBusy
              foreground: root.foreground
              background: root.background
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.requestResetAll()
            }

            Button {
              id: cancelButton
              objectName: "settingsCancelButton"
              text: root.t("common.cancel", {})
              focusable: true
              bordered: true
              enabled: !root.awaitingSave && !root.shortcutBusy
              foreground: root.foreground
              background: root.background
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.dismiss()
            }

            Button {
              id: saveButton
              objectName: "settingsSaveButton"
              text: root.t("common.save", {})
              focusable: true
              bordered: true
              selected: root.dirty
              enabled: !root.awaitingSave && !root.shortcutBusy
              foreground: root.foreground
              background: root.background
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.save()
            }
          }
        }
      }
    }
  }
}
