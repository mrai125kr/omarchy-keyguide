.pragma library
.import "I18n.js" as I18n

const modifierOrder = ["SUPER", "CTRL", "SHIFT", "ALT"]
const displayKinds = ["desktopApp", "webapp", "cmd", "action", "systemUi"]

function arrayFrom(value) {
  if (!Array.isArray(value)) return []
  return value.slice()
}

function bindingGroup(binding) {
  if (!binding || !Array.isArray(binding.modifiers)) return ""
  const canonical = modifierOrder.filter(function (modifier) {
    return binding.modifiers.indexOf(modifier) !== -1
  })
  if (canonical.length !== binding.modifiers.length) return ""
  return canonical.join("+")
}

function bindingsForGroup(bindings, group) {
  return arrayFrom(bindings).filter(function (binding) {
    return bindingGroup(binding) === group
  })
}

function sectionForGroup(bindings, group) {
  return {
    group: String(group || ""),
    bindings: bindingsForGroup(bindings, group)
  }
}

function presentationId(binding) {
  return String(binding && (binding.presentation_id || binding.id) || "")
}

function keyOptionLabel(option, language) {
  const key = String(option && option.key || "")
  if (!option || option.state === "free")
    return key + " · " + I18n.text(language, "common.available", {})
  return key + " · " + I18n.text(language, "shortcut.assigned", {})
    + " — " + String(option.title || "")
}

function keyOptions(status, group, language) {
  const source = status && status.keyOptionsByGroup
    ? status.keyOptionsByGroup[String(group || "")]
    : []
  return arrayFrom(source).map(function (option) {
    const result = Object.assign({}, option)
    result.label = keyOptionLabel(option, language)
    return result
  })
}

function keyOption(status, group, key, language) {
  const targetKey = String(key || "")
  const options = keyOptions(status, group, language)
  for (let index = 0; index < options.length; index += 1) {
    if (String(options[index].key || "") === targetKey) return options[index]
  }
  return null
}

function chordLabel(modifiers, key, language) {
  const modifierLabels = arrayFrom(modifiers).map(function (modifier) {
    return I18n.modifier(language, modifier)
  }).filter(function (modifier) {
    return modifier.length > 0
  })
  const chord = modifierLabels.concat([String(key || "")]).filter(function (part) {
    return part.length > 0
  })
  return chord.join(" + ")
}

function normalizedSearchText(value) {
  let result = String(value || "")
  if (typeof result.normalize === "function")
    result = result.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  return result.toLocaleLowerCase().replace(/[+\-_./:]+/g, " ")
    .trim().replace(/\s+/g, " ")
}

function normalizedDisplayKind(value) {
  const kind = String(value || "")
  if (kind === "command") return "action"
  return displayKinds.indexOf(kind) === -1 ? "action" : kind
}

function typeBadgeKey(kind) {
  switch (normalizedDisplayKind(kind)) {
  case "desktopApp": return "search.desktopAppBadge"
  case "webapp": return "search.webAppBadge"
  case "cmd": return "search.cmdBadge"
  case "systemUi": return "search.systemUiBadge"
  default: return "search.actionBadge"
  }
}

function typeAccent(kind, light, fallback) {
  switch (String(kind || "")) {
  case "desktopApp": return light ? "#1557b0" : "#82b1ff"
  case "webapp": return light ? "#006b5d" : "#54e1c1"
  case "cmd": return light ? "#8a4300" : "#ffc266"
  case "action": return light ? "#6c2b96" : "#d6a5ff"
  case "systemUi": return light ? "#9b174c" : "#ff8fb8"
  default: return fallback
  }
}

function roleBadgeKey(kind) {
  switch (String(kind || "")) {
  case "agent": return "search.agentBadge"
  case "browser": return "search.browserBadge"
  case "editor": return "search.editorBadge"
  default: return ""
  }
}

function fallbackIcon(displayKind, roleKind, browserName) {
  if (String(roleKind || "") === "browser") {
    const browserIcons = {
      Chromium: "chromium", Chrome: "google-chrome",
      Brave: "brave-browser", "Brave Origin": "brave-browser",
      Edge: "microsoft-edge", Firefox: "firefox", Zen: "zen-browser"
    }
    return browserIcons[String(browserName || "")] || "web-browser"
  }
  switch (String(displayKind || "")) {
  case "webapp": return "applications-internet"
  case "command":
  case "cmd": return "utilities-terminal"
  case "desktopApp": return "application-x-executable"
  default: return "preferences-system"
  }
}

