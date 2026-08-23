import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "HudModel.js" as HudModel
import "I18n.js" as I18n
import "VisibilityModel.js" as VisibilityModel

Item {
  id: root

  property var shell: null
  property var manifest: null
  property url hudSource: Qt.resolvedUrl("Hud.qml")

  readonly property string home: Quickshell.env("HOME")
  readonly property string dataHome: Quickshell.env("XDG_DATA_HOME") || home + "/.local/share"
  property string runtimeRoot: home + "/.local/lib/omarchy-keyguide"
  property string settingsPath: dataHome + "/omarchy-keyguide/settings.json"
  property var observerCommand: [runtimeRoot + "/bin/keyguide-observer"]
  property var bindingsCommand: ["python3", "-m", "keyguide_backend", "bindings", "--json"]
  property var settingsCommand: ["python3", "-m", "keyguide_backend", "settings", "get"]
  property var settingsPatchCommandPrefix: [
    "python3", "-m", "keyguide_backend", "settings", "patch"
  ]
  property var shortcutsStatusCommand: [
    "python3", "-m", "keyguide_backend", "shortcuts", "reconcile"
  ]
  property var shortcutsMutationCommandPrefix: [
    "python3", "-m", "keyguide_backend", "shortcuts"
  ]
  property var actionCatalogListCommandPrefix: [
    "python3", "-m", "keyguide_backend", "catalog", "list", "--language"
  ]
  property var actionCatalogFingerprintCommand: [
    "python3", "-m", "keyguide_backend", "catalog", "fingerprint"
  ]
  property var backendEnvironment: ({
    "PYTHONPATH": runtimeRoot,
    "PYTHONDONTWRITEBYTECODE": "1"
  })
  property var boundedProcessCommandPrefix: [
    "python3", "-m", "keyguide_backend.bounded_process"
  ]
  property var pluginBootstrapCommand: []
  property string repositoryRoot: ""
  property bool runtimeReady: false
  property bool runtimeInitializationStarted: false
  property bool runtimeInitializationActive: false
  property bool runtimeBootstrapAttemptStarted: false
  property string runtimeInitializationError: ""
  readonly property int catalogOutputByteLimit: 64 * 1024 * 1024
  readonly property int helperOutputByteLimit: 1024 * 1024
  readonly property int diagnosticOutputByteLimit: 64 * 1024
  readonly property int stdoutOutputLimitExit: 120
  readonly property int stderrOutputLimitExit: 121

  property var settings: defaultSettings()
  property var shortcutStatus: defaultShortcutStatus()
  property var allBindings: []
  property var modifierState: emptyModifierState()
  property bool bindingsRefreshPending: false
  property bool settingsRefreshPending: false
  property string observerError: ""
  property string bindingsError: ""
  property string settingsError: ""
  property string shortcutStatusError: ""
  property string shortcutMutationError: ""
  property bool observerAttemptStarted: false
  property bool bindingsAttemptActive: false
  property bool bindingsAttemptStarted: false
  property bool settingsAttemptActive: false
  property bool settingsAttemptStarted: false
  property int settingsAttemptGeneration: 0
  property int settingsWriteGeneration: 0
  property bool settingsSaveActive: false
  property bool settingsSaveAttemptActive: false
  property bool settingsSaveAttemptStarted: false
  property string settingsSaveError: ""
  property var pendingSettingsPatch: null
  property bool shortcutStatusRefreshPending: false
  property bool shortcutStatusAttemptActive: false
  property bool shortcutStatusAttemptStarted: false
  property bool shortcutMutationActive: false
  property bool shortcutMutationAttemptStarted: false
  property string shortcutMutationOperation: ""
  property var actionCatalog: ({
    version: 1, fingerprint: "", items: [], warnings: []
  })
  property string actionCatalogFingerprint: ""
  property string actionCatalogLanguage: ""
  property var actionCatalogWarnings: []
  property string actionCatalogError: ""
  property bool actionCatalogWatchEnabled: false
  property bool actionCatalogRefreshPending: false
  property bool actionCatalogListAttemptActive: false
  property bool actionCatalogListAttemptStarted: false
  property bool actionCatalogFingerprintAttemptActive: false
  property bool actionCatalogFingerprintAttemptStarted: false
  property int actionCatalogGeneration: 0
  property int actionCatalogListGeneration: 0
  property int actionCatalogFingerprintGeneration: 0
  property string actionCatalogListLanguage: ""
  readonly property bool actionCatalogBusy: actionCatalogListAttemptActive
    || actionCatalogFingerprintAttemptActive
  readonly property bool actionCatalogLoading: actionCatalogListAttemptActive
    && actionCatalog.items.length === 0
  readonly property bool actionCatalogWatchTimerRunning: actionCatalogWatchTimer.running
  property bool wheelSuppressed: false
  property bool dismissedForSuperCycle: false

  readonly property var presentationSettingKeys: [
    "enabled",
    "position",
    "scale",
    "opacity",
    "followTheme",
    "groups",
    "hiddenBindingIds",
    "language"
  ]
  readonly property var shortcutGroups: [
    "SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT",
    "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT",
    "SUPER+SHIFT+ALT", "SUPER+CTRL+SHIFT+ALT"
  ]
  readonly property var supportedShortcutKeys: [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
    "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "SPACE", "RETURN",
    "ESCAPE", "TAB", "BACKSPACE", "DELETE", "HOME", "END", "LEFT", "RIGHT", "UP",
    "DOWN", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11",
    "F12", "COMMA", "PERIOD", "SLASH", "MINUS", "EQUAL", "PRINT"
  ]

  signal settingsSaveFinished(bool success, string errorMessage)
  signal shortcutMutationFinished(bool success, string errorMessage, string operation)

  readonly property var lockService: {
    if (!root.shell || typeof root.shell.serviceFor !== "function") return null
    return root.shell.serviceFor("omarchy.lock")
  }
  readonly property bool locked: lockService === null || lockService.locked !== false
  readonly property bool observerShouldRun: runtimeReady
    && settings.enabled === true && !locked
  readonly property bool observerRunning: observerProcess.running
  readonly property var modifiers: HudModel.modifiersForState(modifierState)
  readonly property string modifierGroup: modifiers.join("+")
  readonly property bool groupEnabled: Array.isArray(settings.groups)
    && settings.groups.indexOf(modifierGroup) !== -1
  readonly property bool actionSuppressed: modifierState.actionPressed === true
    || wheelSuppressed
  readonly property var displayBindings: VisibilityModel.presentedBindings(
    allBindings,
    shortcutStatus && shortcutStatus.actions ? shortcutStatus.actions : [],
    actionCatalog && actionCatalog.items ? actionCatalog.items : [],
    settings.language)
  readonly property var bindings: HudModel.forGroup(
    displayBindings,
    modifiers,
    settings.hiddenBindingIds
  )
  readonly property bool hudVisible: HudModel.shouldShow({
    enabled: settings.enabled,
    locked: locked,
    superPressed: modifierState.super === true,
    actionPressed: modifierState.actionPressed === true,
    wheelSuppressed: wheelSuppressed,
    dismissedForSuperCycle: dismissedForSuperCycle,
    groupEnabled: groupEnabled,
    bindingCount: bindings.length
  })
  readonly property string lastError: runtimeInitializationError
    || shortcutMutationError || shortcutStatusError
    || settingsSaveError || actionCatalogError
    || observerError || bindingsError || settingsError

  function repositoryPluginRoot() {
    if (!manifest || typeof manifest !== "object" || Array.isArray(manifest))
      return ""
    const entryPoints = manifest.entryPoints
    if (!entryPoints || typeof entryPoints !== "object"
        || String(entryPoints.service || "") !== "src/plugin/Service.qml")
      return ""
    return String(manifest.__sourceDir || "")
  }

  function catalogItemById(selectionId) {
    const items = actionCatalog && Array.isArray(actionCatalog.items)
      ? actionCatalog.items : []
    const expectedId = String(selectionId || "")
    for (let index = 0; index < items.length; index += 1) {
      if (String(items[index] && items[index].id || "") === expectedId)
        return items[index]
    }
    return null
  }

  function initializeRuntime() {
    if (runtimeInitializationStarted) return
    runtimeInitializationStarted = true
    runtimeInitializationError = ""
    const sourceRoot = repositoryPluginRoot()
    if (!sourceRoot) {
      runtimeReady = true
      refresh()
      return
    }

    repositoryRoot = sourceRoot.replace(/\/$/, "")
    runtimeRoot = repositoryRoot + "/src/backend"
    observerCommand = [repositoryRoot + "/build/keyguide-observer"]
    if (!Array.isArray(pluginBootstrapCommand)
        || pluginBootstrapCommand.length === 0) {
      pluginBootstrapCommand = [
        "/usr/bin/bash", repositoryRoot + "/scripts/plugin-bootstrap.sh"
      ]
    }
    runtimeInitializationActive = true
    runtimeBootstrapAttemptStarted = false
    runtimeBootstrapProcess.running = true
  }

  function failRuntimeInitialization(message) {
    runtimeInitializationActive = false
    runtimeBootstrapAttemptStarted = false
    runtimeReady = false
    runtimeInitializationError = String(message || "plugin runtime setup failed")
  }

  function finishRuntimeInitialization() {
    runtimeInitializationActive = false
    runtimeBootstrapAttemptStarted = false
    runtimeInitializationError = ""
    runtimeReady = true
    refresh()
    if (actionCatalogWatchEnabled)
      refreshActionCatalog(true)
  }

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

  function emptyModifierState() {
    return {
      super: false,
      ctrl: false,
      shift: false,
      alt: false,
      actionPressed: false,
      wheelPulse: 0
    }
  }

  function defaultShortcutStatus() {
    return {
      version: 3,
      managedCount: 0,
      managedBindingIds: [],
      keyOptionsByGroup: {
        "SUPER": [], "SUPER+CTRL": [], "SUPER+SHIFT": [], "SUPER+ALT": [],
        "SUPER+CTRL+SHIFT": [], "SUPER+CTRL+ALT": [],
        "SUPER+SHIFT+ALT": [], "SUPER+CTRL+SHIFT+ALT": []
      },
      actions: [],
      discoveryError: ""
    }
  }

  function catalogString(value, name, maximum, allowEmpty) {
    if (typeof value !== "string" || value.length > maximum
        || (!allowEmpty && value.length === 0)
        || /[\u0000-\u001f\u007f]/.test(value)) {
      throw new Error(name + " is invalid")
    }
    return value
  }

  function parseActionCatalog(value) {
    const parsed = typeof value === "string"
      ? JSON.parse(String(value || "")) : value
    if (!hasExactKeys(parsed, ["version", "fingerprint", "items", "warnings"])
        || parsed.version !== 1
        || typeof parsed.fingerprint !== "string"
        || !/^[0-9a-f]{64}$/.test(parsed.fingerprint)
        || !Array.isArray(parsed.items) || parsed.items.length > 12288
        || !Array.isArray(parsed.warnings) || parsed.warnings.length > 4096) {
      throw new Error("action catalog has an invalid shape")
    }
    const ids = []
    const items = parsed.items.map(function(item) {
      const names = [
        "kind", "id", "title", "englishTitle", "summary", "icon", "path",
        "keywords"
      ]
      const enhancedNames = names.concat(["targetId", "launchKind"])
      const hasEnhancedFields = hasExactKeys(item, enhancedNames)
      if ((!hasExactKeys(item, names) && !hasEnhancedFields)
          || ["application", "command"].indexOf(item.kind) === -1
          || !Array.isArray(item.keywords) || item.keywords.length > 64
          || (hasEnhancedFields
            && (["desktopApp", "webapp", "command", "cmd"].indexOf(item.launchKind) === -1
              || typeof item.targetId !== "string" || !item.targetId))) {
        throw new Error("action catalog item has an invalid shape")
      }
      const id = root.catalogString(item.id, "catalog item ID", 320, false)
      if (ids.indexOf(id) !== -1
          || id.indexOf(item.kind + ":") !== 0) {
        throw new Error("action catalog item identity is invalid")
      }
      ids.push(id)
      const keywords = item.keywords.map(function(keyword) {
        return root.catalogString(keyword, "catalog keyword", 512, true)
      })
      return {
        kind: item.kind,
        id: id,
        title: root.catalogString(item.title, "catalog title", 512, false),
        englishTitle: root.catalogString(
          item.englishTitle, "catalog English title", 512, false),
        summary: root.catalogString(item.summary, "catalog summary", 512, true),
        icon: root.catalogString(item.icon, "catalog icon", 512, true),
        path: root.catalogString(item.path, "catalog path", 4096, true),
        keywords: keywords,
        targetId: hasEnhancedFields
          ? root.catalogString(item.targetId, "catalog target ID", 1024, false)
          : id,
        launchKind: hasEnhancedFields ? item.launchKind
          : (item.kind === "application" ? "desktopApp" : "command")
      }
    })
    const warnings = parsed.warnings.map(function(warning) {
      return root.catalogString(warning, "catalog warning", 1024, true)
    })
    return {
      version: 1,
      fingerprint: parsed.fingerprint,
      items: items,
      warnings: warnings
    }
  }

  function parseActionCatalogFingerprint(value) {
    const parsed = typeof value === "string"
      ? JSON.parse(String(value || "")) : value
    if (!hasExactKeys(parsed, ["version", "fingerprint"])
        || parsed.version !== 1 || typeof parsed.fingerprint !== "string"
        || !/^[0-9a-f]{64}$/.test(parsed.fingerprint)) {
      throw new Error("action catalog fingerprint has an invalid shape")
    }
    return parsed.fingerprint
  }

  function finishActionCatalogListAttempt() {
    const refreshAgain = actionCatalogRefreshPending
    actionCatalogRefreshPending = false
    actionCatalogListAttemptActive = false
    actionCatalogListAttemptStarted = false
    if (refreshAgain && actionCatalogWatchEnabled)
      Qt.callLater(function() { root.refreshActionCatalog(true) })
  }

  function finishActionCatalogFingerprintAttempt() {
    const refreshAgain = actionCatalogRefreshPending
    actionCatalogRefreshPending = false
    actionCatalogFingerprintAttemptActive = false
    actionCatalogFingerprintAttemptStarted = false
    if (refreshAgain && actionCatalogWatchEnabled)
      Qt.callLater(function() { root.refreshActionCatalog(true) })
  }

  function startActionCatalogList() {
    if (!runtimeReady || !actionCatalogWatchEnabled || actionCatalogBusy)
      return false
    actionCatalogError = ""
    actionCatalogListGeneration = actionCatalogGeneration
    actionCatalogListLanguage = String(settings.language || "en")
    actionCatalogListAttemptActive = true
    actionCatalogListAttemptStarted = false
    actionCatalogListProcess.command = boundedProcessCommand(
      actionCatalogListCommandPrefix.concat([actionCatalogListLanguage]),
      catalogOutputByteLimit,
      diagnosticOutputByteLimit
    )
    actionCatalogListProcess.running = true
    return true
  }

  function startActionCatalogFingerprint() {
    if (!runtimeReady || !actionCatalogWatchEnabled || actionCatalogBusy)
      return false
    actionCatalogError = ""
    actionCatalogFingerprintGeneration = actionCatalogGeneration
    actionCatalogFingerprintAttemptActive = true
    actionCatalogFingerprintAttemptStarted = false
    actionCatalogFingerprintProcess.command = boundedProcessCommand(
      actionCatalogFingerprintCommand,
      helperOutputByteLimit,
      diagnosticOutputByteLimit
    )
    actionCatalogFingerprintProcess.running = true
    return true
  }

  function refreshActionCatalog(force) {
    if (!actionCatalogWatchEnabled)
      return false
    if (!runtimeReady) {
      actionCatalogRefreshPending = true
      return true
    }
    if (actionCatalogBusy) {
      if (force === true)
        actionCatalogGeneration += 1
      actionCatalogRefreshPending = true
      return true
    }
    return force === true
      ? startActionCatalogList() : startActionCatalogFingerprint()
  }

  function setActionCatalogWatching(enabled) {
    const next = enabled === true
    if (actionCatalogWatchEnabled === next) {
      if (next)
        refreshActionCatalog(true)
      return
    }
    actionCatalogWatchEnabled = next
    actionCatalogGeneration += 1
    actionCatalogRefreshPending = false
    if (next) {
      actionCatalogError = ""
      refreshActionCatalog(true)
      return
    }
    actionCatalogListAttemptActive = false
    actionCatalogFingerprintAttemptActive = false
    actionCatalogListAttemptStarted = false
    actionCatalogFingerprintAttemptStarted = false
    if (actionCatalogListProcess.running)
      actionCatalogListProcess.running = false
    if (actionCatalogFingerprintProcess.running)
      actionCatalogFingerprintProcess.running = false
  }

  function clearModifierState() {
    wheelSuppressionTimer.stop()
    wheelSuppressed = false
    dismissedForSuperCycle = false
    modifierState = emptyModifierState()
  }

  function acceptModifierLine(line) {
    let parsed
    try {
      parsed = JSON.parse(String(line || ""))
    } catch (error) {
      observerError = "invalid observer state: " + error
      clearModifierState()
      return
    }

    const names = ["super", "ctrl", "shift", "alt", "actionPressed"]
    const wheelPulseValid = parsed
      && typeof parsed.wheelPulse === "number"
      && Number.isFinite(parsed.wheelPulse)
      && Math.floor(parsed.wheelPulse) === parsed.wheelPulse
      && parsed.wheelPulse >= 0
    if (!parsed || names.some(name => typeof parsed[name] !== "boolean")
        || !wheelPulseValid
        || parsed.wheelPulse < modifierState.wheelPulse) {
      observerError = "invalid observer state shape"
      clearModifierState()
      return
    }
    const wheelAdvanced = parsed.wheelPulse > modifierState.wheelPulse
    if (parsed.super === false) {
      dismissedForSuperCycle = false
    } else if (parsed.actionPressed === true || wheelAdvanced) {
      dismissedForSuperCycle = true
    }
    modifierState = {
      super: parsed.super,
      ctrl: parsed.ctrl,
      shift: parsed.shift,
      alt: parsed.alt,
      actionPressed: parsed.actionPressed,
      wheelPulse: parsed.wheelPulse
    }
    if (wheelAdvanced) {
      wheelSuppressed = true
      wheelSuppressionTimer.restart()
    }
    observerError = ""
  }

  function refreshBindings() {
    if (!runtimeReady) {
      bindingsRefreshPending = true
      return
    }
    if (shortcutMutationActive || bindingsProcess.running) {
      bindingsRefreshPending = true
      return
    }
    bindingsRefreshPending = false
    bindingsAttemptActive = true
    bindingsAttemptStarted = false
    bindingsProcess.running = true
  }

  function refreshSettings() {
    if (!runtimeReady) {
      settingsRefreshPending = true
      return
    }
    if (shortcutMutationActive || settingsSaveActive) {
      settingsRefreshPending = true
      return
    }
    if (settingsProcess.running) {
      settingsRefreshPending = true
      return
    }
    settingsRefreshPending = false
    settingsAttemptActive = true
    settingsAttemptStarted = false
    settingsAttemptGeneration = settingsWriteGeneration
    settingsProcess.running = true
  }

  function refresh() {
    refreshBindings()
    refreshSettings()
    refreshShortcutStatus()
  }

  function refreshShortcutStatus() {
    if (!runtimeReady) {
      shortcutStatusRefreshPending = true
      return
    }
    if (shortcutMutationActive || shortcutStatusProcess.running) {
      shortcutStatusRefreshPending = true
      return
    }
    shortcutStatusRefreshPending = false
    shortcutStatusAttemptActive = true
    shortcutStatusAttemptStarted = false
    shortcutStatusProcess.running = true
  }

  function hasExactKeys(value, names) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return false
    const keys = Object.keys(value)
    return keys.length === names.length
      && names.every(function(name) { return keys.indexOf(name) !== -1 })
  }

  function canonicalModifiers(modifiers) {
    if (!Array.isArray(modifiers)) return null
    const order = ["SUPER", "CTRL", "SHIFT", "ALT"]
    const canonical = order.filter(function(modifier) { return modifiers.indexOf(modifier) !== -1 })
    if (canonical.length !== modifiers.length
        || canonical.some(function(modifier, index) { return modifier !== modifiers[index] })) {
      return null
    }
    return canonical
  }

  function canonicalGroupForModifiers(modifiers) {
    const canonical = canonicalModifiers(modifiers)
    if (canonical === null) return ""
    const group = canonical.join("+")
    return shortcutGroups.indexOf(group) !== -1 ? group : ""
  }

  function uniqueStringArray(values, description) {
    if (!Array.isArray(values)) throw new Error(description + " must be an array")
    const normalized = []
    for (const value of values) {
      if (typeof value !== "string" || !value || normalized.indexOf(value) !== -1)
        throw new Error(description + " must contain unique non-empty strings")
      normalized.push(value)
    }
    return normalized
  }

  function parseShortcutStatus(value) {
    const parsed = typeof value === "string" ? JSON.parse(String(value || "")) : value
    const names = ["version", "managedCount", "managedBindingIds", "keyOptionsByGroup", "actions", "discoveryError"]
    if (!hasExactKeys(parsed, names) || parsed.version !== 3
        || typeof parsed.managedCount !== "number" || !Number.isFinite(parsed.managedCount)
        || Math.floor(parsed.managedCount) !== parsed.managedCount || parsed.managedCount < 0
        || typeof parsed.discoveryError !== "string"
        || !hasExactKeys(parsed.keyOptionsByGroup, shortcutGroups)
        || !Array.isArray(parsed.actions)) {
      throw new Error("shortcut status has an invalid shape")
    }

    const managedBindingIds = uniqueStringArray(parsed.managedBindingIds, "managed binding IDs")
    const optionActionIds = []
    const keyOptionsByGroup = {}
    for (const group of shortcutGroups) {
      const source = parsed.keyOptionsByGroup[group]
      if (!Array.isArray(source)) throw new Error("shortcut key options must be arrays")
      const optionKeys = []
      keyOptionsByGroup[group] = source.map(function(option) {
        const optionNames = [
          "key", "state", "title", "bindingId", "presentationId", "actionId",
          "editable", "editReason", "removable", "removeReason"
        ]
        if (!hasExactKeys(option, optionNames) || typeof option.key !== "string"
            || supportedShortcutKeys.indexOf(option.key) === -1
            || optionKeys.indexOf(option.key) !== -1
            || ["free", "assigned"].indexOf(option.state) === -1
            || typeof option.title !== "string" || typeof option.bindingId !== "string"
            || typeof option.presentationId !== "string"
            || typeof option.actionId !== "string" || typeof option.editable !== "boolean"
            || typeof option.editReason !== "string"
            || typeof option.removable !== "boolean"
            || typeof option.removeReason !== "string") {
          throw new Error("shortcut key option has an invalid shape")
        }
        optionKeys.push(option.key)
        if (option.actionId) {
          if (optionActionIds.indexOf(option.actionId) !== -1)
            throw new Error("shortcut key option action IDs must be unique")
          optionActionIds.push(option.actionId)
        }
        return {
          key: option.key, state: option.state, title: option.title,
          bindingId: option.bindingId, presentationId: option.presentationId,
          actionId: option.actionId,
          editable: option.editable, editReason: option.editReason,
          removable: option.removable, removeReason: option.removeReason
        }
      })
    }

    const actionIds = []
    const actionPresentationIds = []
    const actions = parsed.actions.map(function(action) {
      const hasPresentationId = Object.prototype.hasOwnProperty.call(
        action, "presentationId")
      const shapeAction = Object.assign({}, action)
      delete shapeAction.presentationId
      const actionNames = ["id", "title", "actionKind", "modifiers", "key"]
      const semanticActionNames = actionNames.concat([
        "labelKey", "selectionKind", "selectionId", "titleOverride"
      ])
      const enhancedActionNames = semanticActionNames.concat(["launchKind"])
      const targetActionNames = enhancedActionNames.concat(["targetId"])
      const legacyAgentActionNames = enhancedActionNames.concat(["agentName"])
      const legacyBrowserActionNames = enhancedActionNames.concat(["browserName"])
      const agentActionNames = targetActionNames.concat(["agentName"])
      const browserActionNames = targetActionNames.concat(["browserName"])
      const classifiedActionNames = targetActionNames.concat([
        "displayKind", "roleKind", "targetName"
      ])
      const classifiedAgentActionNames = classifiedActionNames.concat(["agentName"])
      const classifiedBrowserActionNames = classifiedActionNames.concat(["browserName"])
      const hasLegacySemanticFields = hasExactKeys(shapeAction, semanticActionNames)
      const hasLegacyAgentFields = hasExactKeys(shapeAction, legacyAgentActionNames)
      const hasLegacyBrowserFields = hasExactKeys(shapeAction, legacyBrowserActionNames)
      const hasAgentFields = hasExactKeys(shapeAction, agentActionNames)
      const hasBrowserFields = hasExactKeys(shapeAction, browserActionNames)
      const hasClassifiedFields = hasExactKeys(shapeAction, classifiedActionNames)
      const hasClassifiedAgentFields = hasExactKeys(shapeAction, classifiedAgentActionNames)
      const hasClassifiedBrowserFields = hasExactKeys(shapeAction, classifiedBrowserActionNames)
      const hasTargetFields = hasExactKeys(shapeAction, targetActionNames)
      const hasEnhancedSemanticFields = hasExactKeys(shapeAction, enhancedActionNames)
      const hasSemanticFields = hasClassifiedFields || hasClassifiedAgentFields
        || hasClassifiedBrowserFields || hasAgentFields || hasBrowserFields
        || hasTargetFields || hasLegacyAgentFields || hasLegacyBrowserFields
        || hasEnhancedSemanticFields || hasLegacySemanticFields
      if ((!hasExactKeys(shapeAction, actionNames) && !hasSemanticFields)
          || typeof action.id !== "string" || !action.id
          || actionIds.indexOf(action.id) !== -1 || typeof action.title !== "string"
          || (hasPresentationId
            && (typeof action.presentationId !== "string" || !action.presentationId
              || actionPresentationIds.indexOf(action.presentationId) !== -1))
          || ["exec", "lua"].indexOf(action.actionKind) === -1
          || !canonicalGroupForModifiers(action.modifiers)
          || typeof action.key !== "string" || supportedShortcutKeys.indexOf(action.key) === -1
          || (hasSemanticFields
            && (["action", "application", "command"].indexOf(action.selectionKind) === -1
              || typeof action.selectionId !== "string" || !action.selectionId
              || typeof action.labelKey !== "string"
              || typeof action.titleOverride !== "string"
              || ((hasClassifiedFields || hasClassifiedAgentFields
                    || hasClassifiedBrowserFields)
                && (["action", "command", "cmd", "desktopApp", "webapp", "systemUi"]
                      .indexOf(action.displayKind) === -1
                  || ["", "agent", "browser", "editor"]
                      .indexOf(action.roleKind) === -1
                  || typeof action.targetName !== "string"))
              || (!hasLegacySemanticFields
                && ["", "webapp", "desktopApp", "cmd"]
                    .indexOf(action.launchKind) === -1)
              || ((hasTargetFields || hasAgentFields || hasBrowserFields)
                && (typeof action.targetId !== "string" || !action.targetId))
              || ((hasLegacyAgentFields || hasAgentFields)
                && (typeof action.agentName !== "string" || !action.agentName))
              || ((hasLegacyBrowserFields || hasBrowserFields)
                && (typeof action.browserName !== "string" || !action.browserName))))) {
        throw new Error("shortcut action has an invalid shape")
      }
      actionIds.push(action.id)
      if (hasPresentationId) actionPresentationIds.push(action.presentationId)
      return {
        id: action.id, presentationId: hasPresentationId ? action.presentationId : "",
        title: action.title, actionKind: action.actionKind,
        launchKind: hasLegacySemanticFields ? "" : String(action.launchKind || ""),
        targetId: (hasTargetFields || hasAgentFields || hasBrowserFields
            || hasClassifiedFields || hasClassifiedAgentFields
            || hasClassifiedBrowserFields)
          ? action.targetId
          : (action.selectionKind === "application" || action.selectionKind === "command"
              ? action.selectionId : "action:" + action.id),
        agentName: (hasLegacyAgentFields || hasAgentFields
            || hasClassifiedAgentFields) ? action.agentName : "",
        browserName: (hasLegacyBrowserFields || hasBrowserFields
            || hasClassifiedBrowserFields)
          ? action.browserName : "",
        displayKind: (hasClassifiedFields || hasClassifiedAgentFields
            || hasClassifiedBrowserFields) ? action.displayKind : "",
        roleKind: (hasClassifiedFields || hasClassifiedAgentFields
            || hasClassifiedBrowserFields) ? action.roleKind : "",
        targetName: (hasClassifiedFields || hasClassifiedAgentFields
            || hasClassifiedBrowserFields) ? action.targetName : "",
        modifiers: action.modifiers.slice(), key: action.key,
        labelKey: hasSemanticFields ? action.labelKey : "",
        selectionKind: hasSemanticFields ? action.selectionKind : "action",
        selectionId: hasSemanticFields ? action.selectionId : action.id,
        titleOverride: hasSemanticFields ? action.titleOverride : ""
      }
    })
    if (optionActionIds.some(function(id) { return actionIds.indexOf(id) === -1 }))
      throw new Error("shortcut key option references an unknown action")
    return {
      version: 3, managedCount: parsed.managedCount, managedBindingIds: managedBindingIds,
      keyOptionsByGroup: keyOptionsByGroup, actions: actions, discoveryError: parsed.discoveryError
    }
  }

  function applyShortcutStatus(text) {
    try {
      shortcutStatus = parseShortcutStatus(text)
      shortcutStatusError = ""
      return true
    } catch (error) {
      shortcutStatusError = "cannot load shortcut status: " + error
      return false
    }
  }

  function finishShortcutStatusAttempt() {
    const refreshAgain = shortcutStatusRefreshPending
    shortcutStatusRefreshPending = false
    shortcutStatusAttemptActive = false
    shortcutStatusAttemptStarted = false
    if (refreshAgain) Qt.callLater(function() { root.refreshShortcutStatus() })
  }

  function startShortcutMutation(operation, request) {
    if (shortcutMutationActive || settingsSaveActive)
      return false
    if (["add", "move", "assign", "remove", "reset-all"].indexOf(operation) === -1) {
      shortcutMutationError = "unsupported shortcut operation: " + operation
      return false
    }
    if (operation !== "reset-all"
        && (!request || typeof request !== "object" || Array.isArray(request))) {
      shortcutMutationError = "shortcut request must be an object"
      return false
    }
    shortcutMutationError = ""
    shortcutMutationActive = true
    shortcutMutationAttemptStarted = false
    shortcutMutationOperation = operation
    shortcutMutationProcess.command = boundedProcessCommand(
      shortcutsMutationCommandPrefix.concat(
        operation === "reset-all"
          ? [operation]
          : [operation, JSON.stringify(request)]
      ),
      helperOutputByteLimit,
      diagnosticOutputByteLimit
    )
    shortcutMutationProcess.running = true
    return true
  }

  function mutateShortcut(operation, request) {
    if (["add", "move"].indexOf(operation) === -1) {
      shortcutMutationError = "unsupported shortcut operation: " + operation
      return false
    }
    return startShortcutMutation(operation, request)
  }

  function assignShortcut(request) {
    return startShortcutMutation("assign", request)
  }

  function removeShortcut(request) {
    return startShortcutMutation("remove", request)
  }

  function resetAll() {
    return startShortcutMutation("reset-all", null)
  }

  function finishShortcutMutation(success, message, acknowledgementUncertain) {
    const operation = shortcutMutationOperation
    shortcutMutationActive = false
    shortcutMutationAttemptStarted = false
    shortcutMutationOperation = ""
    if (!success)
      shortcutMutationError = String(message || "shortcut mutation failed")
    else
      shortcutMutationError = ""
    shortcutMutationFinished(success, shortcutMutationError, operation)
    if (success || acknowledgementUncertain === true || bindingsRefreshPending)
      Qt.callLater(function() { root.refreshBindings() })
    if (success || acknowledgementUncertain === true || shortcutStatusRefreshPending)
      Qt.callLater(function() { root.refreshShortcutStatus() })
    if ((acknowledgementUncertain === true && operation === "reset-all")
        || settingsRefreshPending)
      Qt.callLater(function() { root.refreshSettings() })
  }

  function presentationSettingsPatch(patch) {
    if (!patch || typeof patch !== "object" || Array.isArray(patch)) {
      settingsSaveError = "settings patch must be an object"
      return null
    }

    const normalized = {}
    let keyCount = 0
    for (const key in patch) {
      if (presentationSettingKeys.indexOf(key) === -1) {
        settingsSaveError = "unsupported settings field: " + key
        return null
      }
      normalized[key] = patch[key]
      keyCount += 1
    }
    if (keyCount === 0) {
      settingsSaveError = "no presentation settings changed"
      return null
    }
    return normalized
  }

  function mergedSettingsPatch(first, second) {
    const merged = {}
    for (const key in first || ({}))
      merged[key] = first[key]
    for (const key in second || ({}))
      merged[key] = second[key]
    return merged
  }

  function startSettingsPatch(patch) {
    if (shortcutMutationActive) {
      settingsSaveError = "settings save is unavailable while a shortcut change is active"
      return false
    }
    const normalized = presentationSettingsPatch(patch)
    if (normalized === null) return false

    settingsSaveActive = true
    settingsSaveAttemptActive = true
    settingsSaveAttemptStarted = false
    settingsWriteGeneration += 1
    settingsPatchProcess.command = boundedProcessCommand(
      settingsPatchCommandPrefix.concat([JSON.stringify(normalized)]),
      helperOutputByteLimit,
      diagnosticOutputByteLimit
    )
    settingsPatchProcess.running = true
    return true
  }

  function patchSettings(patch) {
    const normalized = presentationSettingsPatch(patch)
    if (normalized === null) return false
    if (shortcutMutationActive) {
      settingsSaveError = "settings save is unavailable while a shortcut change is active"
      return false
    }

    if (settingsPatchProcess.running || settingsSaveActive) {
      pendingSettingsPatch = mergedSettingsPatch(pendingSettingsPatch, normalized)
      return true
    }

    settingsSaveError = ""
    return startSettingsPatch(normalized)
  }

  function saveSettingsPatch(patch) {
    return patchSettings(patch)
  }

  function parseBindings(value) {
    const parsed = typeof value === "string" ? JSON.parse(String(value || "")) : value
    if (!Array.isArray(parsed)) throw new Error("bindings must be an array")
    const bindingIds = []
    return parsed.map(function(binding) {
      const names = ["id", "modifiers", "key", "description", "dispatcher", "argument",
        "mouse", "editable", "action_kind", "action_argument", "edit_reason",
        "presentation_id"]
      const semanticNames = names.concat([
        "selection_kind", "selection_id", "label_key", "title_override"
      ])
      const hasSemanticFields = hasExactKeys(binding, semanticNames)
      const modifiers = canonicalModifiers(binding.modifiers)
      if ((!hasExactKeys(binding, names) && !hasSemanticFields)
          || typeof binding.id !== "string" || !binding.id
          || bindingIds.indexOf(binding.id) !== -1 || modifiers === null
          || typeof binding.key !== "string" || !binding.key || typeof binding.description !== "string"
          || (binding.dispatcher !== null && typeof binding.dispatcher !== "string")
          || (binding.argument !== null && typeof binding.argument !== "string")
          || typeof binding.mouse !== "boolean" || typeof binding.editable !== "boolean"
          || (binding.action_kind !== null && typeof binding.action_kind !== "string")
          || (binding.action_argument !== null && typeof binding.action_argument !== "string")
          || typeof binding.edit_reason !== "string"
          || typeof binding.presentation_id !== "string" || !binding.presentation_id
          || (hasSemanticFields
            && (["", "action", "application", "command"].indexOf(binding.selection_kind) === -1
              || typeof binding.selection_id !== "string"
              || (binding.selection_kind === "" && binding.selection_id !== "")
              || (binding.selection_kind !== "" && !binding.selection_id)
              || typeof binding.label_key !== "string"
              || typeof binding.title_override !== "string"))) {
        throw new Error("binding has an invalid shape")
      }
      bindingIds.push(binding.id)
      return {
        id: binding.id, modifiers: modifiers, key: binding.key,
        description: binding.description, dispatcher: binding.dispatcher, argument: binding.argument,
        mouse: binding.mouse, editable: binding.editable, action_kind: binding.action_kind,
        action_argument: binding.action_argument, edit_reason: binding.edit_reason,
        presentation_id: binding.presentation_id,
        selection_kind: hasSemanticFields ? binding.selection_kind : "",
        selection_id: hasSemanticFields ? binding.selection_id : "",
        label_key: hasSemanticFields ? binding.label_key : "",
        title_override: hasSemanticFields ? binding.title_override : ""
      }
    })
  }

  function applyBindings(text) {
    try {
      allBindings = parseBindings(text)
      bindingsError = ""
    } catch (error) {
      allBindings = []
      bindingsError = "cannot load bindings: " + error
    }
  }

  function parseSettings(value) {
    const parsed = typeof value === "string"
      ? JSON.parse(String(value || "")) : value
    const names = [
      "version", "enabled", "position", "scale", "opacity", "groups",
      "hiddenBindingIds", "followTheme", "language"
    ]
    if (!hasExactKeys(parsed, names) || parsed.version !== 2
        || typeof parsed.enabled !== "boolean"
        || ["top", "center", "bottom", "left", "right"].indexOf(parsed.position) === -1
        || typeof parsed.scale !== "number" || !Number.isFinite(parsed.scale)
        || parsed.scale < 0.75 || parsed.scale > 1.5
        || typeof parsed.opacity !== "number" || !Number.isFinite(parsed.opacity)
        || parsed.opacity < 0.2 || parsed.opacity > 1
        || typeof parsed.followTheme !== "boolean"
        || ["en", "ko", "ja", "zh_CN", "es"].indexOf(parsed.language) === -1) {
      throw new Error("settings have an invalid version-2 shape")
    }
    if (!Array.isArray(parsed.groups)
        || parsed.groups.some(function(group) {
          return typeof group !== "string"
            || root.shortcutGroups.indexOf(group) === -1
        }))
      throw new Error("settings contain an unknown modifier group")
    if (!Array.isArray(parsed.hiddenBindingIds)
        || parsed.hiddenBindingIds.some(function(id) { return typeof id !== "string" }))
      throw new Error("hidden binding IDs must be strings")
    return {
      version: 2, enabled: parsed.enabled, position: parsed.position,
      scale: parsed.scale, opacity: parsed.opacity, groups: parsed.groups.slice(),
      hiddenBindingIds: parsed.hiddenBindingIds.slice(), followTheme: parsed.followTheme,
      language: parsed.language
    }
  }

  function applySettings(text) {
    try {
      settings = parseSettings(text)
      settingsError = ""
      return true
    } catch (error) {
      settingsError = "cannot load settings: " + error
      return false
    }
  }

  function failBindings(message) {
    allBindings = []
    bindingsError = message
  }

  function boundedDiagnostic(value) {
    const lines = String(value || "").trim().split(/\r?\n/).filter(function(line) {
      return line.trim() !== ""
    })
    if (!lines.length)
      return "shortcut change failed"
    const traceback = lines.some(function(line) {
      return line.indexOf("Traceback (most recent call last):") !== -1
    })
    const diagnostic = traceback ? lines[lines.length - 1].trim()
      : lines.map(function(line) { return line.trim() }).join(" | ")
    return diagnostic.replace(
      /^[A-Za-z_][A-Za-z0-9_.]*(?:Error|Exception):\s*/, "").slice(0, 2048)
  }

  function decodeUserError(value) {
    const fallback = boundedDiagnostic(value)
    const raw = String(value || "")
    if (raw.length > 16384)
      return fallback
    let parsed
    try {
      parsed = JSON.parse(raw)
    } catch (error) {
      return fallback
    }
    if (!hasExactKeys(parsed, ["version", "code", "message", "context"])
        || parsed.version !== 1 || typeof parsed.code !== "string"
        || !/^[a-z][a-z0-9_.-]{0,127}$/.test(parsed.code)
        || typeof parsed.message !== "string" || !parsed.message
        || parsed.message.length > 2048
        || !parsed.context || typeof parsed.context !== "object"
        || Array.isArray(parsed.context)) {
      return fallback
    }
    const contextKeys = Object.keys(parsed.context)
    if (contextKeys.length > 16 || contextKeys.some(function(key) {
      const contextValue = parsed.context[key]
      return !/^[A-Za-z][A-Za-z0-9]*$/.test(key)
        || typeof contextValue !== "string" || contextValue.length > 512
        || /[\u0000-\u001f\u007f]/.test(contextValue)
    })) {
      return fallback
    }
    const language = String(settings.language || "en")
    const localized = ({
      "catalog.selection_stale": "error.catalogStale",
      "catalog.selection_changed": "error.catalogChanged",
      "shortcut.target_occupied": "error.targetOccupied",
      "shortcut.replacement_confirmation_required": "error.confirmReplacement",
      "shortcut.target_stale": "error.targetStale",
      "shortcut.remove_confirmation_required": "error.removeUnavailable",
      "shortcut.remove_stale": "error.targetStale",
      "shortcut.remove_unavailable": "error.removeUnavailable",
      "settings.language_invalid": "error.languageInvalid",
      "shortcut.mutation_failed": "error.applyFailed",
      "settings.invalid": "error.settingsSave"
    })
    const key = localized[parsed.code] || ""
    if (key)
      return I18n.text(language, key, parsed.context)
    return boundedDiagnostic(parsed.message)
  }

  function shortcutMutationFailureMessage(value) {
    return decodeUserError(value)
  }

  function boundedProcessCommand(command, stdoutLimit, stderrLimit) {
    const wrapped = []
    for (let index = 0; boundedProcessCommandPrefix
        && index < boundedProcessCommandPrefix.length; index += 1) {
      wrapped.push(String(boundedProcessCommandPrefix[index]))
    }
    wrapped.push(
      "--stdout-limit", String(stdoutLimit),
      "--stderr-limit", String(stderrLimit),
      "--"
    )
    for (let index = 0; command && index < command.length; index += 1)
      wrapped.push(String(command[index]))
    return wrapped
  }

  function isOutputLimitExit(exitCode) {
    return exitCode === stdoutOutputLimitExit || exitCode === stderrOutputLimitExit
  }

  function outputLimitError(label, exitCode) {
    const channel = exitCode === stdoutOutputLimitExit
      ? "stdout" : (exitCode === stderrOutputLimitExit ? "stderr" : "output")
    return String(label || "helper") + " " + channel + " output limit exceeded"
  }

  function finishBindingsAttempt() {
    const refreshAgain = bindingsRefreshPending
    bindingsRefreshPending = false
    bindingsAttemptActive = false
    bindingsAttemptStarted = false
    if (refreshAgain) Qt.callLater(function() { root.refreshBindings() })
  }

  function finishSettingsAttempt() {
    const refreshAgain = settingsRefreshPending
    settingsRefreshPending = false
    settingsAttemptActive = false
    settingsAttemptStarted = false
    if (refreshAgain) Qt.callLater(function() { root.refreshSettings() })
  }

  function finishSettingsSave(success, message) {
    settingsSaveAttemptActive = false
    settingsSaveAttemptStarted = false
    if (!success) {
      pendingSettingsPatch = null
      settingsSaveActive = false
      settingsSaveError = String(message || "settings save failed")
      settingsSaveFinished(false, settingsSaveError)
      if (settingsRefreshPending)
        Qt.callLater(function() { root.refreshSettings() })
      return
    }

    if (pendingSettingsPatch !== null) {
      const nextPatch = pendingSettingsPatch
      pendingSettingsPatch = null
      Qt.callLater(function() { root.startSettingsPatch(nextPatch) })
      return
    }

    settingsSaveActive = false
    settingsSaveError = ""
    settingsSaveFinished(true, "")
    if (settingsRefreshPending)
      Qt.callLater(function() { root.refreshSettings() })
  }

  function hudState() {
    return {
      visible: hudVisible,
      modifiers: modifiers,
      bindings: bindings
    }
  }

  function configureHud() {
    if (!hudLoader.item) return
    hudLoader.item.hudVisible = Qt.binding(function() { return root.hudVisible })
    hudLoader.item.modifiers = Qt.binding(function() { return root.modifiers })
    hudLoader.item.bindings = Qt.binding(function() { return root.bindings })
    hudLoader.item.settings = Qt.binding(function() { return root.settings })
    hudLoader.item.language = Qt.binding(function() {
      return String(root.settings.language || "en")
    })
  }

  function handleCompositorEvent(event) {
    if (!event || String(event.name || "") !== "configreloaded")
      return false
    refreshBindings()
    refreshShortcutStatus()
    return true
  }

  onLockedChanged: if (locked) clearModifierState()

  onSettingsChanged: {
    const language = String(settings.language || "en")
    if (actionCatalogWatchEnabled
        && (actionCatalogLanguage !== language
          || (actionCatalogListAttemptActive
            && actionCatalogListLanguage !== language))) {
      actionCatalogGeneration += 1
      actionCatalogRefreshPending = true
      if (!actionCatalogBusy)
        Qt.callLater(function() { root.refreshActionCatalog(true) })
    }
  }

  onManifestChanged: Qt.callLater(function() { root.initializeRuntime() })

  Component.onCompleted: Qt.callLater(function() { root.initializeRuntime() })

  Connections {
    target: Hyprland

    function onRawEvent(event) {
      root.handleCompositorEvent(event)
    }
  }

  Timer {
    id: wheelSuppressionTimer
    interval: 120
    repeat: false
    onTriggered: root.wheelSuppressed = false
  }

  Timer {
    id: actionCatalogWatchTimer
    interval: 2000
    repeat: true
    running: root.actionCatalogWatchEnabled
    onTriggered: root.refreshActionCatalog(false)
  }

  Process {
    id: actionCatalogListProcess
    environment: root.backendEnvironment

    stdout: StdioCollector { id: actionCatalogListStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionCatalogListStderr; waitForEnd: true }

    onStarted: root.actionCatalogListAttemptStarted = true

    onRunningChanged: {
      if (!running && root.actionCatalogListAttemptActive
          && !root.actionCatalogListAttemptStarted) {
        root.actionCatalogError = I18n.text(
          root.settings.language, "error.catalogLoad", {})
        root.finishActionCatalogListAttempt()
      }
    }

    onExited: function(exitCode) {
      if (!root.actionCatalogListAttemptActive)
        return
      const current = root.actionCatalogWatchEnabled
        && root.actionCatalogListGeneration === root.actionCatalogGeneration
        && root.actionCatalogListLanguage === String(root.settings.language || "en")
      if (current && root.isOutputLimitExit(exitCode)) {
        root.actionCatalogError = root.outputLimitError("action catalog", exitCode)
      } else if (current && exitCode === 0) {
        try {
          const parsed = root.parseActionCatalog(actionCatalogListStdout.text)
          root.actionCatalog = parsed
          root.actionCatalogFingerprint = parsed.fingerprint
          root.actionCatalogWarnings = parsed.warnings.slice()
          root.actionCatalogLanguage = root.actionCatalogListLanguage
          root.actionCatalogError = ""
        } catch (error) {
          root.actionCatalogError = I18n.text(
            root.settings.language, "error.catalogLoad", {})
        }
      } else if (current) {
        root.actionCatalogError = root.decodeUserError(
          actionCatalogListStderr.text)
          || I18n.text(root.settings.language, "error.catalogLoad", {})
      }
      root.finishActionCatalogListAttempt()
    }
  }

  Process {
    id: actionCatalogFingerprintProcess
    environment: root.backendEnvironment

    stdout: StdioCollector { id: actionCatalogFingerprintStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionCatalogFingerprintStderr; waitForEnd: true }

    onStarted: root.actionCatalogFingerprintAttemptStarted = true

    onRunningChanged: {
      if (!running && root.actionCatalogFingerprintAttemptActive
          && !root.actionCatalogFingerprintAttemptStarted) {
        root.actionCatalogError = I18n.text(
          root.settings.language, "error.catalogLoad", {})
        root.finishActionCatalogFingerprintAttempt()
      }
    }

    onExited: function(exitCode) {
      if (!root.actionCatalogFingerprintAttemptActive)
        return
      const current = root.actionCatalogWatchEnabled
        && root.actionCatalogFingerprintGeneration === root.actionCatalogGeneration
      let changed = false
      if (current && root.isOutputLimitExit(exitCode)) {
        root.actionCatalogError = root.outputLimitError(
          "action catalog fingerprint", exitCode)
      } else if (current && exitCode === 0) {
        try {
          const fingerprint = root.parseActionCatalogFingerprint(
            actionCatalogFingerprintStdout.text)
          changed = fingerprint !== root.actionCatalogFingerprint
          root.actionCatalogError = ""
        } catch (error) {
          root.actionCatalogError = I18n.text(
            root.settings.language, "error.catalogLoad", {})
        }
      } else if (current) {
        root.actionCatalogError = root.decodeUserError(
          actionCatalogFingerprintStderr.text)
          || I18n.text(root.settings.language, "error.catalogLoad", {})
      }
      const refreshAgain = root.actionCatalogRefreshPending
      root.actionCatalogRefreshPending = false
      root.actionCatalogFingerprintAttemptActive = false
      root.actionCatalogFingerprintAttemptStarted = false
      if (current && changed && root.actionCatalogWatchEnabled) {
        Qt.callLater(function() { root.startActionCatalogList() })
      } else if (refreshAgain && root.actionCatalogWatchEnabled) {
        Qt.callLater(function() { root.refreshActionCatalog(true) })
      }
    }
  }

  Process {
    id: runtimeBootstrapProcess
    command: root.boundedProcessCommand(
      root.pluginBootstrapCommand, 0, root.diagnosticOutputByteLimit)
    environment: root.backendEnvironment

    stderr: StdioCollector { id: runtimeBootstrapStderr; waitForEnd: true }

    onStarted: root.runtimeBootstrapAttemptStarted = true

    onRunningChanged: {
      if (!running && root.runtimeInitializationActive
          && !root.runtimeBootstrapAttemptStarted) {
        root.failRuntimeInitialization("plugin runtime setup command failed to start")
      }
    }

    onExited: function(exitCode) {
      if (!root.runtimeInitializationActive) return
      if (root.isOutputLimitExit(exitCode)) {
        root.failRuntimeInitialization(root.outputLimitError(
          "plugin runtime setup", exitCode))
        return
      } else if (exitCode !== 0) {
        const detail = String(runtimeBootstrapStderr.text || "").trim()
        root.failRuntimeInitialization(
          "plugin runtime setup failed" + (detail ? ": " + detail : "")
        )
        return
      }
      root.finishRuntimeInitialization()
    }
  }

  Process {
    id: observerProcess
    command: root.observerCommand
    running: root.observerShouldRun

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) { root.acceptModifierLine(line) }
    }

    stderr: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        const message = String(line || "").trim()
        if (message) {
          root.observerError = "observer: " + message
          root.clearModifierState()
        }
      }
    }

    onStarted: {
      root.observerAttemptStarted = true
      root.observerError = ""
    }

    onRunningChanged: {
      if (running) {
        root.observerAttemptStarted = false
      } else {
        root.clearModifierState()
        if (root.observerShouldRun && !root.observerAttemptStarted) {
          root.observerError = "observer command failed to start"
        }
        root.observerAttemptStarted = false
      }
    }
  }

  Process {
    id: bindingsProcess
    command: root.boundedProcessCommand(
      root.bindingsCommand, root.helperOutputByteLimit, root.diagnosticOutputByteLimit)
    environment: root.backendEnvironment

    stdout: StdioCollector { id: bindingsStdout; waitForEnd: true }
    stderr: StdioCollector { id: bindingsStderr; waitForEnd: true }

    onStarted: root.bindingsAttemptStarted = true

    onRunningChanged: {
      if (!running && root.bindingsAttemptActive && !root.bindingsAttemptStarted) {
        root.failBindings("bindings command failed to start")
        root.finishBindingsAttempt()
      }
    }

    onExited: function(exitCode) {
      if (!root.bindingsAttemptActive) return
      if (root.isOutputLimitExit(exitCode))
        root.failBindings(root.outputLimitError("bindings", exitCode))
      else if (exitCode === 0) root.applyBindings(bindingsStdout.text)
      else root.failBindings(root.decodeUserError(bindingsStderr.text)
        || "bindings command failed")
      root.finishBindingsAttempt()
    }
  }

  Process {
    id: settingsProcess
    command: root.boundedProcessCommand(
      root.settingsCommand, root.helperOutputByteLimit, root.diagnosticOutputByteLimit)
    environment: root.backendEnvironment

    stdout: StdioCollector { id: settingsStdout; waitForEnd: true }
    stderr: StdioCollector { id: settingsStderr; waitForEnd: true }

    onStarted: root.settingsAttemptStarted = true

    onRunningChanged: {
      if (!running && root.settingsAttemptActive && !root.settingsAttemptStarted) {
        root.settingsError = "settings command failed to start"
        root.finishSettingsAttempt()
      }
    }

    onExited: function(exitCode) {
      if (!root.settingsAttemptActive) return
      if (root.settingsAttemptGeneration !== root.settingsWriteGeneration) {
        root.settingsRefreshPending = true
      } else if (root.isOutputLimitExit(exitCode)) {
        root.settingsError = root.outputLimitError("settings", exitCode)
      } else if (exitCode === 0) {
        root.applySettings(settingsStdout.text)
      } else {
        root.settingsError = root.decodeUserError(settingsStderr.text)
          || "settings command failed"
      }
      root.finishSettingsAttempt()
    }
  }

  Process {
    id: settingsPatchProcess
    environment: root.backendEnvironment

    stdout: StdioCollector { id: settingsPatchStdout; waitForEnd: true }
    stderr: StdioCollector { id: settingsPatchStderr; waitForEnd: true }

    onStarted: root.settingsSaveAttemptStarted = true

    onRunningChanged: {
      if (!running && root.settingsSaveAttemptActive && !root.settingsSaveAttemptStarted) {
        root.finishSettingsSave(false, "settings patch command failed to start")
      }
    }

    onExited: function(exitCode) {
      if (!root.settingsSaveActive) return
      if (root.isOutputLimitExit(exitCode)) {
        root.finishSettingsSave(false, root.outputLimitError(
          "settings patch", exitCode))
        return
      }
      if (exitCode !== 0) {
        root.finishSettingsSave(
          false,
          root.decodeUserError(settingsPatchStderr.text)
            || "settings patch command failed"
        )
        return
      }
      if (!root.applySettings(settingsPatchStdout.text)) {
        root.finishSettingsSave(false, root.settingsError)
        return
      }
      root.finishSettingsSave(true, "")
    }
  }

  Process {
    id: shortcutStatusProcess
    command: root.boundedProcessCommand(
      root.shortcutsStatusCommand, root.helperOutputByteLimit,
      root.diagnosticOutputByteLimit)
    environment: root.backendEnvironment

    stdout: StdioCollector { id: shortcutStatusStdout; waitForEnd: true }
    stderr: StdioCollector { id: shortcutStatusStderr; waitForEnd: true }

    onStarted: root.shortcutStatusAttemptStarted = true

    onRunningChanged: {
      if (!running && root.shortcutStatusAttemptActive
          && !root.shortcutStatusAttemptStarted) {
        root.shortcutStatusError = "shortcut status command failed to start"
        root.finishShortcutStatusAttempt()
      }
    }

    onExited: function(exitCode) {
      if (!root.shortcutStatusAttemptActive) return
      if (root.isOutputLimitExit(exitCode)) {
        root.shortcutStatusError = root.outputLimitError("shortcut status", exitCode)
      } else if (exitCode === 0) {
        root.applyShortcutStatus(shortcutStatusStdout.text)
      } else {
        root.shortcutStatusError = root.decodeUserError(shortcutStatusStderr.text)
          || "shortcut status command failed"
      }
      root.finishShortcutStatusAttempt()
    }
  }

  Process {
    id: shortcutMutationProcess
    environment: root.backendEnvironment

    stdout: StdioCollector { id: shortcutMutationStdout; waitForEnd: true }
    stderr: StdioCollector { id: shortcutMutationStderr; waitForEnd: true }

    onStarted: root.shortcutMutationAttemptStarted = true

    onRunningChanged: {
      if (!running && root.shortcutMutationActive
          && !root.shortcutMutationAttemptStarted) {
        root.finishShortcutMutation(false, "shortcut mutation command failed to start")
      }
    }

    onExited: function(exitCode) {
      if (!root.shortcutMutationActive) return
      if (root.isOutputLimitExit(exitCode)) {
        root.finishShortcutMutation(
          false,
          root.outputLimitError("shortcut mutation", exitCode),
          true
        )
        return
      }
      if (exitCode !== 0) {
        root.finishShortcutMutation(
          false,
          root.shortcutMutationFailureMessage(shortcutMutationStderr.text),
          true
        )
        return
      }
      try {
        const parsed = JSON.parse(String(shortcutMutationStdout.text || ""))
        if (root.shortcutMutationOperation === "reset-all") {
          if (!root.hasExactKeys(parsed, ["shortcuts", "settings"]))
            throw new Error("reset-all response has an invalid shape")
          const nextStatus = root.parseShortcutStatus(parsed.shortcuts)
          const nextSettings = root.parseSettings(parsed.settings)
          root.shortcutStatus = nextStatus
          root.settings = nextSettings
          root.shortcutStatusError = ""
          root.settingsError = ""
        } else if (["assign", "remove"].indexOf(root.shortcutMutationOperation) !== -1) {
          if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
            throw new Error("shortcut response has an invalid shape")
          const nextStatus = root.parseShortcutStatus(parsed.shortcuts)
          const nextBindings = root.parseBindings(parsed.bindings)
          root.shortcutStatus = nextStatus
          root.allBindings = nextBindings
          root.shortcutStatusError = ""
          root.bindingsError = ""
        } else if (!root.applyShortcutStatus(parsed)) {
          throw new Error(root.shortcutStatusError || "invalid shortcut status")
        }
      } catch (error) {
        root.finishShortcutMutation(
          false,
          "could not confirm committed shortcut state: " + error,
          true
        )
        return
      }
      root.finishShortcutMutation(true, "")
    }
  }

  FileView {
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload()
      root.refreshSettings()
    }
  }

  Loader {
    id: hudLoader
    active: String(root.hudSource) !== ""
    source: root.hudSource
    onLoaded: root.configureHud()
  }

  IpcHandler {
    target: "keyguide"

    function refresh(): string {
      root.refresh()
      return "ok"
    }

    function state(): string {
      return JSON.stringify(root.hudState())
    }

    function settings(): string {
      return JSON.stringify(root.settings)
    }
  }
}
