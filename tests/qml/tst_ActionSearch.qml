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
    compare(search.resultCount, 3)
    const list = findNamed(search, "shortcutActionSearchResults", 0)
    verify(list !== null)
    verify(list.visible)
    compare(findNamed(search, "shortcutActionSearchGuidance", 0), null)
    compare(findNamed(search, "shortcutActionSearchLoading", 0), null)
    compare(findNamed(search, "shortcutActionSearchWarning", 0), null)
  }

  function test_application_icon_and_command_badge_are_distinct() {
    const search = createSearch({ query: "demo" })
    tryCompare(search, "resultCount", 2)
    const icon = findNamed(search, "shortcutActionSearchApplicationIcon", 0)
    const badge = findNamed(search, "shortcutActionSearchCommandBadge", 0)
    verify(icon !== null)
    verify(badge !== null)
    verify(icon.visible)
    verify(String(icon.source || "") !== "")
    verify(badge.visible)
    compare(badge.text, "(CMD)")
  }

  function test_picker_groups_results_and_uses_shortcut_chips() {
    const search = createSearch({
      language: "ko",
      query: "demo",
      actions: [{
        id: "action-demo", title: "Demo", labelKey: "action.demo",
        actionKind: "exec", modifiers: ["SUPER"], key: "D"
      }]
    })
    tryCompare(search, "resultCount", 3)

    const panel = findNamed(search, "shortcutActionSearchPanel", 0)
    const fieldSurface = findNamed(
      search, "shortcutActionSearchFieldSurface", 0)
    verify(panel !== null)
    verify(fieldSurface !== null)
    verify(panel.radius >= 12)
    verify(fieldSurface.radius >= fieldSurface.height / 3)

    const applicationCategory = findNamed(
      search, "shortcutActionSearchCategory-application", 0)
    const actionCategory = findNamed(
      search, "shortcutActionSearchCategory-action", 0)
    const commandCategory = findNamed(
      search, "shortcutActionSearchCategory-command", 0)
    verify(applicationCategory !== null)
    verify(actionCategory !== null)
    verify(commandCategory !== null)
    compare(applicationCategory.text, "프로그램")
    compare(actionCategory.text, "일반 액션")
    compare(commandCategory.text, "명령")

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

  function test_registered_application_key_is_shown_in_a_right_hand_chip() {
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
    compare(search.resultCount, 3)

    search.query = "terminal"
    tryCompare(search, "resultCount", 1)
    compare(search.results[0].id, "action-terminal")
  }

  function test_registered_command_shows_cmd_then_the_key_at_the_far_right() {
    const search = createSearch({
      query: "demo",
      catalogItems: [testRoot.catalog[1]],
      actions: [{
        id: "managed-demo-command", title: "demo", labelKey: "",
        actionKind: "exec", modifiers: ["SUPER", "ALT"], key: "D",
        selectionKind: "command", selectionId: "command:demo"
      }]
    })
    tryCompare(search, "resultCount", 1)
    const row = findNamed(search, "shortcutActionSearchResult", 0)
    const commandBadge = findNamed(
      search, "shortcutActionSearchCommandBadge", 0)
    const title = findNamed(search, "shortcutActionSearchTitle", 0)
    const chip = findNamed(search, "shortcutActionSearchShortcutChip", 0)
    verify(row !== null && title !== null && commandBadge !== null && chip !== null)
    compare(commandBadge.text, "(CMD)")
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
    verify(badge !== null)
    verify(badge.visible)
    compare(badge.text, "(웹앱)")
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
    tryCompare(search, "resultCount", 2)
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
    compare(search.currentIndex, 1)
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
    search.chooseResult(search.results[0])
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
