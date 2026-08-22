import QtQuick
import QtTest
import "../../src/plugin/VisibilityModel.js" as VisibilityModel

TestCase {
  name: "VisibilityModel"

  readonly property var groupOptions: [
    "SUPER", "SUPER+CTRL", "SUPER+SHIFT", "SUPER+ALT",
    "SUPER+CTRL+SHIFT", "SUPER+CTRL+ALT",
    "SUPER+SHIFT+ALT", "SUPER+CTRL+SHIFT+ALT"
  ]

  property var bindings

  function binding(id, group) {
    return {
      id: id,
      modifiers: group.split("+"),
      key: id.toUpperCase(),
      description: id
    }
  }

  function init() {
    bindings = [
      binding("super-a", "SUPER"),
      binding("super-b", "SUPER"),
      binding("ctrl", "SUPER+CTRL"),
      binding("shift", "SUPER+SHIFT"),
      binding("alt", "SUPER+ALT"),
      binding("ctrl-shift", "SUPER+CTRL+SHIFT"),
      binding("ctrl-alt", "SUPER+CTRL+ALT"),
      binding("shift-alt", "SUPER+SHIFT+ALT"),
      binding("all", "SUPER+CTRL+SHIFT+ALT")
    ]
  }

  function test_sections_preserve_canonical_eight_group_order() {
    const sections = VisibilityModel.sections(bindings.slice().reverse(), groupOptions)

    compare(sections.length, 8)
    compare(sections.map(function (section) { return section.group }).join("|"),
            groupOptions.join("|"))
    compare(sections[0].bindings.map(function (item) { return item.id }).join(","),
            "super-b,super-a")
  }

  function test_sections_omit_empty_groups_without_mutating_bindings() {
    const sparseBindings = [bindings[0], bindings[4], bindings[8]]
    const before = JSON.stringify(sparseBindings)
    const sections = VisibilityModel.sections(sparseBindings, groupOptions)

    compare(sections.map(function (section) { return section.group }).join("|"),
            "SUPER|SUPER+ALT|SUPER+CTRL+SHIFT+ALT")
    compare(JSON.stringify(sparseBindings), before)
  }

  function test_section_for_group_keeps_the_selected_empty_group() {
    const section = VisibilityModel.sectionForGroup([], "SUPER+SHIFT")

    compare(section.group, "SUPER+SHIFT")
    compare(section.bindings.length, 0)
  }

  function test_key_options_keep_backend_order_and_status_labels() {
    const status = {
      keyOptionsByGroup: {
        "SUPER": [
          { key: "N", state: "free", title: "", bindingId: "", actionId: "" },
          { key: "A", state: "assigned", title: "Alpha", bindingId: "alpha", actionId: "action-alpha" }
        ]
      },
      actions: []
    }

    const options = VisibilityModel.keyOptions(status, "SUPER", "en")

    compare(options.map(function(option) { return option.key }).join(","), "N,A")
    compare(options.map(function(option) { return option.label }).join("|"),
            "N · Available|A · Assigned — Alpha")
    compare(VisibilityModel.keyOption(status, "SUPER", "A", "en").bindingId, "alpha")
    compare(VisibilityModel.keyOption(status, "SUPER", "Z", "en"), null)

    const korean = VisibilityModel.keyOptions(status, "SUPER", "ko")
    compare(korean.map(function(option) { return option.label }).join("|"),
            "N · 사용 가능|A · 지정됨 — Alpha")
  }

  function test_action_options_include_current_chord_and_only_allow_free_targets() {
    const status = {
      keyOptionsByGroup: {},
      actions: [
        { id: "alpha", title: "Alpha", actionKind: "exec", modifiers: ["SUPER"], key: "A" },
        { id: "beta", title: "Beta", actionKind: "lua", modifiers: ["SUPER", "CTRL"], key: "B" }
      ]
    }

    status.actions[0].labelKey = "action.terminal"
    status.actions[0].title = "Terminal"
    const freeOptions = VisibilityModel.actionOptions(status, { state: "free" }, "ko")
    const assignedOptions = VisibilityModel.actionOptions(status, { state: "assigned" }, "ko")

    compare(freeOptions.map(function(option) { return option.label }).join("|"),
            "터미널 · exec · Super + A|Beta · lua · Super + Ctrl + B")
    verify(freeOptions.every(function(option) { return option.selectable }))
    verify(assignedOptions.every(function(option) { return !option.selectable }))
  }

  function test_disabling_master_preserves_partial_hidden_selection() {
    const settings = {
      groups: groupOptions.slice(),
      hiddenBindingIds: ["super-a", "stale-id"]
    }
    const beforeBindings = JSON.stringify(bindings)
    const patch = VisibilityModel.toggleGroup(settings, bindings, "SUPER", false)

    verify(patch.groups.indexOf("SUPER") === -1)
    compare(patch.hiddenBindingIds.join(","), "super-a,stale-id")
    compare(settings.groups.join("|"), groupOptions.join("|"))
    compare(settings.hiddenBindingIds.join(","), "super-a,stale-id")
    compare(JSON.stringify(bindings), beforeBindings)
    verify(patch.groups !== settings.groups)
    verify(patch.hiddenBindingIds !== settings.hiddenBindingIds)
  }

  function test_enabling_master_restores_partial_hidden_selection() {
    const settings = {
      groups: ["SUPER+CTRL"],
      hiddenBindingIds: ["super-a", "stale-id"]
    }
    const patch = VisibilityModel.toggleGroup(settings, bindings, "SUPER", true)

    verify(patch.groups.indexOf("SUPER") !== -1)
    compare(patch.hiddenBindingIds.join(","), "super-a,stale-id")
  }

  function test_disabling_master_removes_every_duplicate_group_entry() {
    const settings = {
      groups: ["SUPER", "SUPER+CTRL", "SUPER"],
      hiddenBindingIds: []
    }
    const patch = VisibilityModel.toggleGroup(settings, bindings, "SUPER", false)

    compare(patch.groups.join(","), "SUPER+CTRL")
    compare(settings.groups.join(","), "SUPER,SUPER+CTRL,SUPER")
  }

  function test_enabling_all_hidden_group_shows_current_children_only() {
    const settings = {
      groups: ["SUPER+CTRL"],
      hiddenBindingIds: ["super-a", "stale-id", "super-b", "ctrl"]
    }
    const beforeBindings = JSON.stringify(bindings)
    const patch = VisibilityModel.toggleGroup(settings, bindings, "SUPER", true)

    verify(patch.groups.indexOf("SUPER") !== -1)
    compare(patch.hiddenBindingIds.join(","), "stale-id,ctrl")
    compare(settings.groups.join(","), "SUPER+CTRL")
    compare(settings.hiddenBindingIds.join(","), "super-a,stale-id,super-b,ctrl")
    compare(JSON.stringify(bindings), beforeBindings)
  }

  function test_hiding_one_of_two_visible_children_keeps_master_on() {
    const settings = {
      groups: ["SUPER", "SUPER+CTRL"],
      hiddenBindingIds: ["stale-id"]
    }
    const patch = VisibilityModel.toggleBinding(settings, bindings, "super-a", false)

    verify(patch.groups.indexOf("SUPER") !== -1)
    compare(patch.hiddenBindingIds.join(","), "stale-id,super-a")
  }

  function test_hiding_last_visible_child_turns_master_off() {
    const settings = {
      groups: ["SUPER", "SUPER+CTRL"],
      hiddenBindingIds: ["super-a", "stale-id"]
    }
    const patch = VisibilityModel.toggleBinding(settings, bindings, "super-b", false)

    verify(patch.groups.indexOf("SUPER") === -1)
    compare(patch.hiddenBindingIds.join(","), "super-a,stale-id,super-b")
  }

  function test_hiding_last_visible_child_removes_every_duplicate_group_entry() {
    const settings = {
      groups: ["SUPER", "SUPER+CTRL", "SUPER"],
      hiddenBindingIds: ["super-a"]
    }
    const patch = VisibilityModel.toggleBinding(settings, bindings, "super-b", false)

    compare(patch.groups.join(","), "SUPER+CTRL")
    compare(settings.groups.join(","), "SUPER,SUPER+CTRL,SUPER")
  }

  function test_showing_child_preserves_master_state_and_stale_ids() {
    const settings = {
      groups: ["SUPER+CTRL"],
      hiddenBindingIds: ["super-a", "stale-id", "super-b"]
    }
    const patch = VisibilityModel.toggleBinding(settings, bindings, "super-a", true)

    verify(patch.groups.indexOf("SUPER") === -1)
    compare(patch.hiddenBindingIds.join(","), "stale-id,super-b")
  }

  function test_showing_child_removes_every_duplicate_hidden_entry() {
    const settings = {
      groups: ["SUPER"],
      hiddenBindingIds: ["super-a", "stale-id", "super-a"]
    }
    const patch = VisibilityModel.toggleBinding(settings, bindings, "super-a", true)

    compare(patch.hiddenBindingIds.join(","), "stale-id")
    compare(settings.hiddenBindingIds.join(","), "super-a,stale-id,super-a")
  }

  function test_unknown_binding_is_a_cloned_noop() {
    const settings = {
      groups: ["SUPER"],
      hiddenBindingIds: ["stale-id"]
    }
    const patch = VisibilityModel.toggleBinding(settings, bindings, "missing", false)

    compare(patch.groups.join(","), "SUPER")
    compare(patch.hiddenBindingIds.join(","), "stale-id")
    verify(patch.groups !== settings.groups)
    verify(patch.hiddenBindingIds !== settings.hiddenBindingIds)
  }

  function test_toggle_uses_stable_presentation_identity_not_auth_identity() {
    const changed = binding("fresh-auth-id-after-move", "SUPER")
    changed.presentation_id = "stable-visibility-id"
    const settings = { groups: ["SUPER"], hiddenBindingIds: [] }

    const hidden = VisibilityModel.toggleBinding(
      settings, [changed], "stable-visibility-id", false)
    compare(hidden.hiddenBindingIds.join(","), "stable-visibility-id")

    const shown = VisibilityModel.toggleBinding(
      hidden, [changed], "stable-visibility-id", true)
    compare(shown.hiddenBindingIds.join(","), "")
    compare(shown.groups.join(","), "")
  }

  function test_new_binding_reconciles_by_stable_id_without_rewriting_stale_choices() {
    const originalBindings = [
      binding("super-a", "SUPER"),
      binding("super-b", "SUPER")
    ]
    const settings = {
      groups: ["SUPER"],
      hiddenBindingIds: ["super-a", "removed-binding"]
    }
    const updatedBindings = [
      binding("super-a", "SUPER"),
      binding("super-c", "SUPER")
    ]
    const beforeSettings = JSON.stringify(settings)
    const beforeBindings = JSON.stringify(updatedBindings)

    const offPatch = VisibilityModel.toggleGroup(
      settings, updatedBindings, "SUPER", false)

    compare(offPatch.groups.join(","), "")
    compare(offPatch.hiddenBindingIds.join(","), "super-a,removed-binding")
    compare(JSON.stringify(settings), beforeSettings)
    compare(JSON.stringify(updatedBindings), beforeBindings)

    const onPatch = VisibilityModel.toggleGroup(
      offPatch, updatedBindings, "SUPER", true)

    compare(onPatch.groups.join(","), "SUPER")
    compare(onPatch.hiddenBindingIds.join(","), "super-a,removed-binding")

    const childPatch = VisibilityModel.toggleBinding(
      onPatch, updatedBindings, "super-c", false)

    compare(childPatch.groups.join(","), "")
    compare(
      childPatch.hiddenBindingIds.join(","),
      "super-a,removed-binding,super-c"
    )
    compare(JSON.stringify(originalBindings), JSON.stringify([
      binding("super-a", "SUPER"),
      binding("super-b", "SUPER")
    ]))
    compare(JSON.stringify(updatedBindings), beforeBindings)
  }
}
