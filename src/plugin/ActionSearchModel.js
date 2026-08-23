.pragma library
.import "I18n.js" as I18n
.import "VisibilityModel.js" as VisibilityModel

const scoreExact = 400
const scorePrefix = 300
const scoreWordPrefix = 200
const scoreSubstring = 100

function arrayFrom(value) {
  if (!value || typeof value.length !== "number")
    return []
  const result = []
  for (let index = 0; index < value.length; index += 1)
    result.push(value[index])
  return result
}

function normalized(value) {
  let result = String(value || "")
  if (typeof result.normalize === "function")
    result = result.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  return result.toLocaleLowerCase().trim().replace(/\s+/g, " ")
}

function chordLabel(language, modifiers, key) {
  const parts = arrayFrom(modifiers).map(function(modifier) {
    return I18n.modifier(language, modifier)
  })
  const keyName = String(key || "")
  if (keyName)
    parts.push(keyName)
  return parts.join(" + ")
}

function requestedLimit(limit) {
  const requested = Number(limit)
  if (!Number.isFinite(requested) || requested <= 0)
    return 0
  return Math.max(1, Math.floor(requested))
}

function limited(items, limit) {
  const count = requestedLimit(limit)
  return count > 0 ? items.slice(0, count) : items
}

function scoreField(field, query) {
  const value = normalized(field)
  if (!value)
    return 0
  if (value === query)
    return scoreExact
  if (value.indexOf(query) === 0)
    return scorePrefix
  const words = value.split(" ")
  if (words.some(function(word) { return word.indexOf(query) === 0 }))
    return scoreWordPrefix
  return value.indexOf(query) !== -1 ? scoreSubstring : 0
}

function bestScore(fields, query) {
  let best = 0
  arrayFrom(fields).forEach(function(field) {
    best = Math.max(best, scoreField(field, query))
  })
  return best
}

function actionResult(language, action) {
  const fallback = String(action && action.title || "")
  const labelKey = String(action && action.labelKey
    || I18n.actionKey(fallback) || "")
  const baseTitle = I18n.actionTitle(language, labelKey, fallback)
  const englishTitle = I18n.actionTitle("en", labelKey, fallback)
  const agentName = String(action && action.agentName || "")
  const browserName = String(action && action.browserName || "")
  const targetName = String(action && action.targetName || "")
  const declaredRole = String(action && action.roleKind || "")
  const declaredDisplayValue = String(action && action.displayKind || "")
  const declaredDisplay = declaredDisplayValue === "command"
    ? "action" : declaredDisplayValue
  const selectionKind = String(action && action.selectionKind || "action")
  const launchKind = String(action && action.launchKind || "")
  const actionKind = String(action && action.actionKind || "")
  const isAgent = declaredRole === "agent" || (labelKey === "action.agent" && agentName)
  const isBrowser = declaredRole === "browser" || (labelKey === "action.browser" && browserName)
  const isEditor = declaredRole === "editor"
  const browserSearchName = declaredRole === "browser" && !targetName
    ? "" : browserName
  const title = targetName || (declaredRole ? baseTitle
    : (isAgent ? agentName : (isBrowser ? browserName : baseTitle)))
  const currentChord = chordLabel(
    language, action && action.modifiers, action && action.key)
  const badgeKind = declaredDisplay || (isAgent ? "cmd"
    : (isBrowser ? "desktopApp"
      : (launchKind === "webapp" ? "webapp"
        : (selectionKind === "application" ? "desktopApp"
          : "action"))))
  const roleBadgeKind = declaredRole || (isAgent ? "agent" : (isBrowser ? "browser" : ""))
  const targetId = String(action && action.targetId || "")
    || (selectionKind !== "action" && action && action.selectionId
      ? String(action.selectionId) : "action:" + String(action && action.id || ""))
  return {
    kind: "action",
    id: String(action && action.id || ""),
    title: title,
    englishTitle: englishTitle,
    summary: actionKind,
    icon: VisibilityModel.fallbackIcon(
      badgeKind, roleBadgeKind, browserName),
    path: "",
    keywords: [title, baseTitle, englishTitle, fallback, currentChord,
      agentName, browserSearchName, targetName, isAgent ? "CLI Agent" : "",
      agentName === "Codex" ? "GPT" : "", isBrowser ? "Browser" : "",
      browserSearchName === "Chromium" ? "Chrome" : "", isEditor ? "Editor" : ""],
    labelKey: labelKey,
    badgeKind: badgeKind,
    roleBadgeKind: roleBadgeKind,
    targetId: targetId,
    currentChord: currentChord,
    currentChords: currentChord ? [currentChord] : [],
    currentShortcuts: currentChord ? [{
      chord: currentChord,
      badgeKind: badgeKind,
      roleBadgeKind: roleBadgeKind
    }] : [],
    registered: currentChord !== "",
    score: 0
  }
}

