.pragma library
.import "I18n.js" as I18n

const modifierOrder = ["SUPER", "CTRL", "SHIFT", "ALT"]

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
