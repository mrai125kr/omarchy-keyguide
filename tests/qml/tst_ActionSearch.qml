import QtQuick
import QtTest
import "../../src/plugin/components" as Components

TestCase {
  id: testRoot
  name: "ActionSearch"
  when: windowShown

  width: 720
  height: 640
  visible: true

  readonly property var actions: [{
    id: "action-terminal", title: "Terminal", labelKey: "action.terminal",
    actionKind: "exec", modifiers: ["SUPER"], key: "RETURN"
  }]
  readonly property var catalog: [
    {
      kind: "application", id: "application:org.demo.App.desktop",
      title: "Demo App", englishTitle: "Demo App", summary: "Friendly app",
      icon: "application-x-executable", path: "", keywords: ["demo"]
    },
    {
      kind: "command", id: "command:demo", title: "demo",
      englishTitle: "demo", summary: "", icon: "",
      path: "/usr/bin/demo", keywords: ["demo"]
    }
  ]

  Component {
    id: searchComponent

    Components.ActionSearch {
      width: 680
      height: 600
      language: "en"
      keyboardFocusOwned: true
    }
  }

  Component {
    id: spyComponent
    SignalSpy {}
  }

  function findNamed(object, name, depth) {
    if (!object || depth > 24)
      return null
    if (String(object.objectName || "") === name)
      return object
    const children = object.children || []
    for (let index = 0; index < children.length; index += 1) {
      const found = findNamed(children[index], name, depth + 1)
      if (found)
        return found
    }
    if (object.contentItem && object.contentItem !== object)
      return findNamed(object.contentItem, name, depth + 1)
    return null
  }

  function createSearch(properties) {
    const search = createTemporaryObject(searchComponent, testRoot, {
      actions: testRoot.actions,
      catalogItems: testRoot.catalog,
      iconResolver: function(iconName) {
        return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='2' height='2'/%3E"
      }
    })
    verify(search !== null)
    const overrides = properties || {}
    Object.keys(overrides).forEach(function(name) {
      search[name] = overrides[name]
    })
    search.openSearch()
    wait(0)
    return search
  }

  function test_blank_query_shows_results_without_explanatory_lines() {
    const search = createSearch({ language: "ko" })
    compare(search.resultCount, 2)
    const list = findNamed(search, "shortcutActionSearchResults", 0)
    verify(list !== null)
    verify(list.visible)
    compare(findNamed(search, "shortcutActionSearchGuidance", 0), null)
    compare(findNamed(search, "shortcutActionSearchLoading", 0), null)
    compare(findNamed(search, "shortcutActionSearchWarning", 0), null)
  }

  function test_raw_command_is_not_rendered_beside_the_application() {
    const search = createSearch({ query: "demo" })
    tryCompare(search, "resultCount", 1)
    const icon = findNamed(search, "shortcutActionSearchApplicationIcon", 0)
    const badge = findNamed(search, "shortcutActionSearchRawCommandBadge", 0)
    verify(icon !== null)
    compare(badge, null)
    verify(icon.visible)
    verify(String(icon.source || "") !== "")
  }

  function test_missing_theme_icon_renders_a_visible_glyph_fallback() {
    const search = createSearch({
      query: "terminal",
      catalogItems: [],
      iconResolver: function(iconName) {
        return "file:///definitely-missing-keyguide-icon.svg"
      }
    })
    tryCompare(search, "resultCount", 1)
    const icon = findNamed(search, "shortcutActionSearchResultIcon", 0)
    const fallback = findNamed(search, "shortcutActionSearchIconFallback", 0)
    verify(icon !== null)
    tryCompare(icon, "status", Image.Error)
    verify(fallback !== null && fallback.visible)
    verify(String(fallback.text || "") !== "")
  }

  function test_picker_uses_one_list_without_type_sections() {
    const search = createSearch({
      language: "ko",
      query: "demo",
      actions: [{
        id: "action-demo", title: "Demo", labelKey: "action.demo",
        actionKind: "exec", modifiers: ["SUPER"], key: "D"
      }]
    })
    tryCompare(search, "resultCount", 2)

    const panel = findNamed(search, "shortcutActionSearchPanel", 0)
    const fieldSurface = findNamed(
      search, "shortcutActionSearchFieldSurface", 0)
    verify(panel !== null)
    verify(fieldSurface !== null)
    verify(panel.radius >= 12)
    verify(fieldSurface.radius >= fieldSurface.height / 3)

    compare(findNamed(search, "shortcutActionSearchCategory-application", 0), null)
    compare(findNamed(search, "shortcutActionSearchCategory-action", 0), null)
    compare(findNamed(search, "shortcutActionSearchCategory-command", 0), null)

    const shortcutChip = findNamed(
      search, "shortcutActionSearchShortcutChip", 0)
    verify(shortcutChip !== null)
    verify(shortcutChip.visible)
    compare(shortcutChip.text, "Super + D")
  }

  function test_empty_and_error_states_are_named_and_localized() {
    const search = createSearch({
      language: "es", query: "missing", busy: true,
      warningCount: 7
    })
    const empty = findNamed(search, "shortcutActionSearchEmpty", 0)
    const error = findNamed(search, "shortcutActionSearchError", 0)
    compare(findNamed(search, "shortcutActionSearchLoading", 0), null)
    compare(findNamed(search, "shortcutActionSearchWarning", 0), null)
    verify(empty !== null && !empty.visible)

    search.busy = false
    wait(0)
    verify(empty.visible)
    compare(empty.text, "No hay coincidencias. Revisa la escritura o prueba el nombre en inglés.")

    search.errorText = "Could not load"
    wait(0)
    verify(error !== null && error.visible)
    compare(error.text, "Could not load")
    verify(!empty.visible)
  }

  function test_registered_application_is_one_icon_target_with_a_key_chip() {
    const search = createSearch({
      catalogItems: [testRoot.catalog[0]],
      actions: [{
        id: "managed-demo-app", title: "Demo App", labelKey: "",
        actionKind: "exec", modifiers: ["SUPER"], key: "D",
        selectionKind: "application",
        selectionId: "application:org.demo.App.desktop"
      }]
    })
    tryCompare(search, "resultCount", 1)
    const row = findNamed(search, "shortcutActionSearchResult", 0)
    const chip = findNamed(search, "shortcutActionSearchShortcutChip", 0)
    verify(row !== null && chip !== null && chip.visible)
    compare(chip.text, "Super + D")
    verify(chip.mapToItem(row, 0, 0).x > row.width / 2)
  }

  function test_typing_filters_the_initial_list_to_matching_items_only() {
    const search = createSearch({})
    compare(search.resultCount, 2)

    search.query = "terminal"
    tryCompare(search, "resultCount", 1)
    compare(search.results[0].id, "action-terminal")
  }

  function test_existing_direct_command_is_shown_as_a_registered_action() {
    const search = createSearch({
      query: "demo",
      catalogItems: [testRoot.catalog[1]],
      actions: [{
        id: "managed-demo-command", title: "demo", labelKey: "",
        actionKind: "exec", displayKind: "action",
        modifiers: ["SUPER", "ALT"], key: "D",
        selectionKind: "command", selectionId: "command:demo"
      }]
    })
    tryCompare(search, "resultCount", 1)
    const row = findNamed(search, "shortcutActionSearchResult", 0)
    const commandBadge = findNamed(
      search, "shortcutActionSearchActionBadge", 0)
    const title = findNamed(search, "shortcutActionSearchTitle", 0)
    const chip = findNamed(search, "shortcutActionSearchShortcutChip", 0)
    verify(row !== null && title !== null && commandBadge !== null && chip !== null)
    compare(commandBadge.text, "ACTION")
    compare(chip.text, "Super + Alt + D")
    const titleX = title.mapToItem(row, 0, 0).x
    const badgeX = commandBadge.mapToItem(row, 0, 0).x
    const chipX = chip.mapToItem(row, 0, 0).x
    verify(badgeX >= titleX + Math.min(title.paintedWidth, title.width))
    verify(badgeX - (titleX + Math.min(title.paintedWidth, title.width)) <= 20)
    verify(chipX > row.width / 2)
  }

  function test_webapp_action_shows_a_localized_webapp_badge() {
    const search = createSearch({
      language: "ko",
      query: "chatgpt",
      catalogItems: [],
      actions: [{
        id: "source-chatgpt", title: "ChatGPT", labelKey: "",
        actionKind: "exec", launchKind: "webapp",
        modifiers: ["SUPER", "SHIFT"], key: "A",
        selectionKind: "action", selectionId: "action-source-chatgpt"
      }]
    })
    tryCompare(search, "resultCount", 1)
    const badge = findNamed(search, "shortcutActionSearchWebAppBadge", 0)
    const icon = findNamed(search, "shortcutActionSearchResultIcon", 0)
    verify(badge !== null)
    verify(icon !== null && icon.visible)
    verify(String(icon.source || "") !== "")
    verify(badge.visible)
    compare(badge.text, "웹앱")
  }

  function test_agent_shows_command_and_registered_role_badges() {
    const search = createSearch({
      language: "ko",
      query: "codex",
      catalogItems: [],
      actions: [{
        id: "source-agent", title: "Agent", labelKey: "action.agent",
        actionKind: "exec", agentName: "Codex",
        modifiers: ["SUPER", "CTRL", "SHIFT"], key: "A",
        selectionKind: "action", selectionId: "action-source-agent"
      }]
    })
    tryCompare(search, "resultCount", 1)
    compare(search.results[0].title, "Codex")
    const commandBadge = findNamed(
      search, "shortcutActionSearchCommandBadge", 0)
    const agentBadge = findNamed(
      search, "shortcutActionSearchAgentBadge", 0)
    verify(commandBadge !== null && commandBadge.visible)
    verify(agentBadge !== null && agentBadge.visible)
    compare(commandBadge.text, "CMD")
    compare(agentBadge.text, "에이전트")
  }

  function test_browser_shows_desktop_app_and_registered_role_badges() {
    const search = createSearch({
      language: "ko",
      query: "chromium",
      catalogItems: [],
      actions: [{
        id: "source-browser", title: "Browser", labelKey: "action.browser",
        actionKind: "exec", browserName: "Chromium",
        modifiers: ["SUPER"], key: "B",
        selectionKind: "action", selectionId: "action-source-browser"
      }]
    })
    tryCompare(search, "resultCount", 1)
    compare(search.results[0].title, "Chromium")
    const desktopBadge = findNamed(
      search, "shortcutActionSearchDesktopAppBadge", 0)
    const browserBadge = findNamed(
      search, "shortcutActionSearchBrowserBadge", 0)
    verify(desktopBadge !== null && desktopBadge.visible)
    verify(browserBadge !== null && browserBadge.visible)
    compare(desktopBadge.text, "데스크톱 앱")
    compare(browserBadge.text, "브라우저")
  }

  function test_neovim_editor_shows_cmd_and_editor_badges() {
    const search = createSearch({
      language: "ko",
      query: "neovim",
      catalogItems: [],
      actions: [{
        id: "source-editor", title: "Editor", labelKey: "action.editor",
        actionKind: "exec", displayKind: "cmd", roleKind: "editor",
        targetName: "Neovim", targetId: "application:nvim.desktop",
        modifiers: ["SUPER", "SHIFT"], key: "N",
        selectionKind: "action", selectionId: "action-source-editor"
      }]
    })
    tryCompare(search, "resultCount", 1)
    compare(search.results[0].title, "Neovim")
    const cmdBadge = findNamed(search, "shortcutActionSearchCommandBadge", 0)
    const editorBadge = findNamed(search, "shortcutActionSearchEditorBadge", 0)
    verify(cmdBadge !== null && cmdBadge.visible)
    verify(editorBadge !== null && editorBadge.visible)
    compare(cmdBadge.text, "CMD")
    compare(editorBadge.text, "에디터")
  }

  function test_exec_window_operation_shows_action_badge() {
    const search = createSearch({
      language: "ko",
      query: "window gaps",
      catalogItems: [],
      actions: [{
        id: "source-gaps", title: "Toggle window gaps",
        labelKey: "action.toggleWindowGaps", actionKind: "exec",
        displayKind: "action", roleKind: "", targetName: "",
        modifiers: ["SUPER"], key: "G",
        selectionKind: "action", selectionId: "action-source-gaps"
      }]
    })
    tryCompare(search, "resultCount", 1)
    const actionBadge = findNamed(search, "shortcutActionSearchActionBadge", 0)
    compare(findNamed(search, "shortcutActionSearchCommandBadge", 0), null)
    verify(actionBadge !== null && actionBadge.visible)
    compare(actionBadge.text, "행동")
  }

  function test_type_badge_and_shortcut_share_a_high_contrast_color() {
    const cases = [
      { kind: "desktopApp", badge: "shortcutActionSearchDesktopAppBadge",
        expected: "#82b1ff" },
      { kind: "webapp", badge: "shortcutActionSearchWebAppBadge",
        expected: "#54e1c1" },
      { kind: "cmd", badge: "shortcutActionSearchCommandBadge",
        expected: "#ffc266" },
      { kind: "action", badge: "shortcutActionSearchActionBadge",
        expected: "#d6a5ff" },
      { kind: "systemUi", badge: "shortcutActionSearchSystemUiBadge",
        expected: "#ff8fb8" }
    ]
    for (let index = 0; index < cases.length; index += 1) {
      const item = cases[index]
      const search = createSearch({
        query: "target", catalogItems: [], actions: [{
          id: "colored-" + item.kind, title: "Target", labelKey: "",
          actionKind: "exec", displayKind: item.kind, roleKind: "",
          targetName: "", modifiers: ["SUPER"], key: "T",
          selectionKind: "action", selectionId: "colored-" + item.kind
        }]
      })
      tryCompare(search, "resultCount", 1)
      const badge = findNamed(search, item.badge, 0)
      const chip = findNamed(search, "shortcutActionSearchShortcutChip", 0)
      verify(badge !== null && chip !== null)
      compare(String(badge.color), item.expected)
      compare(String(chip.color), item.expected)
      search.destroy()
    }
  }

  function test_multiple_shortcuts_render_as_individual_type_colored_chips() {
    const chromium = {
      kind: "application", id: "application:chromium.desktop",
      targetId: "application:chromium.desktop", title: "Chromium",
      englishTitle: "Chromium", summary: "Web browser", icon: "chromium",
      path: "", keywords: ["chrome", "browser"]
    }
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
    const search = createSearch({
      query: "chromium", catalogItems: [chromium], actions: actions
    })
    tryCompare(search, "resultCount", 1)
    const row = findNamed(search, "shortcutActionSearchResult", 0)
    const firstChip = findNamed(
      search, "shortcutActionSearchShortcutChipSurface-0", 0)
    const secondChip = findNamed(
      search, "shortcutActionSearchShortcutChipSurface-1", 0)
    verify(row !== null)
    compare(row.shortcutChipCount, 2)
    verify(firstChip !== null && secondChip !== null)
    compare(String(firstChip.accentColor), "#82b1ff")
    compare(String(secondChip.accentColor), "#82b1ff")
  }

  function test_merged_shortcuts_follow_their_individual_display_kind_colors() {
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
    const search = createSearch({
      query: "shared", catalogItems: [], actions: actions
    })
    tryCompare(search, "resultCount", 1)
    const firstChip = findNamed(
      search, "shortcutActionSearchShortcutChipSurface-0", 0)
    const secondChip = findNamed(
      search, "shortcutActionSearchShortcutChipSurface-1", 0)
    verify(firstChip !== null && secondChip !== null)
    compare(String(firstChip.accentColor), "#82b1ff")
    compare(String(secondChip.accentColor), "#54e1c1")
  }

  function test_type_palette_switches_to_dark_accents_on_a_light_surface() {
    const search = createSearch({ surface: "#f4f4f4" })
    compare(String(search.typeAccent("desktopApp")), "#1557b0")
    compare(String(search.typeAccent("webapp")), "#006b5d")
    compare(String(search.typeAccent("cmd")), "#8a4300")
    compare(String(search.typeAccent("action")), "#6c2b96")
    compare(String(search.typeAccent("systemUi")), "#9b174c")
  }

  function test_system_ui_uses_a_localized_badge_without_parentheses() {
    const search = createSearch({
      language: "ko", query: "bluetooth", catalogItems: [], actions: [{
        id: "bluetooth", title: "Bluetooth", labelKey: "",
        actionKind: "exec", displayKind: "systemUi", roleKind: "",
        targetName: "", modifiers: ["SUPER"], key: "B",
        selectionKind: "action", selectionId: "bluetooth"
      }]
    })
    tryCompare(search, "resultCount", 1)
    const badge = findNamed(search, "shortcutActionSearchSystemUiBadge", 0)
    verify(badge !== null && badge.visible)
    compare(badge.text, "시스템 UI")
  }

  function test_result_order_uses_the_selected_locale_collation() {
    const chinese = createSearch({
      language: "zh_CN", query: "", actions: [], catalogItems: [
        {
          kind: "application", id: "application:ba.desktop",
          targetId: "application:ba.desktop", title: "八号",
          englishTitle: "Number Eight", summary: "", icon: "",
          path: "", keywords: [], launchKind: "desktopApp"
        },
        {
          kind: "application", id: "application:a.desktop",
          targetId: "application:a.desktop", title: "阿尔法",
          englishTitle: "Alpha", summary: "", icon: "",
          path: "", keywords: [], launchKind: "desktopApp"
        }
      ]
    })
    tryCompare(chinese, "resultCount", 2)
    compare(chinese.results.map(function(item) { return item.title }).join(","),
            "阿尔法,八号")
    chinese.destroy()

    const spanish = createSearch({
      language: "es", query: "", actions: [], catalogItems: [
        {
          kind: "application", id: "application:enye.desktop",
          targetId: "application:enye.desktop", title: "Ñandú",
          englishTitle: "Rhea", summary: "", icon: "",
          path: "", keywords: [], launchKind: "desktopApp"
        },
        {
          kind: "application", id: "application:nube.desktop",
          targetId: "application:nube.desktop", title: "Nube",
          englishTitle: "Cloud", summary: "", icon: "",
          path: "", keywords: [], launchKind: "desktopApp"
        }
      ]
    })
    tryCompare(spanish, "resultCount", 2)
    compare(spanish.results.map(function(item) { return item.title }).join(","),
            "Nube,Ñandú")
    spanish.destroy()
  }

  function test_result_order_prioritizes_relevance_then_registration_then_numbers() {
    const action = {
      id: "registered-prefix", title: "Toolkit 10", labelKey: "",
      actionKind: "exec", displayKind: "action", roleKind: "",
      targetId: "action:registered-prefix",
      modifiers: ["SUPER"], key: "T",
      selectionKind: "action", selectionId: "registered-prefix"
    }
    const applications = [
      {
        kind: "application", id: "application:tool.desktop",
        targetId: "application:tool.desktop", title: "Tool",
        englishTitle: "Tool", summary: "", icon: "", path: "",
        keywords: [], launchKind: "desktopApp"
      },
      {
        kind: "application", id: "application:toolkit-2.desktop",
        targetId: "application:toolkit-2.desktop", title: "Toolkit 2",
        englishTitle: "Toolkit 2", summary: "", icon: "", path: "",
        keywords: [], launchKind: "desktopApp"
      }
    ]
    const search = createSearch({
      language: "en", query: "tool", actions: [action],
      catalogItems: applications
    })
    tryCompare(search, "resultCount", 3)
    compare(search.results.map(function(item) { return item.title }).join(","),
            "Tool,Toolkit 10,Toolkit 2")
    search.destroy()

    const blank = createSearch({
      language: "en", query: "", actions: [{
        id: "registered-z", title: "Zed 20", labelKey: "",
        actionKind: "exec", displayKind: "action", roleKind: "",
        modifiers: ["SUPER"], key: "Z"
      }], catalogItems: [
        {
          kind: "application", id: "application:tool-10.desktop",
          targetId: "application:tool-10.desktop", title: "Tool 10",
          englishTitle: "Tool 10", summary: "", icon: "", path: "",
          keywords: [], launchKind: "desktopApp"
        },
        {
          kind: "application", id: "application:tool-2.desktop",
          targetId: "application:tool-2.desktop", title: "Tool 2",
          englishTitle: "Tool 2", summary: "", icon: "", path: "",
          keywords: [], launchKind: "desktopApp"
        }
      ]
    })
    tryCompare(blank, "resultCount", 3)
    compare(blank.results.map(function(item) { return item.title }).join(","),
            "Zed 20,Tool 2,Tool 10")
    blank.destroy()
  }

  function test_application_shows_a_localized_desktop_app_badge() {
    const search = createSearch({
      language: "ko",
      query: "demo",
      catalogItems: [testRoot.catalog[0]],
      actions: []
    })
    tryCompare(search, "resultCount", 1)
    const badge = findNamed(search, "shortcutActionSearchDesktopAppBadge", 0)
    verify(badge !== null)
    verify(badge.visible)
    compare(badge.text, "데스크톱 앱")
  }

  function test_general_action_does_not_repeat_the_key_in_small_text() {
    const search = createSearch({
      query: "demo", catalogItems: [],
      actions: [{
        id: "action-demo", title: "Demo", labelKey: "",
        actionKind: "exec", modifiers: ["SUPER"], key: "D"
      }]
    })
    tryCompare(search, "resultCount", 1)
    const secondary = findNamed(
      search, "shortcutActionSearchSecondaryText", 0)
    const chip = findNamed(search, "shortcutActionSearchShortcutChip", 0)
    compare(secondary, null)
    verify(chip !== null)
    compare(chip.text, "Super + D")
  }

  function test_no_result_row_renders_a_small_description_line() {
    const search = createSearch({ query: "demo" })
    tryCompare(search, "resultCount", 1)
    compare(findNamed(search, "shortcutActionSearchSecondaryText", 0), null)
  }

  function test_same_title_unmanaged_action_stays_separate_from_application() {
    const search = createSearch({
      query: "demo",
      catalogItems: [testRoot.catalog[0]],
      actions: [{
        id: "source-demo-app", title: "Demo App", labelKey: "",
        actionKind: "exec", modifiers: ["SUPER", "SHIFT"], key: "D",
        selectionKind: "action", selectionId: "action-source-demo-app"
      }]
    })
    tryCompare(search, "resultCount", 2)
    const action = search.results.filter(function(item) {
      return item.kind === "action"
    })[0]
    const application = search.results.filter(function(item) {
      return item.kind === "application"
    })[0]
    compare(action.currentChord, "Super + Shift + D")
    compare(application.currentChord, "")
    search.currentIndex = search.results.indexOf(action)
    wait(0)
    const row = findNamed(search, "shortcutActionSearchResult", 0)
    const chip = findNamed(search, "shortcutActionSearchShortcutChip", 0)
    verify(row !== null && chip !== null && chip.visible)
    compare(chip.text, "Super + Shift + D")
    verify(chip.mapToItem(row, 0, 0).x > row.width / 2)
  }

  function test_keyboard_navigation_wraps_selects_and_escape_closes() {
    const search = createSearch({ query: "demo" })
    const selectedSpy = createTemporaryObject(spyComponent, testRoot, {
      target: search, signalName: "selected"
    })
    const watchingSpy = createTemporaryObject(spyComponent, testRoot, {
      target: search, signalName: "watchingChanged"
    })
    verify(selectedSpy !== null)
    verify(watchingSpy !== null)
    const input = findNamed(search, "shortcutActionSearchInput", 0)
    verify(input !== null)
    tryVerify(function() { return input.activeFocus })
    compare(search.currentIndex, 0)

    keyClick(Qt.Key_Up)
    compare(search.currentIndex, 0)
    keyClick(Qt.Key_Down)
    compare(search.currentIndex, 0)
    keyClick(Qt.Key_Return)
    compare(selectedSpy.count, 1)
    compare(selectedSpy.signalArguments[0][0].kind, "application")

    keyClick(Qt.Key_Escape)
    compare(watchingSpy.count, 1)
    compare(watchingSpy.signalArguments[0][0], false)
    verify(!search.searchOpen)
  }

  function test_mouse_equivalent_selection_uses_the_same_result_contract() {
    const search = createSearch({ query: "demo" })
    const selectedSpy = createTemporaryObject(spyComponent, testRoot, {
      target: search, signalName: "selected"
    })
    verify(selectedSpy !== null)
    const firstDelegate = findNamed(search, "shortcutActionSearchResult", 0)
    verify(firstDelegate !== null)
    waitForRendering(search)
    mouseClick(firstDelegate, firstDelegate.width / 2,
               firstDelegate.height / 2, Qt.LeftButton)
    compare(selectedSpy.count, 1)
    compare(selectedSpy.signalArguments[0][0].id,
            "application:org.demo.App.desktop")
  }

  function test_removed_selection_is_cleared_without_losing_query() {
    const search = createSearch({ query: "demo" })
    const removed = findNamed(search, "shortcutActionSearchSelectionRemoved", 0)
    const application = search.results.filter(function(item) {
      return item.kind === "application"
    })[0]
    search.chooseResult(application)
    compare(search.selectedId, "application:org.demo.App.desktop")

    search.catalogItems = [catalog[1]]
    wait(0)
    compare(search.selectedId, "")
    compare(search.query, "demo")
    verify(removed !== null && removed.visible)
    compare(removed.text,
            "That item is no longer installed. Choose another result.")
  }

  function test_input_focus_is_only_requested_when_the_overlay_owns_it() {
    const search = createSearch({ keyboardFocusOwned: false })
    const input = findNamed(search, "shortcutActionSearchInput", 0)
    verify(input !== null)
    verify(!input.activeFocus)
    search.keyboardFocusOwned = true
    search.openSearch()
    tryVerify(function() { return input.activeFocus })
  }
}