function catalogResult(item) {
  const id = String(item && item.id || "")
  const badgeKind = String(item && item.launchKind || "")
    || (String(item && item.kind || "") === "application"
      ? "desktopApp" : "command")
  const icon = String(item && item.icon || "")
  return {
    kind: String(item && item.kind || ""),
    id: id,
    title: String(item && item.title || ""),
    englishTitle: String(item && item.englishTitle || item && item.title || ""),
    summary: String(item && item.summary || ""),
    icon: icon || VisibilityModel.fallbackIcon(badgeKind, "", ""),
    path: String(item && item.path || ""),
    keywords: arrayFrom(item && item.keywords).map(function(keyword) {
      return String(keyword || "")
    }),
    labelKey: "",
    badgeKind: badgeKind,
    roleBadgeKind: "",
    targetId: String(item && item.targetId || id),
    currentChord: "",
    currentChords: [],
    currentShortcuts: [],
    registered: false,
    score: 0
  }
}

function registeredActionResults(language, actions, catalogTargets) {
  const groups = ({})
  const order = []
  arrayFrom(actions).forEach(function(action) {
    const selectionKind = String(action && action.selectionKind || "action")
    const selectionId = String(action && action.selectionId || "")
    const actionId = String(action && action.id || "")
    const declaredTarget = String(action && action.targetId || "")
    const targetId = selectionKind !== "action" && selectionId
        && catalogTargets[selectionId]
      ? catalogTargets[selectionId]
      : (declaredTarget || (selectionKind !== "action" && selectionId
          ? selectionId : "action:" + actionId))
    const groupId = targetId || "action:" + actionId
    if (!groups[groupId]) {
      groups[groupId] = []
      order.push(groupId)
    }
    groups[groupId].push(action)
  })
  return order.map(function(groupId) {
    const grouped = groups[groupId]
    const result = actionResult(language, grouped[0])
    result.targetId = groupId
    const shortcuts = []
    grouped.forEach(function(action) {
      const candidate = actionResult(language, action)
      const chord = candidate.currentChord
      if (chord && !shortcuts.some(function(shortcut) {
        return shortcut.chord === chord
      })) {
        shortcuts.push({
          chord: chord,
          badgeKind: candidate.badgeKind,
          roleBadgeKind: candidate.roleBadgeKind
        })
      }
    })
    const chords = shortcuts.map(function(shortcut) { return shortcut.chord })
    result.currentShortcuts = shortcuts
    result.currentChords = chords.slice()
    result.currentChord = chords.join(" · ")
    result.keywords = result.keywords.concat(chords)
    result.registered = chords.length > 0
    return result
  })
}

function appendUnique(target, values) {
  arrayFrom(values).forEach(function(value) {
    if (value && target.indexOf(value) === -1)
      target.push(value)
  })
}

function shortcutEntries(item) {
  const result = []
  arrayFrom(item && item.currentShortcuts).forEach(function(shortcut) {
    const chord = String(shortcut && shortcut.chord || "")
    if (!chord || result.some(function(candidate) {
      return candidate.chord === chord
    })) return
    result.push({
      chord: chord,
      badgeKind: String(shortcut && shortcut.badgeKind
        || item && item.badgeKind || "action"),
      roleBadgeKind: String(shortcut && shortcut.roleBadgeKind || "")
    })
  })
  if (result.length > 0)
    return result
  const chords = arrayFrom(item && item.currentChords)
  if (chords.length === 0 && item && item.currentChord)
    appendUnique(chords, String(item.currentChord).split(" · "))
  chords.forEach(function(chord) {
    const value = String(chord || "")
    if (value) result.push({
      chord: value,
      badgeKind: String(item && item.badgeKind || "action"),
      roleBadgeKind: String(item && item.roleBadgeKind || "")
    })
  })
  return result
}

function appendUniqueShortcuts(target, values) {
  arrayFrom(values).forEach(function(value) {
    if (!value || !value.chord || target.some(function(candidate) {
      return candidate.chord === value.chord
    })) return
    target.push(value)
  })
}

