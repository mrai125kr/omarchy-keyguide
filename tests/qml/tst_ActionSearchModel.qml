import QtQuick
import QtTest
import "../../src/plugin/ActionSearchModel.js" as ActionSearchModel

TestCase {
  name: "ActionSearchModel"

  readonly property var terminalAction: ({
    id: "action-terminal",
    title: "Terminal",
    labelKey: "action.terminal",
    actionKind: "exec",
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
      keywords: keywords || []
    }
  }

  function test_blank_query_shows_the_complete_sorted_catalog() {
    const items = []
    for (let index = 0; index < 45; index += 1) {
      items.push(catalogItem(
        "command", "command:tool-" + index, "tool-" + index,
        "tool-" + index, "", "/usr/bin/tool-" + index))
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

  function test_kind_priority_breaks_equal_scores() {
    const actions = [{
      id: "action-demo", title: "Demo", labelKey: "action.demo",
      actionKind: "exec", modifiers: ["SUPER"], key: "D"
    }]
    const items = [
      catalogItem("command", "command:demo", "Demo", "Demo", "", "/usr/bin/demo"),
      catalogItem("application", "application:demo.desktop", "Demo", "Demo")
    ]
    const found = ActionSearchModel.results("demo", "en", actions, items, 30)

    compare(found.map(function(item) { return item.kind }).join(","),
            "application,action,command")
  }

  function test_results_stay_grouped_by_kind_before_relevance_within_group() {
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
            "application,action,command")
    compare(found.map(function(item) { return item.score }).join(","),
            "200,400,400")
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

  function test_command_search_does_not_match_arbitrary_parent_directories() {
    const command = catalogItem(
      "command", "command:demo", "demo", "demo", "", "/opt/private-tools/demo")

    compare(ActionSearchModel.results("demo", "en", [], [command], 30).length, 1)
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
    compare(result.path, "")
    verify(Array.isArray(result.keywords))
  }

  function test_managed_application_shortcuts_merge_into_the_catalog_result() {
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
  }

  function test_same_title_webapp_does_not_merge_into_an_application() {
    const application = catalogItem(
      "application", "application:chatgpt.desktop",
      "ChatGPT", "ChatGPT", "AI assistant")
    const existingAction = {
      id: "source-chatgpt", title: "ChatGPT", labelKey: "",
      actionKind: "exec", modifiers: ["SUPER", "SHIFT"], key: "A",
      selectionKind: "action", selectionId: "action-source-chatgpt",
      launchKind: "webapp"
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
    compare(actionResult.id, existingAction.id)
    compare(actionResult.currentChord, "Super + Shift + A")
    compare(actionResult.badgeKind, "webapp")
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

  function test_managed_command_shortcuts_merge_and_keep_all_registered_keys() {
    const command = catalogItem(
      "command", "command:demo", "demo", "demo", "", "/usr/bin/demo")
    const actions = [
      {
        id: "managed-demo-one", title: "demo", labelKey: "",
        actionKind: "exec", modifiers: ["SUPER"], key: "D",
        selectionKind: "command", selectionId: "command:demo"
      },
      {
        id: "managed-demo-two", title: "demo", labelKey: "",
        actionKind: "exec", modifiers: ["SUPER", "SHIFT"], key: "D",
        selectionKind: "command", selectionId: "command:demo"
      }
    ]

    const found = ActionSearchModel.results("demo", "en", actions, [command], 30)

    compare(found.length, 1)
    compare(found[0].kind, "command")
    compare(found[0].currentChord, "Super + D · Super + Shift + D")
  }

  function test_explicit_result_limit_is_honored_without_a_hidden_hard_cap() {
    const items = []
    for (let index = 0; index < 80; index += 1) {
      items.push(catalogItem(
        "command", "command:tool-" + index, "tool-" + index,
        "tool-" + index, "", "/usr/bin/tool-" + index))
    }

    compare(ActionSearchModel.results("tool", "en", [], items, 100).length, 80)
    compare(ActionSearchModel.results("tool", "en", [], items, 7).length, 7)
  }

  function test_blank_query_merges_an_actual_application_shortcut_key() {
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
    compare(found[0].id, application.id)
    compare(found[0].currentChord, "Super + A")
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
