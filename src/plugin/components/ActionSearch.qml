pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import "../ActionSearchModel.js" as ActionSearchModel
import "../I18n.js" as I18n

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

  readonly property var results: ActionSearchModel.results(
    query, language, actions, catalogItems, 0)
  readonly property int resultCount: results.length

  signal selected(var result)
  signal watchingChanged(bool watching)

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

  onActionsChanged: Qt.callLater(function() { root.reconcileSelection() })
  onCatalogItemsChanged: Qt.callLater(function() { root.reconcileSelection() })
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
    updateCurrentIndex()
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
      section.property: "kind"
      section.criteria: ViewSection.FullString

      section.delegate: Item {
        required property string section

        width: resultList.width
        height: 34

        Text {
          objectName: "shortcutActionSearchCategory-" + parent.section
          anchors.left: parent.left
          anchors.leftMargin: 8
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 7
          text: I18n.text(
            root.language, "search.category." + parent.section, {})
          color: root.mutedForeground
          font.family: root.fontFamily
          font.pixelSize: 12
          font.bold: true
        }
      }

      delegate: Rectangle {
        id: resultRow

        required property int index
        required property var modelData
        property var resultData: modelData

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

          objectName: "shortcutActionSearchApplicationIcon"
          visible: resultRow.resultData.kind === "application"
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          width: visible ? 32 : 0
          height: 32
          fillMode: Image.PreserveAspectFit
          source: visible ? root.applicationIconSource(resultRow.resultData) : ""
          asynchronous: true
        }

        Row {
          id: leadingContent

          anchors.left: applicationIcon.right
          anchors.leftMargin: applicationIcon.visible ? 11 : 10
          anchors.right: shortcutChip.left
          anchors.rightMargin: shortcutChip.visible ? 12 : 10
          anchors.verticalCenter: parent.verticalCenter
          height: 26
          spacing: 7

          Text {
            id: resultTitle

            objectName: "shortcutActionSearchTitle"
            width: Math.max(0, Math.min(implicitWidth,
              leadingContent.width - (commandBadge.visible
                ? commandBadge.width + leadingContent.spacing : 0)))
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

            visible: resultRow.resultData.kind === "command"
              || resultRow.resultData.badgeKind === "webapp"
            width: visible ? commandBadgeLabel.implicitWidth + 18 : 0
            height: 26
            radius: height / 2
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
            border.width: 1
            border.color: Qt.rgba(
              root.accent.r, root.accent.g, root.accent.b, 0.30)

            Text {
              id: commandBadgeLabel

              objectName: resultRow.resultData.kind === "command"
                ? "shortcutActionSearchCommandBadge"
                : (resultRow.resultData.badgeKind === "webapp"
                    ? "shortcutActionSearchWebAppBadge" : "")
              anchors.centerIn: parent
              text: I18n.text(root.language,
                resultRow.resultData.kind === "command"
                  ? "search.commandBadge" : "search.webAppBadge", {})
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: 11
              font.bold: true
            }
          }
        }

        Rectangle {
          id: shortcutChip

          visible: String(resultRow.resultData.currentChord || "") !== ""
          width: visible ? shortcutChipLabel.implicitWidth + 18 : 0
          height: 26
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          radius: height / 2
          color: Qt.rgba(root.foreground.r, root.foreground.g,
                         root.foreground.b, 0.09)
          border.width: 1
          border.color: Qt.rgba(root.foreground.r, root.foreground.g,
                                root.foreground.b, 0.10)

          Text {
            id: shortcutChipLabel

            objectName: shortcutChip.visible
              ? "shortcutActionSearchShortcutChip" : ""
            anchors.centerIn: parent
            text: String(resultRow.resultData.currentChord || "")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: 11
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