function mergedTargets(catalogResults, actionResults) {
  const groups = ({})
  const order = []
  catalogResults.concat(actionResults).forEach(function(candidate) {
    const groupId = String(candidate.targetId || "")
      || String(candidate.kind || "") + "\u0000" + String(candidate.id || "")
    if (!groups[groupId]) {
      groups[groupId] = candidate
      groups[groupId].targetId = groupId
      order.push(groupId)
      return
    }
    const result = groups[groupId]
    const shortcuts = shortcutEntries(result)
    appendUniqueShortcuts(shortcuts, shortcutEntries(candidate))
    const chords = shortcuts.map(function(shortcut) { return shortcut.chord })
    result.currentShortcuts = shortcuts
    result.currentChords = chords.slice()
    result.currentChord = chords.join(" · ")
    result.registered = result.registered || candidate.registered
    appendUnique(result.keywords, candidate.keywords)
    if (!result.roleBadgeKind && candidate.roleBadgeKind)
      result.roleBadgeKind = candidate.roleBadgeKind
    if (candidate.roleBadgeKind)
      result.badgeKind = candidate.badgeKind
    if (candidate.badgeKind === "webapp")
      result.badgeKind = "webapp"
    if ((!result.icon || result.icon === VisibilityModel.fallbackIcon(
          result.badgeKind, "", ""))
        && candidate.icon)
      result.icon = candidate.icon
  })
  return order.map(function(groupId) { return groups[groupId] })
}

function searchFields(item) {
  if (item.kind === "action") {
    return [item.title, item.englishTitle, item.currentChord]
      .concat(item.keywords)
  }
  if (item.kind === "command") {
    const pieces = item.path.split("/")
    const basename = pieces.length > 0 ? pieces[pieces.length - 1] : ""
    return [item.title, item.englishTitle, basename, item.currentChord]
      .concat(item.keywords)
  }
  return [item.title, item.englishTitle, item.summary, item.currentChord]
    .concat(item.keywords)
}

function localeCode(language) {
  const locales = {
    en: "en-US", ko: "ko-KR", ja: "ja-JP",
    zh_CN: "zh-CN", es: "es-ES"
  }
  return locales[String(language || "")] || "en-US"
}

function numericTextOrder(left, right) {
  const leftValue = String(left || "").replace(/^0+/, "") || "0"
  const rightValue = String(right || "").replace(/^0+/, "") || "0"
  if (leftValue.length !== rightValue.length)
    return leftValue.length - rightValue.length
  const valueOrder = leftValue.localeCompare(rightValue)
  if (valueOrder !== 0)
    return valueOrder
  return String(left).length - String(right).length
}

function naturalTitleOrder(left, right, language) {
  // This is the deterministic fallback used before limiting and by isolated
  // model consumers. ActionSearch.qml applies Qt's locale-aware StringSorter
  // to the complete UI result set because QML JavaScript ignores the locale
  // argument to String.localeCompare on supported Qt runtimes.
  const leftSegments = normalized(left).match(/\d+|\D+/g) || []
  const rightSegments = normalized(right).match(/\d+|\D+/g) || []
  const count = Math.min(leftSegments.length, rightSegments.length)
  for (let index = 0; index < count; index += 1) {
    const leftSegment = leftSegments[index]
    const rightSegment = rightSegments[index]
    const leftNumeric = /^\d+$/.test(leftSegment)
    const rightNumeric = /^\d+$/.test(rightSegment)
    let order = 0
    if (leftNumeric && rightNumeric)
      order = numericTextOrder(leftSegment, rightSegment)
    else
      order = leftSegment.localeCompare(rightSegment, localeCode(language))
    if (order !== 0)
      return order
  }
  return leftSegments.length - rightSegments.length
}

function compareResults(left, right, language) {
  if (left.score !== right.score)
    return right.score - left.score
  if (left.registered !== right.registered)
    return left.registered ? -1 : 1
  const titleOrder = naturalTitleOrder(left.title, right.title, language)
  if (titleOrder !== 0)
    return titleOrder
  const targetOrder = String(left.targetId).localeCompare(String(right.targetId))
  if (targetOrder !== 0)
    return targetOrder
  return String(left.id).localeCompare(String(right.id))
}

function results(query, language, actions, catalogItems, limit) {
  const needle = normalized(query)
  const catalogTargets = ({})
  arrayFrom(catalogItems).forEach(function(item) {
    const id = String(item && item.id || "")
    if (id)
      catalogTargets[id] = String(item && item.targetId || id)
  })
  const catalogResults = arrayFrom(catalogItems).filter(function(item) {
    return String(item && item.kind || "") === "application"
  }).map(function(item) {
    return catalogResult(item)
  })
  const candidates = mergedTargets(
    catalogResults,
    registeredActionResults(language, actions, catalogTargets))
  const resultOrder = function(left, right) {
    return compareResults(left, right, language)
  }
  if (!needle) {
    return limited(candidates.filter(function(item) {
      return item.id
    }).sort(resultOrder), limit)
  }
  return limited(candidates.map(function(item) {
    item.score = bestScore(searchFields(item), needle)
    return item
  }).filter(function(item) {
    return item.id && item.score > 0
  }).sort(resultOrder), limit)
}
