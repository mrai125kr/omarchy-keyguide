import QtQuick
import QtTest
import "../../src/plugin/HudModel.js" as HudModel

TestCase {
  name: "HudModel"

  property var sampleBindings

  function init() {
    sampleBindings = [
      {
        id: "terminal",
        modifiers: ["SUPER"],
        key: "RETURN",
        description: "Terminal"
      },
      {
        id: "menu",
        modifiers: ["SUPER"],
        key: "SPACE",
        description: "Omarchy menu"
      },
      {
        id: "browser",
        modifiers: ["SUPER", "CTRL"],
        key: "B",
        description: "Browser"
      },
      {
        id: "editor",
        modifiers: ["SUPER", "CTRL"],
        key: "E",
        description: "Editor"
      }
    ]
  }

  function test_exact_modifier_filter() {
    const visible = HudModel.forGroup(sampleBindings, ["SUPER", "CTRL"], [])

    compare(visible.length, 2)
    verify(visible.every(item => item.modifiers.join("+") === "SUPER+CTRL"))
  }

  function test_unknown_modifier_does_not_match_known_group() {
    const binding = {
      id: "unknown-modifier",
      modifiers: ["SUPER", "CTRL", "UNKNOWN"],
      key: "U",
      description: "Unknown"
    }

    compare(HudModel.forGroup([binding], ["SUPER", "CTRL"], []).length, 0)
  }

  function test_hidden_items_are_presentation_only() {
    const visible = HudModel.forGroup(sampleBindings, ["SUPER"], ["terminal"])

    compare(visible.length, 1)
    compare(visible[0].id, "menu")
    compare(sampleBindings.length, 4)
    compare(sampleBindings[0].id, "terminal")
  }

  function test_hidden_presentation_identity_survives_title_and_key_changes() {
    const changed = {
      id: "fresh-auth-id-after-move",
      presentation_id: "terminal-visibility",
      modifiers: ["SUPER"],
      key: "N",
      description: "Renamed Terminal"
    }

    compare(
      HudModel.forGroup([changed], ["SUPER"], ["terminal-visibility"]).length,
      0
    )
    compare(HudModel.forGroup([changed], ["SUPER"], []).length, 1)
  }

  function test_locked_session_forces_hidden() {
    verify(!HudModel.shouldShow({
      enabled: true,
      locked: true,
      superPressed: true,
      groupEnabled: true,
      bindingCount: 2
    }))
  }

  function test_visibility_requires_enabled_group_with_bindings() {
    verify(!HudModel.shouldShow({
      enabled: true,
      locked: false,
      superPressed: true,
      groupEnabled: false,
      bindingCount: 2
    }))
    verify(!HudModel.shouldShow({
      enabled: true,
      locked: false,
      superPressed: true,
      groupEnabled: true,
      bindingCount: 0
    }))
  }

  function test_action_and_wheel_state_force_hidden() {
    const visibleState = {
      enabled: true,
      locked: false,
      superPressed: true,
      groupEnabled: true,
      bindingCount: 2,
      actionPressed: false,
      wheelSuppressed: false
    }

    verify(HudModel.shouldShow(visibleState))
    visibleState.actionPressed = true
    verify(!HudModel.shouldShow(visibleState))
    visibleState.actionPressed = false
    visibleState.wheelSuppressed = true
    verify(!HudModel.shouldShow(visibleState))
  }

  function test_dismissal_latched_for_super_cycle_forces_hidden() {
    const visibleState = {
      enabled: true,
      locked: false,
      superPressed: true,
      groupEnabled: true,
      bindingCount: 2,
      actionPressed: false,
      wheelSuppressed: false,
      dismissedForSuperCycle: false
    }

    verify(HudModel.shouldShow(visibleState))
    visibleState.dismissedForSuperCycle = true
    verify(!HudModel.shouldShow(visibleState))
  }

  function test_observer_state_uses_canonical_modifier_order() {
    compare(
      HudModel.modifiersForState({
        super: true,
        ctrl: true,
        shift: true,
        alt: false
      }).join("+"),
      "SUPER+CTRL+SHIFT"
    )
  }
}
