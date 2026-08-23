import QtQuick
import QtTest
import "../../src/plugin/ActionSearchModel.js" as ActionSearchModel

TestCase {
  name: "ActionSearchModel"

  readonly property var terminalAction: ({
    id: "action-terminal",
    title: "Terminal",
    labelKey: "action.terminal",
    actionKind: "exec", displayKind: "cmd",
    modifiers: ["SUPER"],
    key: "RETURN"
  })

  function catalogItem(kind, id, title, englishTitle, summary, path, keywords) {
    return {
      kind: kind,
      id: id,
      title: title,
      englishTitle: englishTitle,
      summary: summary || "",
      icon: kind === "application" ? "application-x-executable" : "",
      path: path || "",
      keywords: keywords || [],
      targetId: id,
      launchKind: kind === "application" ? "desktopApp" : "command"
    }
  }

  function test_blank_query_shows_the_complete_visible_catalog() {
    const items = []
    for (let index = 0; index < 45; index += 1) {
      items.push(catalogItem(
        "application", "application:tool-" + index + ".desktop", "tool-" + index,
        "tool-" + index))
    }

    const found = ActionSearchModel.results(
      "   ", "en", [terminalAction], items, 0)

    compare(found.length, 46)
    compare(found[0].kind, "action")
    compare(found[0].id, terminalAction.id)
  }

  function test_korean_and_english_find_the_same_general_action() {
    compare(ActionSearchModel.results(
      "터미널", "ko", [terminalAction], [], 30)[0].id,
      "action-terminal")
    compare(ActionSearchModel.results(
      "terminal", "ko", [terminalAction], [], 30)[0].id,
      "action-terminal")
  }

  function test_agent_shows_codex_as_a_registered_command() {
    const agent = {
      id: "action-agent", title: "Agent", labelKey: "action.agent",
      actionKind: "exec", agentName: "Codex",
      modifiers: ["SUPER", "CTRL", "SHIFT"], key: "A"
    }

    const byCodex = ActionSearchModel.results("codex", "ko", [agent], [], 30)
    const byGpt = ActionSearchModel.results("gpt", "ko", [agent], [], 30)

    compare(byCodex.length, 1)
    compare(byGpt.length, 1)
    compare(byCodex[0].title, "Codex")
    compare(byCodex[0].badgeKind, "cmd")
    compare(byCodex[0].roleBadgeKind, "agent")
    compare(byCodex[0].currentChord, "Super + Ctrl + Shift + A")
  }

  function test_browser_shows_its_registered_desktop_application() {
    const browser = {
      id: "action-browser", title: "Browser", labelKey: "action.browser",
      actionKind: "exec", browserName: "Chromium",
      modifiers: ["SUPER"], key: "B"
    }

    const found = ActionSearchModel.results(
      "chrome", "ko", [browser], [], 30)

    compare(found.length, 1)
    compare(found[0].title, "Chromium")
    compare(found[0].badgeKind, "desktopApp")
    compare(found[0].roleBadgeKind, "browser")
    compare(found[0].currentChord, "Super + B")
  }

  function test_browser_role_merges_with_its_catalog_application_identity() {
    const chromium = catalogItem(
      "application", "application:chromium.desktop",
      "Chromium", "Chromium", "Web browser")
    chromium.icon = "chromium"
    const browser = {
      id: "action-browser", title: "Browser", labelKey: "action.browser",
      actionKind: "exec", displayKind: "desktopApp", roleKind: "browser",
      targetName: "Chromium", targetId: "application:chromium.desktop",
      modifiers: ["SUPER"], key: "B"
    }

    const found = ActionSearchModel.results(
      "chromium", "ko", [browser], [chromium], 30)

    compare(found.length, 1)
    compare(found[0].title, "Chromium")
    compare(found[0].icon, "chromium")
    compare(found[0].badgeKind, "desktopApp")
    compare(found[0].roleBadgeKind, "browser")
    compare(found[0].currentChord, "Super + B")
  }

  function test_one_browser_target_collects_every_registered_chord() {
    const chromium = catalogItem(
      "application", "application:chromium.desktop",
      "Chromium", "Chromium", "Web browser")
    const actions = [
      {
        id: "browser-b", title: "Browser", labelKey: "action.browser",
        actionKind: "exec", displayKind: "desktopApp", roleKind: "browser",
        targetName: "Chromium", targetId: "application:chromium.desktop",
        modifiers: ["SUPER", "SHIFT"], key: "B"
      },
      {
        id: "browser-return", title: "Browser", labelKey: "action.browser",
        actionKind: "exec", displayKind: "desktopApp", roleKind: "browser",
        targetName: "Chromium", targetId: "application:chromium.desktop",
        modifiers: ["SUPER", "SHIFT"], key: "RETURN"
      }
    ]

    const found = ActionSearchModel.results(
      "chromium", "en", actions, [chromium], 30)

    compare(found.length, 1)
    compare(found[0].currentChord, "Super + Shift + B · Super + Shift + RETURN")
    compare(found[0].currentChords.length, 2)
    compare(found[0].currentChords[0], "Super + Shift + B")
    compare(found[0].currentChords[1], "Super + Shift + RETURN")
    compare(found[0].currentShortcuts.length, 2)
    compare(found[0].currentShortcuts[0].badgeKind, "desktopApp")
    compare(found[0].currentShortcuts[1].badgeKind, "desktopApp")
  }

  function test_each_merged_shortcut_keeps_its_own_display_kind() {
    const actions = [
      {
        id: "shared-desktop", title: "Shared", labelKey: "",
        actionKind: "exec", displayKind: "desktopApp", roleKind: "",
        targetId: "shared:target", modifiers: ["SUPER"], key: "D"
      },
      {
        id: "shared-web", title: "Shared", labelKey: "",
        actionKind: "exec", displayKind: "webapp", roleKind: "",
        targetId: "shared:target", modifiers: ["SUPER"], key: "W"
      }
    ]

    const found = ActionSearchModel.results("shared", "en", actions, [], 30)

    compare(found.length, 1)
    compare(found[0].currentShortcuts.length, 2)
    compare(found[0].currentShortcuts[0].chord, "Super + D")
    compare(found[0].currentShortcuts[0].badgeKind, "desktopApp")
    compare(found[0].currentShortcuts[1].chord, "Super + W")
    compare(found[0].currentShortcuts[1].badgeKind, "webapp")
  }

  function test_raw_path_commands_never_enter_the_user_picker() {
    const commands = [
      catalogItem("command", "command:codex", "codex", "codex"),
      catalogItem("command", "command:usage", "omarchy-agent-usage-codex",
                  "omarchy-agent-usage-codex"),
      catalogItem("command", "command:driver", "chromedriver", "chromedriver")
    ]

    compare(ActionSearchModel.results("codex", "en", [], commands, 30).length, 0)
    compare(ActionSearchModel.results("chrom", "en", [], commands, 30).length, 0)
  }

  function test_codex_role_is_one_row_even_when_path_contains_codex_helpers() {
    const agent = {
      id: "agent-codex", title: "Agent", labelKey: "action.agent",
      actionKind: "exec", displayKind: "cmd", roleKind: "agent",
      targetName: "Codex", targetId: "agent:codex",
      modifiers: ["SUPER", "CTRL", "SHIFT"], key: "A"
    }
    const commands = [
      catalogItem("command", "command:codex", "codex", "codex"),
      catalogItem("command", "command:usage", "omarchy-agent-usage-codex",
                  "omarchy-agent-usage-codex")
    ]

    const found = ActionSearchModel.results("codex", "en", [agent], commands, 30)

    compare(found.length, 1)
    compare(found[0].title, "Codex")
    compare(found[0].currentChord, "Super + Ctrl + Shift + A")
  }

  function test_private_browser_action_stays_separate_from_plain_browser() {
    const chromium = catalogItem(
      "application", "application:chromium.desktop",
      "Chromium", "Chromium", "Web browser")
    const privateBrowser = {
      id: "action-private-browser", title: "Browser (private)",
      labelKey: "action.privateBrowser", actionKind: "exec",
      displayKind: "desktopApp", roleKind: "browser", targetName: "",
      targetId: "action:action-private-browser",
      browserName: "Chromium", modifiers: ["SUPER", "SHIFT", "ALT"], key: "B"
    }

    const found = ActionSearchModel.results(
      "browser", "en", [privateBrowser], [chromium], 30)

    compare(found.length, 2)
    const privateResult = found.filter(function(item) {
      return item.targetId === "action:action-private-browser"
    })[0]
    compare(privateResult.title, "Private Browser")

    const byProvider = ActionSearchModel.results(
      "chromium", "en", [privateBrowser], [chromium], 30)
    compare(byProvider.length, 1)
    compare(byProvider[0].targetId, "application:chromium.desktop")
  }

  function test_editor_role_uses_neovim_cmd_classification() {
    const editor = {
      id: "action-editor", title: "Editor", labelKey: "action.editor",
      actionKind: "exec", displayKind: "cmd", roleKind: "editor",
      targetName: "Neovim", targetId: "application:nvim.desktop",
      modifiers: ["SUPER", "SHIFT"], key: "N"
    }

    const found = ActionSearchModel.results("neovim", "ko", [editor], [], 30)

    compare(found.length, 1)
    compare(found[0].title, "Neovim")
    compare(found[0].badgeKind, "cmd")
    compare(found[0].roleBadgeKind, "editor")
  }

  function test_exec_window_operation_is_an_action_not_cmd() {
    const action = {
      id: "action-gaps", title: "Toggle window gaps",
      labelKey: "action.toggleWindowGaps", actionKind: "exec",
      displayKind: "action", roleKind: "",
      modifiers: ["SUPER"], key: "G"
    }

    const found = ActionSearchModel.results("window gaps", "en", [action], [], 30)

    compare(found.length, 1)
    compare(found[0].badgeKind, "action")
  }

  function test_catalog_command_is_not_a_user_visible_target() {
    const command = catalogItem(
      "command", "command:demo", "demo", "demo", "", "/usr/bin/demo")

    const found = ActionSearchModel.results("demo", "ko", [], [command], 30)

    compare(found.length, 0)
  }

  function test_original_omarchy_english_and_localized_title_both_remain_searchable() {
    const actions = [{
      id: "action-reveal", title: "Reveal active window on top",
      labelKey: "action.revealActiveWindow", actionKind: "lua",
      modifiers: ["SUPER"], key: "R"
    }]

    const originalEnglish = ActionSearchModel.results(
      "reveal active", "ko", actions, [], 0)
    const localized = ActionSearchModel.results(
      "맨 앞으로", "ko", actions, [], 0)

    compare(originalEnglish.length, 1)
    compare(originalEnglish[0].id, "action-reveal")
    compare(localized.length, 1)
    compare(localized[0].id, "action-reveal")
  }

  function test_exact_prefix_word_prefix_and_substring_scores_are_stable() {
    const items = [
      catalogItem("application", "application:exact.desktop", "demo", "demo"),
      catalogItem("application", "application:prefix.desktop", "demonstration", "demonstration"),
      catalogItem("application", "application:word.desktop", "My demo tool", "My demo tool"),
      catalogItem("application", "application:substring.desktop", "pandemographic", "pandemographic")
    ]
    const found = ActionSearchModel.results("demo", "en", [], items, 30)

    compare(found.map(function(item) { return item.id }).join(","),
            "application:exact.desktop,application:prefix.desktop,application:word.desktop,application:substring.desktop")
    compare(found.map(function(item) { return item.score }).join(","),
            "400,300,200,100")
  }

  function test_registered_target_precedes_unregistered_equal_matches() {
    const actions = [{
      id: "action-demo", title: "Demo", labelKey: "action.demo",
      actionKind: "exec", modifiers: ["SUPER"], key: "D"
    }]
    const items = [
      catalogItem("command", "command:demo", "Demo", "Demo", "", "/usr/bin/demo"),
      catalogItem("application", "application:demo.desktop", "Demo", "Demo")
    ]
    const found = ActionSearchModel.results("demo", "en", actions, items, 30)

    compare(found[0].kind, "action")
    verify(found[0].currentChord !== "")
  }

  function test_relevance_is_global_instead_of_grouped_by_kind() {
    const actions = [{
      id: "action-demo", title: "Demo", labelKey: "action.demo",
      actionKind: "exec", modifiers: ["SUPER"], key: "D"
    }]
    const items = [
      catalogItem("application", "application:substring.desktop",
                  "My demography tool", "My demography tool"),
      catalogItem("command", "command:demo", "Demo", "Demo", "",
                  "/usr/bin/demo")
    ]
    const found = ActionSearchModel.results("demo", "en", actions, items, 30)

    compare(found.map(function(item) { return item.kind }).join(","),
            "action,application")
    compare(found.map(function(item) { return item.score }).join(","),
            "400,200")
  }

  function test_diacritics_case_and_whitespace_are_folded() {
    const items = [
      catalogItem("application", "application:cafe.desktop", "Café   Música", "Cafe Music")
    ]
    compare(ActionSearchModel.results(
      "  CAFE musica ", "es", [], items, 30)[0].id,
      "application:cafe.desktop")
  }

  function test_application_search_uses_names_summary_and_keywords() {
    const item = catalogItem(
      "application", "application:paint.desktop", "그림판", "Paint",
      "사진과 그림 편집", "", ["drawing", "editor"])

    compare(ActionSearchModel.results("그림판", "ko", [], [item], 30)[0].id,
            item.id)
    compare(ActionSearchModel.results("paint", "ko", [], [item], 30)[0].id,
            item.id)
    compare(ActionSearchModel.results("drawing", "ko", [], [item], 30)[0].id,
            item.id)
    compare(ActionSearchModel.results("사진", "ko", [], [item], 30)[0].id,
            item.id)
  }

  function test_command_search_never_exposes_path_entries() {
    const command = catalogItem(
      "command", "command:demo", "demo", "demo", "", "/opt/private-tools/demo")

    compare(ActionSearchModel.results("demo", "en", [], [command], 30).length, 0)
    compare(ActionSearchModel.results("private", "en", [], [command], 30).length, 0)
  }

  function test_result_contract_contains_localized_title_and_current_chord() {
    const result = ActionSearchModel.results(
      "terminal", "ko", [terminalAction], [], 30)[0]

    compare(result.kind, "action")
    compare(result.title, "터미널")
    compare(result.englishTitle, "Terminal")
    compare(result.labelKey, "action.terminal")
    compare(result.currentChord, "Super + RETURN")
    compare(result.badgeKind, "cmd")
    verify(result.icon !== "")
    compare(result.path, "")
    verify(Array.isArray(result.keywords))
  }

  function test_managed_application_merges_by_selection_target_identity() {
    const application = catalogItem(
      "application", "application:org.demo.App.desktop",
      "Demo App", "Demo App", "Friendly app")
    const actions = [{
      id: "managed-demo-app", title: "Demo App", labelKey: "",
      actionKind: "exec", modifiers: ["SUPER"], key: "D",
      selectionKind: "application",
      selectionId: "application:org.demo.App.desktop"
    }]

    const found = ActionSearchModel.results(
      "demo", "en", actions, [application], 30)

    compare(found.length, 1)
    compare(found[0].kind, "application")
    compare(found[0].id, application.id)
    compare(found[0].currentChord, "Super + D")
    compare(found[0].badgeKind, "desktopApp")
  }

  function test_equal_titles_with_different_target_ids_stay_separate() {
    const application = catalogItem(
      "application", "application:chatgpt.desktop",
      "ChatGPT", "ChatGPT", "AI assistant")
    const existingAction = {
      id: "source-chatgpt", title: "ChatGPT", labelKey: "",
      actionKind: "exec", modifiers: ["SUPER", "SHIFT"], key: "A",
      selectionKind: "action", selectionId: "action-source-chatgpt",
      launchKind: "webapp", targetId: "webapp:https://chatgpt.com/"
    }

    const found = ActionSearchModel.results(
      "chatgpt", "ko", [existingAction], [application], 30)

    compare(found.length, 2)
    const appResult = found.filter(function(item) {
      return item.kind === "application"
    })[0]
    const actionResult = found.filter(function(item) {
      return item.kind === "action"
    })[0]
    compare(appResult.id, application.id)
    compare(appResult.currentChord, "")
    compare(appResult.badgeKind, "desktopApp")
    compare(actionResult.id, existingAction.id)
    compare(actionResult.currentChord, "Super + Shift + A")
    compare(actionResult.badgeKind, "webapp")
  }

  function test_same_webapp_target_merges_icon_and_registered_key() {
    const youtube = catalogItem(
      "application", "application:YouTube.desktop",
      "YouTube", "YouTube", "", "", [])
    youtube.targetId = "webapp:https://youtube.com/"
    youtube.launchKind = "webapp"
    youtube.icon = "youtube"
    const action = {
      id: "source-youtube", title: "YouTube", labelKey: "",
      actionKind: "exec", launchKind: "webapp",
      targetId: "webapp:https://youtube.com/",
      modifiers: ["SUPER", "SHIFT"], key: "Y",
      selectionKind: "action", selectionId: "source-youtube"
    }

    const found = ActionSearchModel.results(
      "youtube", "ko", [action], [youtube], 30)

    compare(found.length, 1)
    compare(found[0].id, youtube.id)
    compare(found[0].badgeKind, "webapp")
    compare(found[0].icon, "youtube")
    compare(found[0].currentChord, "Super + Shift + Y")
  }

  function test_ambiguous_application_titles_do_not_claim_an_existing_key() {
    const applications = [
      catalogItem("application", "application:one.desktop", "Demo", "Demo"),
      catalogItem("application", "application:two.desktop", "Demo", "Demo")
    ]
    const existingAction = {
      id: "source-demo", title: "Demo", labelKey: "",
      actionKind: "exec", modifiers: ["SUPER"], key: "D",
      selectionKind: "action", selectionId: "action-source-demo"
    }

    const found = ActionSearchModel.results(
      "demo", "en", [existingAction], applications, 30)

    compare(found.length, 3)
    compare(found.filter(function(item) {
      return item.kind === "application" && item.currentChord !== ""
    }).length, 0)
    compare(found.filter(function(item) {
      return item.kind === "action" && item.currentChord === "Super + D"
    }).length, 1)
  }

  function test_managed_commands_merge_registered_keys_into_one_target() {
    const command = catalogItem(
      "command", "command:demo", "demo", "demo", "", "/usr/bin/demo")
    const actions = [
      {
        id: "managed-demo-one", title: "demo", labelKey: "",
        actionKind: "exec", displayKind: "action",
        modifiers: ["SUPER"], key: "D",
        selectionKind: "command", selectionId: "command:demo"
      },
      {
        id: "managed-demo-two", title: "demo", labelKey: "",
        actionKind: "exec", displayKind: "action",
        modifiers: ["SUPER", "SHIFT"], key: "D",
        selectionKind: "command", selectionId: "command:demo"
      }
    ]

    const found = ActionSearchModel.results("demo", "en", actions, [command], 30)

    compare(found.length, 1)
    compare(found[0].kind, "action")
    compare(found[0].currentChord, "Super + D · Super + Shift + D")
    compare(found[0].badgeKind, "action")
  }

  function test_explicit_result_limit_is_honored_without_a_hidden_hard_cap() {
    const items = []
    for (let index = 0; index < 80; index += 1) {
      items.push(catalogItem(
        "application", "application:tool-" + index + ".desktop", "tool-" + index,
        "tool-" + index))
    }

    compare(ActionSearchModel.results("tool", "en", [], items, 100).length, 80)
    compare(ActionSearchModel.results("tool", "en", [], items, 7).length, 7)
  }

  function test_blank_query_merges_registered_target_by_identity() {
    const application = catalogItem(
      "application", "application:chatgpt.desktop",
      "ChatGPT", "ChatGPT", "")
    const actions = [{
      id: "managed-chatgpt", title: "ChatGPT", labelKey: "",
      actionKind: "exec", modifiers: ["SUPER"], key: "A",
      selectionKind: "application",
      selectionId: "application:chatgpt.desktop"
    }]

    const found = ActionSearchModel.results("", "ko", actions, [application], 0)

    compare(found.length, 1)
    compare(found[0].kind, "application")
    compare(found[0].currentChord, "Super + A")
  }

  function test_blank_query_sorts_registered_first_then_natural_numbers() {
    const items = [
      catalogItem("application", "application:tool-10.desktop", "도구 10", "Tool 10"),
      catalogItem("application", "application:tool-2.desktop", "도구 2", "Tool 2"),
      catalogItem("application", "application:tool-02.desktop", "도구 02", "Tool 02"),
      catalogItem("application", "application:tool-1.desktop", "도구 1", "Tool 1")
    ]
    const actions = [{
      id: "registered-tool-20", title: "도구 20", labelKey: "",
      actionKind: "exec", displayKind: "action", roleKind: "",
      targetId: "action:registered-tool-20",
      modifiers: ["SUPER"], key: "T",
      selectionKind: "action", selectionId: "registered-tool-20"
    }]

    const found = ActionSearchModel.results("", "ko", actions, items, 0)

    compare(found.map(function(item) { return item.title }).join(","),
            "도구 20,도구 1,도구 2,도구 02,도구 10")
  }

  function test_blank_query_uses_the_current_display_language_titles() {
    const actions = [
      {
        id: "audio", title: "Audio", labelKey: "action.audio",
        actionKind: "exec", displayKind: "systemUi", roleKind: "",
        modifiers: ["SUPER"], key: "A"
      },
      {
        id: "browser", title: "Browser", labelKey: "action.browser",
        actionKind: "exec", displayKind: "desktopApp", roleKind: "",
        modifiers: ["SUPER"], key: "B"
      }
    ]

    compare(ActionSearchModel.results("", "en", actions, [], 0)
      .map(function(item) { return item.title }).join(","), "Audio,Browser")
    compare(ActionSearchModel.results("", "ko", actions, [], 0)
      .map(function(item) { return item.title }).join(","), "브라우저,오디오")
    compare(ActionSearchModel.results("", "ja", actions, [], 0)
      .map(function(item) { return item.title }).join(","), "オーディオ,ブラウザ")
    compare(ActionSearchModel.results("", "zh_CN", actions, [], 0)
      .map(function(item) { return item.title }).join(","), "浏览器,音频")
    compare(ActionSearchModel.results("", "es", actions, [], 0)
      .map(function(item) { return item.title }).join(","), "Audio,Navegador")
  }

  function test_search_relevance_precedes_registration_then_natural_title() {
    const actions = [{
      id: "registered-prefix", title: "Toolkit 10", labelKey: "",
      actionKind: "exec", displayKind: "action", roleKind: "",
      modifiers: ["SUPER"], key: "T"
    }]
    const items = [
      catalogItem("application", "application:tool.desktop", "Tool", "Tool"),
      catalogItem("application", "application:toolkit-2.desktop", "Toolkit 2", "Toolkit 2")
    ]

    const found = ActionSearchModel.results("tool", "en", actions, items, 30)

    compare(found.map(function(item) { return item.title }).join(","),
            "Tool,Toolkit 10,Toolkit 2")
    compare(found.map(function(item) { return item.score }).join(","),
            "400,300,300")
  }

  function test_equal_titles_use_stable_identity_order() {
    const items = [
      catalogItem("application", "application:z.desktop", "Demo", "Demo"),
      catalogItem("application", "application:a.desktop", "Demo", "Demo")
    ]
    compare(ActionSearchModel.results("demo", "en", [], items, 30)
      .map(function(item) { return item.id }).join(","),
      "application:a.desktop,application:z.desktop")
  }
}
