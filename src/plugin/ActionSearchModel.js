.pragma library
.import "I18n.js" as I18n

const scoreExact = 400
const scorePrefix = 300
const scoreWordPrefix = 200
const scoreSubstring = 100
const kindOrder = { application: 0, action: 1, command: 2 }

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
  const title = I18n.actionTitle(language, labelKey, fallback)
  const englishTitle = I18n.actionTitle("en", labelKey, fallback)
  const currentChord = chordLabel(
    language, action && action.modifiers, action && action.key)
  return {
    kind: "action",
    id: String(action && action.id || ""),
    title: title,
    englishTitle: englishTitle,
    summary: String(action && action.actionKind || ""),
    icon: "",
    path: "",
    keywords: [title, englishTitle, fallback, currentChord],
    labelKey: labelKey,
    badgeKind: String(action && action.launchKind || ""),
    currentChord: currentChord,
    score: 0
  }
}

function catalogResult(item, registeredChords) {
  const id = String(item && item.id || "")
  return {
    kind: String(item && item.kind || ""),
    id: id,
    title: String(item && item.title || ""),
    englishTitle: String(item && item.englishTitle || item && item.title || ""),
    summary: String(item && item.summary || ""),
    icon: String(item && item.icon || ""),
    path: String(item && item.path || ""),
    keywords: arrayFrom(item && item.keywords).map(function(keyword) {
      return String(keyword || "")
    }),
    labelKey: "",
    currentChord: arrayFrom(registeredChords && registeredChords[id]).join(" · "),
    score: 0
  }
}

function appendChord(result, id, chord) {
  if (!id || !chord)
    return
  if (!result[id])
    result[id] = []
  if (result[id].indexOf(chord) === -1)
    result[id].push(chord)
}

function registeredChordLinks(language, actions, catalogItems) {
  const chords = ({})
  arrayFrom(actions).forEach(function(action) {
    const selectionKind = String(action && action.selectionKind || "action")
    const selectionId = String(action && action.selectionId || "")
    const chord = chordLabel(language, action.modifiers, action.key)
    if (!chord)
      return
    if ((selectionKind === "application" || selectionKind === "command")
        && selectionId) {
      appendChord(chords, selectionId, chord)
    }
  })
  return { chords: chords }
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

function compareResults(left, right) {
  const leftKind = kindOrder[left.kind] === undefined ? 99 : kindOrder[left.kind]
  const rightKind = kindOrder[right.kind] === undefined ? 99 : kindOrder[right.kind]
  if (leftKind !== rightKind)
    return leftKind - rightKind
  if (left.score !== right.score)
    return right.score - left.score
  const titleOrder = normalized(left.title).localeCompare(normalized(right.title))
  if (titleOrder !== 0)
    return titleOrder
  return String(left.id).localeCompare(String(right.id))
}

function results(query, language, actions, catalogItems, limit) {
  const needle = normalized(query)
  const links = registeredChordLinks(language, actions, catalogItems)
  const candidates = arrayFrom(catalogItems).map(function(item) {
    return catalogResult(item, links.chords)
  }).concat(arrayFrom(actions).filter(function(action) {
    const selectionKind = String(action && action.selectionKind || "action")
    return selectionKind === "action"
  }).map(function(action) {
    return actionResult(language, action)
    }))
  if (!needle) {
    return limited(candidates.filter(function(item) {
      return item.id
    }).sort(compareResults), limit)
  }
  return limited(candidates.map(function(item) {
    item.score = bestScore(searchFields(item), needle)
    return item
  }).filter(function(item) {
    return item.id && item.score > 0
  }).sort(compareResults), limit)
}