function fallbackIconGlyph(displayKind) {
  switch (normalizedDisplayKind(displayKind)) {
  case "cmd": return ">_"
  case "webapp": return "@"
  case "desktopApp": return "A"
  case "systemUi": return "*"
  default: return "+"
  }
}

function actionIndexes(actions) {
  const byId = {}
  const byPresentationId = {}
  const byChord = {}
  arrayFrom(actions).forEach(function(action) {
    const id = String(action && action.id || "")
    if (id && byId[id] === undefined) byId[id] = action
    const stablePresentationId = String(action && action.presentationId || "")
    if (stablePresentationId
        && byPresentationId[stablePresentationId] === undefined)
      byPresentationId[stablePresentationId] = action
    const group = bindingGroup(action)
    const key = String(action && action.key || "")
    const chord = group && key ? group + "|" + key : ""
    if (!stablePresentationId && chord && byChord[chord] === undefined)
      byChord[chord] = action
  })
  return {
    byId: byId,
    byPresentationId: byPresentationId,
    byChord: byChord
  }
}

function actionForBinding(indexes, binding) {
  const stablePresentationId = presentationId(binding)
  const direct = indexes.byPresentationId[stablePresentationId]
    || indexes.byId[stablePresentationId]
  if (direct) return direct
  const group = bindingGroup(binding)
  const key = String(binding && binding.key || "")
  return indexes.byChord[group && key ? group + "|" + key : ""] || null
}

function catalogByTargetId(items) {
  const result = {}
  arrayFrom(items).forEach(function(item) {
    const id = String(item && item.id || "")
    const targetId = String(item && item.targetId || id)
    if (targetId && result[targetId] === undefined) result[targetId] = item
    if (id && result[id] === undefined) result[id] = item
  })
  return result
}

function registeredBinding(binding, action, catalogMap, language) {
  const result = Object.assign({}, binding || {})
  const selectedApplication = String(result.selection_kind || "") === "application"
  const displayKind = String(action && action.displayKind || "")
    || (selectedApplication ? "desktopApp" : "action")
  result.displayKind = normalizedDisplayKind(displayKind)
  result.roleKind = String(action && action.roleKind || "")
  result.targetName = String(action && action.targetName || "")
  result.agentName = String(action && action.agentName || "")
  result.browserName = String(action && action.browserName || "")
  result.launchKind = String(action && action.launchKind || "")
  result.labelKey = String(action && action.labelKey || result.label_key || "")
  result.targetId = String(action && action.targetId
    || result.selection_id || "")
  const catalogItem = catalogMap[result.targetId] || null
  result.titleOverride = String(result.title_override
    || action && action.titleOverride || "")
  const localizedAction = I18n.actionTitle(
    language, result.labelKey, String(result.description || ""))
  const concreteName = String(catalogItem && catalogItem.title
    || result.targetName
    || (result.roleKind === "agent" ? result.agentName : "")
    || (result.roleKind === "browser" ? result.browserName : "")
    || "")
  result.description = result.titleOverride || concreteName || localizedAction
  result.icon = String(catalogItem && catalogItem.icon || "")
    || fallbackIcon(result.displayKind, result.roleKind, result.browserName)
  return result
}

function presentedBindings(bindings, actions, catalogItems, language) {
  const indexes = actionIndexes(actions)
  const catalogMap = catalogByTargetId(catalogItems)
  return arrayFrom(bindings).map(function(binding) {
    return registeredBinding(
      binding, actionForBinding(indexes, binding), catalogMap, language)
  })
}

function registeredSearchFields(binding, language) {
  const kind = normalizedDisplayKind(binding && binding.displayKind)
  const roleKey = roleBadgeKey(binding && binding.roleKind)
  const fallback = String(binding && binding.description || "")
  const labelKey = String(binding && binding.labelKey
    || I18n.actionKey(fallback) || "")
  const localizedTitle = I18n.actionTitle(language, labelKey, fallback)
  const englishTitle = I18n.actionTitle("en", labelKey, fallback)
  return [
    localizedTitle, englishTitle, fallback,
    chordLabel(binding && binding.modifiers, binding && binding.key, language),
    chordLabel(binding && binding.modifiers, binding && binding.key, "en"),
    bindingGroup(binding), String(binding && binding.key || ""),
    I18n.text(language, typeBadgeKey(kind), {}),
    I18n.text("en", typeBadgeKey(kind), {}),
    roleKey ? I18n.text(language, roleKey, {}) : "",
    roleKey ? I18n.text("en", roleKey, {}) : "",
    String(binding && binding.targetName || ""),
    String(binding && binding.agentName || ""),
    String(binding && binding.browserName || ""),
    String(binding && binding.selection_id || ""),
    String(binding && binding.action_argument || "")
  ]
}

