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

  function test_registered_filter_is_empty_until_query_or_group_is_selected() {
    verify(typeof VisibilityModel.registeredBindings === "function",
           "registered shortcut filtering is missing")
    const source = [
      {
        id: "browser", presentation_id: "action-browser",
        modifiers: ["SUPER"], key: "B", description: "Chromium"
      }
    ]

    const result = VisibilityModel.registeredBindings(
      source, [], "", "", "ko")

    compare(result.length, 0)
    compare(source.length, 1)
  }

  function test_registered_group_filter_matches_the_exact_modifier_group() {
    verify(typeof VisibilityModel.registeredBindings === "function",
           "registered shortcut filtering is missing")
    const source = [
      {
        id: "plain", presentation_id: "action-plain",
        modifiers: ["SUPER"], key: "A", description: "Plain"
      },
      {
        id: "control", presentation_id: "action-control",
        modifiers: ["SUPER", "CTRL"], key: "A", description: "Control"
      }
    ]

    const result = VisibilityModel.registeredBindings(
      source, [], "", "SUPER", "en")

    compare(result.map(function(item) { return item.id }).join(","), "plain")
  }

  function test_registered_query_searches_title_chord_type_and_role_in_all_groups() {
    verify(typeof VisibilityModel.registeredBindings === "function",
           "registered shortcut filtering is missing")
    const source = [
      {
        id: "bluetooth", presentation_id: "action-bluetooth",
        modifiers: ["SUPER", "CTRL"], key: "B", description: "Bluetooth"
      },
      {
        id: "browser", presentation_id: "action-browser",
        modifiers: ["SUPER", "SHIFT"], key: "RETURN", description: "Browser"
      }
    ]
    const actions = [
      {
        id: "action-bluetooth", title: "Bluetooth",
        displayKind: "systemUi", roleKind: "", targetName: ""
      },
      {
        id: "action-browser", title: "Browser",
        displayKind: "desktopApp", roleKind: "browser", targetName: "Chromium"
      }
    ]

    const byKoreanType = VisibilityModel.registeredBindings(
      source, actions, "시스템 UI", "", "ko")
    const byRole = VisibilityModel.registeredBindings(
      source, actions, "browser", "", "en")
    const byChord = VisibilityModel.registeredBindings(
      source, actions, "shift return", "", "en")

    compare(byKoreanType.map(function(item) { return item.id }).join(","),
            "bluetooth")
    compare(byRole.map(function(item) { return item.id }).join(","), "browser")
    compare(byChord.map(function(item) { return item.id }).join(","), "browser")
    compare(byKoreanType[0].displayKind, "systemUi")
    compare(byRole[0].targetName, "Chromium")
  }

  function test_registered_query_and_group_are_combined_as_an_intersection() {
    verify(typeof VisibilityModel.registeredBindings === "function",
           "registered shortcut filtering is missing")
    const source = [
      {
        id: "plain-browser", presentation_id: "action-plain-browser",
        modifiers: ["SUPER"], key: "B", description: "Browser"
      },
      {
        id: "control-browser", presentation_id: "action-control-browser",
        modifiers: ["SUPER", "CTRL"], key: "B", description: "Browser"
      },
      {
        id: "control-audio", presentation_id: "action-control-audio",
        modifiers: ["SUPER", "CTRL"], key: "A", description: "Audio"
      }
    ]

    const result = VisibilityModel.registeredBindings(
      source, [], "browser", "SUPER+CTRL", "en")

    compare(result.map(function(item) { return item.id }).join(","),
            "control-browser")
  }

  function test_presented_agent_uses_the_concrete_target_name_and_cmd_icon() {
    verify(typeof VisibilityModel.presentedBindings === "function",
           "shared binding presentation is missing")
    if (typeof VisibilityModel.presentedBindings !== "function")
      return
    const bindings = [{
      id: "agent-binding", presentation_id: "agent-binding",
      modifiers: ["SUPER", "CTRL", "SHIFT"], key: "A",
      description: "Agent", label_key: "action.agent"
    }]
    const actions = [{
      id: "action-agent", modifiers: ["SUPER", "CTRL", "SHIFT"], key: "A",
      title: "Agent", labelKey: "action.agent", targetName: "Codex",
      agentName: "Codex", targetId: "agent:codex",
      displayKind: "cmd", roleKind: "agent"
    }]

    const result = VisibilityModel.presentedBindings(
      bindings, actions, [], "ko")

    compare(result.length, 1)
    compare(result[0].description, "Codex")
    compare(result[0].displayKind, "cmd")
    compare(result[0].roleKind, "agent")
    compare(result[0].icon, "utilities-terminal")
  }

  function test_enriched_action_does_not_join_a_new_binding_by_chord() {
    const bindings = [{
      id: "new-binding", presentation_id: "new-presentation",
      modifiers: ["SUPER", "CTRL", "SHIFT"], key: "A",
      description: "New action", label_key: ""
    }]
    const staleActions = [{
      id: "old-action", presentationId: "old-presentation",
      modifiers: ["SUPER", "CTRL", "SHIFT"], key: "A",
      title: "Agent", targetName: "Codex", agentName: "Codex",
      targetId: "agent:codex", displayKind: "cmd", roleKind: "agent"
    }]

    const result = VisibilityModel.presentedBindings(
      bindings, staleActions, [], "en")

    compare(result.length, 1)
    compare(result[0].description, "New action")
    compare(result[0].displayKind, "action")
    compare(result[0].roleKind, "")
  }

  function test_presented_apps_resolve_icons_by_exact_target_identity() {
    verify(typeof VisibilityModel.presentedBindings === "function",
           "shared binding presentation is missing")
    if (typeof VisibilityModel.presentedBindings !== "function")
      return
    const bindings = [
      {
        id: "chatgpt", presentation_id: "action-chatgpt",
        modifiers: ["SUPER"], key: "A", description: "ChatGPT",
        selection_kind: "application",
        selection_id: "application:chatgpt.desktop"
      },
      {
        id: "youtube", presentation_id: "action-youtube",
        modifiers: ["SUPER", "SHIFT"], key: "Y", description: "YouTube"
      }
    ]
    const actions = [
      {
        id: "action-chatgpt", modifiers: ["SUPER"], key: "A",
        title: "ChatGPT", targetName: "ChatGPT",
        targetId: "application:chatgpt.desktop",
        displayKind: "desktopApp", roleKind: ""
      },
      {
        id: "action-youtube", modifiers: ["SUPER", "SHIFT"], key: "Y",
        title: "YouTube", targetId: "webapp:https://youtube.com/",
        displayKind: "webapp", roleKind: ""
      }
    ]
    const catalog = [
      {
        id: "application:wrong-youtube.desktop", title: "YouTube",
        targetId: "application:wrong-youtube.desktop", icon: "wrong-icon"
      },
      {
        id: "application:chatgpt.desktop", title: "ChatGPT",
        targetId: "application:chatgpt.desktop", icon: "chatgpt"
      },
      {
        id: "application:YouTube.desktop", title: "YouTube",
        targetId: "webapp:https://youtube.com/", icon: "youtube"
      }
    ]

    const result = VisibilityModel.presentedBindings(
      bindings, actions, catalog, "en")

    compare(result.length, 2)
    compare(result[0].icon, "chatgpt")
    compare(result[1].icon, "youtube")
  }

  function test_registered_titles_follow_the_selected_language_but_keep_app_names() {
    verify(typeof VisibilityModel.registeredBindings === "function",
           "registered shortcut filtering is missing")
    const source = [
      {
        id: "terminal", presentation_id: "action-terminal",
        modifiers: ["SUPER"], key: "RETURN", description: "Terminal",
        label_key: "action.terminal"
      },
      {
        id: "chatgpt", presentation_id: "action-chatgpt",
        modifiers: ["SUPER"], key: "A", description: "ChatGPT",
        label_key: ""
      },
      {
        id: "custom-terminal", presentation_id: "action-custom-terminal",
        modifiers: ["SUPER"], key: "T", description: "작업 터미널",
        label_key: "action.terminal", title_override: "작업 터미널"
      }
    ]
    const actions = [
      {
        id: "action-terminal", title: "Terminal",
        labelKey: "action.terminal", displayKind: "cmd"
      },
      {
        id: "action-chatgpt", title: "ChatGPT",
        labelKey: "", displayKind: "desktopApp", targetName: "ChatGPT"
      },
      {
        id: "action-custom-terminal", title: "작업 터미널",
        labelKey: "action.terminal", titleOverride: "작업 터미널",
        displayKind: "cmd"
      }
    ]

    const result = VisibilityModel.registeredBindings(
      source, actions, "a", "SUPER", "ko")

    compare(result.length, 3)
    compare(result[0].description, "터미널")
    compare(result[1].description, "ChatGPT")
    compare(result[2].description, "작업 터미널")
  }

  function test_action_type_presentation_is_shared_by_search_and_registered_rows() {
    verify(typeof VisibilityModel.typeBadgeKey === "function",
           "shared action type labels are missing")
    verify(typeof VisibilityModel.typeAccent === "function",
           "shared action type colors are missing")

    compare(VisibilityModel.typeBadgeKey("desktopApp"), "search.desktopAppBadge")
    compare(VisibilityModel.typeBadgeKey("webapp"), "search.webAppBadge")
    compare(VisibilityModel.typeBadgeKey("cmd"), "search.cmdBadge")
    compare(VisibilityModel.typeBadgeKey("action"), "search.actionBadge")
    compare(VisibilityModel.typeBadgeKey("systemUi"), "search.systemUiBadge")
    compare(VisibilityModel.typeAccent("desktopApp", true, "#123456"), "#1557b0")
    compare(VisibilityModel.typeAccent("desktopApp", false, "#123456"), "#82b1ff")
    compare(VisibilityModel.typeAccent("systemUi", true, "#123456"), "#9b174c")
    compare(VisibilityModel.typeAccent("unknown", false, "#123456"), "#123456")
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
