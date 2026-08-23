pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import QtQml.Models
import "../ActionSearchModel.js" as ActionSearchModel
import "../I18n.js" as I18n
import "../VisibilityModel.js" as VisibilityModel

Item {
  id: root

  objectName: "shortcutActionSearch"

  property string language: "en"
  property var actions: []
  property var catalogItems: []
  property bool busy: false
  property string errorText: ""
  property int warningCount: 0
  property string query: ""
  property bool keyboardFocusOwned: false
  property bool searchOpen: false
  property string selectedId: ""
  property bool selectionWasRemoved: false
  property int currentIndex: -1
  property color surface: "#151515"
  property color foreground: "#f2f2f2"
  property color mutedForeground: "#a7a7a7"
  property color accent: "#8fbfff"
  property color errorForeground: "#ff8a8a"
  property string fontFamily: "sans-serif"
  property var iconResolver: null

  readonly property var rawResults: ActionSearchModel.results(
    query, language, actions, catalogItems, 0)
  property var results: []
  readonly property int resultCount: results.length

  signal selected(var result)
  signal watchingChanged(bool watching)

  function localeName(value) {
    const locales = {
      en: "en_US", ko: "ko_KR", ja: "ja_JP",
      zh_CN: "zh_CN", es: "es_ES"
    }
    return locales[String(value || "")] || "en_US"
  }

  function refreshResultOrder() {
    const source = rawResults || []
    localeSortSource.clear()
    for (let index = 0; index < source.length; index += 1) {
      const item = source[index]
      localeSortSource.append({
        sourceIndex: index,
        score: Number(item && item.score || 0),
        registered: Boolean(item && item.registered),
        title: String(item && item.title || ""),
        targetId: String(item && item.targetId || ""),
        resultId: String(item && item.id || "")
      })
    }
    localeSortProxy.invalidateSorter()
    const ordered = []
    for (let row = 0; row < localeSortProxy.rowCount(); row += 1) {
      const proxyIndex = localeSortProxy.index(row, 0)
      const sourceIndex = localeSortProxy.mapToSource(proxyIndex).row
      if (sourceIndex >= 0 && sourceIndex < source.length)
        ordered.push(source[sourceIndex])
    }
    results = ordered
  }

  function sourceContains(id) {
    const target = String(id || "")
    const sources = [actions, catalogItems]
    for (let sourceIndex = 0; sourceIndex < sources.length; sourceIndex += 1) {
      const source = Array.isArray(sources[sourceIndex]) ? sources[sourceIndex] : []
      for (let index = 0; index < source.length; index += 1) {
        if (String(source[index] && source[index].id || "") === target)
          return true
      }
    }
    return false
  }

  function reconcileSelection() {
    if (selectedId && !sourceContains(selectedId)) {
      selectedId = ""
      selectionWasRemoved = true
    }
  }

  function updateCurrentIndex() {
    if (resultCount === 0) {
      currentIndex = -1
      return
    }
    if (currentIndex < 0 || currentIndex >= resultCount)
      currentIndex = 0
  }

  function openSearch() {
    if (!enabled)
      return false
    if (!searchOpen) {
      searchOpen = true
      watchingChanged(true)
    }
    updateCurrentIndex()
    if (keyboardFocusOwned) {
      Qt.callLater(function() {
        if (root.searchOpen && root.keyboardFocusOwned)
          queryInput.forceActiveFocus()
      })
    }
    return true
  }

  function closeSearch() {
    if (!searchOpen)
      return false
    queryInput.focus = false
    searchOpen = false
    watchingChanged(false)
    return true
  }

  function moveSelection(step) {
    if (resultCount === 0) {
      currentIndex = -1
      return
    }
    const direction = Number(step) < 0 ? -1 : 1
    currentIndex = (currentIndex + direction + resultCount) % resultCount
    resultList.positionViewAtIndex(currentIndex, ListView.Contain)
  }

  function chooseResult(result) {
    if (!result || !result.id || !enabled)
      return false
    selectedId = String(result.id)
    selectionWasRemoved = false
    selected(result)
    return true
  }

  function chooseCurrent() {
    if (currentIndex < 0 || currentIndex >= resultCount)
      return false
    return chooseResult(results[currentIndex])
  }

  function applicationIconSource(item) {
    const requested = String(item && item.icon || "")
    const iconName = requested || "application-x-executable"
    if (typeof iconResolver === "function") {
      const resolved = String(iconResolver(iconName) || "")
      if (resolved)
        return resolved
    }
    return "image://icon/" + iconName
  }

  function surfaceIsLight() {
    return surface.r * 0.2126 + surface.g * 0.7152 + surface.b * 0.0722 > 0.55
  }

  function typeAccent(kind) {
    return VisibilityModel.typeAccent(kind, surfaceIsLight(), accent)
  }

  function shortcutList(item) {
    const declared = item && item.currentShortcuts
    const result = []
    if (declared && typeof declared.length === "number") {
      for (let index = 0; index < declared.length; index += 1) {
        const shortcut = declared[index]
        const chord = String(shortcut && shortcut.chord || "").trim()
        if (chord && !result.some(function(candidate) {
          return candidate.chord === chord
        })) result.push({
          chord: chord,
          badgeKind: String(shortcut && shortcut.badgeKind
            || item && item.badgeKind || "action"),
          roleBadgeKind: String(shortcut && shortcut.roleBadgeKind || "")
        })
      }
    }
    if (result.length > 0)
      return result
    const chords = item && item.currentChords
      && typeof item.currentChords.length === "number"
      ? item.currentChords : String(item && item.currentChord || "").split(" · ")
    for (let index = 0; index < chords.length; index += 1) {
      const chord = chords[index]
      const value = String(chord || "").trim()
      if (value && !result.some(function(candidate) {
        return candidate.chord === value
      })) result.push({
        chord: value,
        badgeKind: String(item && item.badgeKind || "action"),
        roleBadgeKind: String(item && item.roleBadgeKind || "")
      })
    }
    return result
  }

  onActionsChanged: Qt.callLater(function() { root.reconcileSelection() })
  onCatalogItemsChanged: Qt.callLater(function() { root.reconcileSelection() })
  onRawResultsChanged: refreshResultOrder()
  onLanguageChanged: Qt.callLater(refreshResultOrder)
  onResultsChanged: updateCurrentIndex()
  onQueryChanged: updateCurrentIndex()
  onEnabledChanged: if (!enabled) closeSearch()
  onKeyboardFocusOwnedChanged: {
    if (keyboardFocusOwned && searchOpen)
      Qt.callLater(function() { queryInput.forceActiveFocus() })
    else
      queryInput.focus = false
  }

  Component.onCompleted: {
    reconcileSelection()
    refreshResultOrder()
    updateCurrentIndex()
  }

  ListModel {
    id: localeSortSource
  }

  SortFilterProxyModel {
    id: localeSortProxy

    model: localeSortSource
    sorters: [
      RoleSorter {
        roleName: "score"
        sortOrder: Qt.DescendingOrder
        priority: 0
      },
      RoleSorter {
        roleName: "registered"
        sortOrder: Qt.DescendingOrder
        priority: 1
      },
      StringSorter {
        roleName: "title"
        locale: Qt.locale(root.localeName(root.language))
        caseSensitivity: Qt.CaseInsensitive
        numericMode: true
        priority: 2
      },
      StringSorter {
        roleName: "targetId"
        locale: Qt.locale("en_US")
        caseSensitivity: Qt.CaseInsensitive
        numericMode: true
        priority: 3
      },
      StringSorter {
        roleName: "resultId"
        locale: Qt.locale("en_US")
        caseSensitivity: Qt.CaseInsensitive
        numericMode: true
        priority: 4
      }
    ]
  }

  Rectangle {
    objectName: "shortcutActionSearchPanel"
    anchors.fill: parent
    radius: 16
    color: Qt.lighter(root.surface, 1.08)
    border.width: 1
    border.color: Qt.rgba(
      root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
  }

  Column {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 8

    Text {
      width: parent.width
      text: I18n.text(root.language, "search.prompt", {})
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: 16
      font.bold: true
      wrapMode: Text.WordWrap
    }

    QQC.TextField {
      id: queryInput

      objectName: "shortcutActionSearchInput"
      width: parent.width
      height: 46
      enabled: root.enabled
      activeFocusOnTab: root.enabled && root.keyboardFocusOwned && root.searchOpen
      placeholderText: I18n.text(root.language, "search.placeholder", {})
      placeholderTextColor: root.mutedForeground
      text: root.query
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: 13
      leftPadding: 43
      rightPadding: 16
      verticalAlignment: TextInput.AlignVCenter
      selectByMouse: true
      onTextEdited: root.query = text
      background: Rectangle {
        objectName: "shortcutActionSearchFieldSurface"
        radius: height / 2
        color: Qt.rgba(
          root.foreground.r, root.foreground.g, root.foreground.b, 0.045)
        border.width: queryInput.activeFocus ? 1.5 : 1
        border.color: queryInput.activeFocus
          ? root.accent
          : Qt.rgba(root.foreground.r, root.foreground.g,
                    root.foreground.b, 0.16)

        Text {
          anchors.left: parent.left
          anchors.leftMargin: 16
          anchors.verticalCenter: parent.verticalCenter
          text: "\u2315"
          color: queryInput.activeFocus ? root.accent : root.mutedForeground
          font.family: root.fontFamily
          font.pixelSize: 22
        }
      }
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Down) {
          root.moveSelection(1)
          event.accepted = true
        } else if (event.key === Qt.Key_Up) {
          root.moveSelection(-1)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.chooseCurrent()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          root.closeSearch()
          event.accepted = true
        }
      }
    }

    Text {
      objectName: "shortcutActionSearchError"
      width: parent.width
      visible: root.errorText !== ""
      text: root.errorText
      color: root.errorForeground
      font.family: root.fontFamily
      font.pixelSize: 12
      wrapMode: Text.WordWrap
    }

    Text {
      objectName: "shortcutActionSearchSelectionRemoved"
      width: parent.width
      visible: root.selectionWasRemoved
      text: I18n.text(root.language, "search.selectionRemoved", {})
      color: root.errorForeground
      font.family: root.fontFamily
      font.pixelSize: 12
      wrapMode: Text.WordWrap
    }

    Text {
      objectName: "shortcutActionSearchEmpty"
      width: parent.width
      visible: root.query.trim() !== "" && root.resultCount === 0
        && !root.busy && !root.errorText
      text: I18n.text(root.language, "search.noResults", {})
      color: root.mutedForeground
      font.family: root.fontFamily
      font.pixelSize: 13
      wrapMode: Text.WordWrap
    }

    ListView {
      id: resultList

      objectName: "shortcutActionSearchResults"
      width: parent.width
      height: Math.max(0, parent.height - y)
      visible: root.resultCount > 0
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      currentIndex: root.currentIndex
      model: root.results

      delegate: Rectangle {
        id: resultRow

        required property int index
        required property var modelData
        property var resultData: modelData
        readonly property color typeAccentColor: root.typeAccent(
          resultData.badgeKind)
        readonly property var shortcutEntries: root.shortcutList(resultData)
        readonly property int shortcutChipCount: shortcutRepeater.count

        objectName: "shortcutActionSearchResult"
        width: resultList.width
        height: 52
        radius: 10
        color: resultRow.index === root.currentIndex || pointerArea.containsMouse
          ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
          : "transparent"
        border.width: resultRow.index === root.currentIndex ? 1 : 0
        border.color: Qt.rgba(
          root.accent.r, root.accent.g, root.accent.b, 0.35)

        Image {
          id: applicationIcon

          objectName: resultRow.resultData.kind === "application"
            ? "shortcutActionSearchApplicationIcon"
            : "shortcutActionSearchResultIcon"
          visible: true
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          width: 32
          height: 32
          fillMode: Image.PreserveAspectFit
          source: root.applicationIconSource(resultRow.resultData)
          asynchronous: true

          Text {
            objectName: "shortcutActionSearchIconFallback"
            anchors.centerIn: parent
            visible: applicationIcon.status === Image.Error
            text: VisibilityModel.fallbackIconGlyph(
              resultRow.resultData.badgeKind)
            color: resultRow.typeAccentColor
            font.family: root.fontFamily
            font.pixelSize: 13
            font.bold: true
          }
        }

        Row {
          id: leadingContent

          anchors.left: applicationIcon.right
          anchors.leftMargin: applicationIcon.visible ? 11 : 10
          anchors.right: shortcutChips.left
          anchors.rightMargin: shortcutChips.visible ? 12 : 10
          anchors.verticalCenter: parent.verticalCenter
          height: 26
          spacing: 7

          Text {
            id: resultTitle

            objectName: "shortcutActionSearchTitle"
            width: Math.max(0, Math.min(implicitWidth,
              leadingContent.width - (commandBadge.visible
                ? commandBadge.width + leadingContent.spacing : 0)
              - (roleBadge.visible
                ? roleBadge.width + leadingContent.spacing : 0)))
            height: leadingContent.height
            verticalAlignment: Text.AlignVCenter
            text: String(resultRow.resultData.title || "")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
          }

          Rectangle {
            id: commandBadge

            visible: resultRow.resultData.badgeKind === "cmd"
              || resultRow.resultData.badgeKind === "webapp"
              || resultRow.resultData.badgeKind === "desktopApp"
              || resultRow.resultData.badgeKind === "action"
              || resultRow.resultData.badgeKind === "systemUi"
            width: visible ? commandBadgeLabel.implicitWidth + 18 : 0
            height: 26
            radius: height / 2
            color: Qt.rgba(resultRow.typeAccentColor.r,
                           resultRow.typeAccentColor.g,
                           resultRow.typeAccentColor.b, 0.16)
            border.width: 1
            border.color: Qt.rgba(
              resultRow.typeAccentColor.r, resultRow.typeAccentColor.g,
              resultRow.typeAccentColor.b, 0.42)

            Text {
              id: commandBadgeLabel

              objectName: resultRow.resultData.badgeKind === "cmd"
                ? "shortcutActionSearchCommandBadge"
                : (resultRow.resultData.badgeKind === "webapp"
                    ? "shortcutActionSearchWebAppBadge"
                    : (resultRow.resultData.badgeKind === "desktopApp"
                        ? "shortcutActionSearchDesktopAppBadge"
                        : (resultRow.resultData.badgeKind === "action"
                            ? "shortcutActionSearchActionBadge"
                            : (resultRow.resultData.badgeKind === "systemUi"
                                ? "shortcutActionSearchSystemUiBadge" : ""))))
              anchors.centerIn: parent
              text: I18n.text(root.language,
                VisibilityModel.typeBadgeKey(
                  resultRow.resultData.badgeKind), {})
              color: resultRow.typeAccentColor
              font.family: root.fontFamily
              font.pixelSize: 11
              font.bold: true
            }
          }

          Rectangle {
            id: roleBadge

            visible: resultRow.resultData.roleBadgeKind === "agent"
              || resultRow.resultData.roleBadgeKind === "browser"
              || resultRow.resultData.roleBadgeKind === "editor"
            width: visible ? roleBadgeLabel.implicitWidth + 18 : 0
            height: 26
            radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g,
                           root.foreground.b, 0.09)
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g,
                                  root.foreground.b, 0.14)

            Text {
              id: roleBadgeLabel

              objectName: resultRow.resultData.roleBadgeKind === "agent"
                ? "shortcutActionSearchAgentBadge"
                : (resultRow.resultData.roleBadgeKind === "browser"
                    ? "shortcutActionSearchBrowserBadge"
                    : (resultRow.resultData.roleBadgeKind === "editor"
                        ? "shortcutActionSearchEditorBadge" : ""))
              anchors.centerIn: parent
              text: I18n.text(root.language,
                resultRow.resultData.roleBadgeKind === "agent"
                  ? "search.agentBadge"
                  : (resultRow.resultData.roleBadgeKind === "browser"
                      ? "search.browserBadge" : "search.editorBadge"), {})
              color: root.mutedForeground
              font.family: root.fontFamily
              font.pixelSize: 11
              font.bold: true
            }
          }
        }

        Row {
          id: shortcutChips

          objectName: "shortcutActionSearchShortcutChips"
          visible: resultRow.shortcutEntries.length > 0
          height: 26
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          spacing: 6

          Repeater {
            id: shortcutRepeater

            model: resultRow.shortcutEntries

            delegate: Rectangle {
              id: shortcutChip

              required property int index
              required property var modelData
              readonly property color accentColor: root.typeAccent(
                String(modelData.badgeKind || resultRow.resultData.badgeKind))

              objectName: "shortcutActionSearchShortcutChipSurface-" + index
              width: shortcutChipLabel.implicitWidth + 18
              height: 26
              radius: height / 2
              color: Qt.rgba(shortcutChip.accentColor.r,
                             shortcutChip.accentColor.g,
                             shortcutChip.accentColor.b, 0.16)
              border.width: 1
              border.color: Qt.rgba(shortcutChip.accentColor.r,
                                    shortcutChip.accentColor.g,
                                    shortcutChip.accentColor.b, 0.42)

              Text {
                id: shortcutChipLabel

                objectName: "shortcutActionSearchShortcutChip"
                anchors.centerIn: parent
                text: String(shortcutChip.modelData.chord || "")
                color: shortcutChip.accentColor
                font.family: root.fontFamily
                font.pixelSize: 11
              }
            }
          }
        }

        MouseArea {
          id: pointerArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            root.currentIndex = resultRow.index
            root.chooseResult(resultRow.resultData)
          }
        }
      }

      QQC.ScrollBar.vertical: QQC.ScrollBar {}
    }
  }
}