function registeredBindings(bindings, actions, query, group, language,
                            catalogItems) {
  const requestedGroup = String(group || "")
  const normalizedQuery = normalizedSearchText(query)
  if (!requestedGroup && !normalizedQuery) return []

  const queryParts = normalizedQuery.split(" ").filter(function(part) {
    return part.length > 0
  })
  return presentedBindings(bindings, actions, catalogItems, language).filter(function(binding) {
    return !requestedGroup || bindingGroup(binding) === requestedGroup
  }).filter(function(binding) {
    if (queryParts.length === 0) return true
    const haystack = normalizedSearchText(
      registeredSearchFields(binding, language).join(" "))
    return queryParts.every(function(part) {
      return haystack.indexOf(part) !== -1
    })
  })
}

function actionOptions(status, targetOption, language) {
  const targetIsFree = Boolean(targetOption) && targetOption.state === "free"
  return arrayFrom(status && status.actions).map(function (action) {
    const result = Object.assign({}, action)
    const fallback = String(action && action.title || "")
    const labelKey = String(action && action.labelKey
      || I18n.actionKey(fallback) || "")
    result.label = I18n.actionTitle(language, labelKey, fallback) + " · "
      + String(action && action.actionKind || "") + " · "
      + chordLabel(action && action.modifiers, action && action.key, language)
    result.selectable = targetIsFree
    return result
  })
}

function sections(bindings, groupOptions) {
  const source = arrayFrom(bindings)
  return arrayFrom(groupOptions).map(function (group) {
    return {
      group: group,
      bindings: bindingsForGroup(source, group)
    }
  }).filter(function (section) {
    return section.bindings.length > 0
  })
}

function toggleGroup(settings, bindings, group, enabled) {
  const source = settings || {}
  let groups = arrayFrom(source.groups)
  let hiddenBindingIds = arrayFrom(source.hiddenBindingIds)
  const groupIndex = groups.indexOf(group)

  if (enabled) {
    if (groupIndex === -1) groups.push(group)
    const currentIds = bindingsForGroup(bindings, group).map(function (binding) {
      return presentationId(binding)
    }).filter(function (id) {
      return id.length > 0
    })
    const allCurrentHidden = currentIds.length > 0 && currentIds.every(function (id) {
      return hiddenBindingIds.indexOf(id) !== -1
    })
    if (allCurrentHidden) {
      hiddenBindingIds = hiddenBindingIds.filter(function (id) {
        return currentIds.indexOf(id) === -1
      })
    }
  } else if (groupIndex !== -1) {
    groups = groups.filter(function (candidate) {
      return candidate !== group
    })
  }

  return {
    groups: groups,
    hiddenBindingIds: hiddenBindingIds
  }
}

function toggleBinding(settings, bindings, id, visible) {
  const source = settings || {}
  let groups = arrayFrom(source.groups)
  let hiddenBindingIds = arrayFrom(source.hiddenBindingIds)
  const bindingId = String(id || "")
  const binding = arrayFrom(bindings).find(function (candidate) {
    return candidate && presentationId(candidate) === bindingId
  })
  if (!binding) {
    return {
      groups: groups,
      hiddenBindingIds: hiddenBindingIds
    }
  }

  const hiddenIndex = hiddenBindingIds.indexOf(bindingId)
  if (visible && hiddenIndex !== -1) {
    hiddenBindingIds = hiddenBindingIds.filter(function (candidate) {
      return candidate !== bindingId
    })
  } else if (!visible && hiddenIndex === -1) {
    hiddenBindingIds.push(bindingId)
  }

  if (!visible) {
    const group = bindingGroup(binding)
    const hasVisibleChild = bindingsForGroup(bindings, group).some(function (candidate) {
      return hiddenBindingIds.indexOf(presentationId(candidate)) === -1
    })
    const groupIndex = groups.indexOf(group)
    if (!hasVisibleChild && groupIndex !== -1) {
      groups = groups.filter(function (candidate) {
        return candidate !== group
      })
    }
  }

  return {
    groups: groups,
    hiddenBindingIds: hiddenBindingIds
  }
}
