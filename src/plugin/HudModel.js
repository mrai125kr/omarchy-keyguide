.pragma library

const modifierOrder = ["SUPER", "CTRL", "SHIFT", "ALT"]

function canonicalModifiers(modifiers) {
  if (!Array.isArray(modifiers)) return null
  const canonical = modifierOrder.filter(modifier => modifiers.indexOf(modifier) !== -1)
  return canonical.length === modifiers.length ? canonical : null
}

function sameModifiers(left, right) {
  const canonicalLeft = canonicalModifiers(left)
  const canonicalRight = canonicalModifiers(right)
  return canonicalLeft !== null
    && canonicalRight !== null
    && canonicalLeft.length === canonicalRight.length
    && canonicalLeft.every((modifier, index) => modifier === canonicalRight[index])
}

function forGroup(bindings, modifiers, hiddenBindingIds) {
  const source = Array.isArray(bindings) ? bindings : []
  const hidden = Array.isArray(hiddenBindingIds) ? hiddenBindingIds : []
  return source.filter(binding => binding
    && hidden.indexOf(binding.presentation_id || binding.id) === -1
    && sameModifiers(binding.modifiers, modifiers))
}

function shouldShow(state) {
  return state !== null
    && typeof state === "object"
    && state.enabled === true
    && state.locked !== true
    && state.superPressed === true
    && state.actionPressed !== true
    && state.wheelSuppressed !== true
    && state.dismissedForSuperCycle !== true
    && state.groupEnabled !== false
    && (state.bindingCount === undefined || state.bindingCount > 0)
}

function modifiersForState(state) {
  const source = state || {}
  const modifiers = []
  if (source.super === true) modifiers.push("SUPER")
  if (source.ctrl === true) modifiers.push("CTRL")
  if (source.shift === true) modifiers.push("SHIFT")
  if (source.alt === true) modifiers.push("ALT")
  return modifiers
}
