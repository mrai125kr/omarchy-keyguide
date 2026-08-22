pragma ComponentBehavior: Bound

import QtQuick
import "../I18n.js" as I18n

Rectangle {
  id: root

  property var bindingData: ({})
  property string language: "en"
  property bool visibleInHud: true
  property bool interactive: true
  property bool editable: true
  property string editReason: ""
  readonly property string editText: root.editable
    ? I18n.text(root.language, "common.change", {})
    : I18n.text(root.language, "common.unavailable", {})
  readonly property string reasonText: root.editable ? "" : root.editReason
  readonly property bool compactLayout: width < 720
  readonly property var chordParts: {
    const parts = []
    const modifiers = root.bindingData && root.bindingData.modifiers
      && typeof root.bindingData.modifiers.length === "number"
      ? root.bindingData.modifiers : []
    for (let index = 0; index < modifiers.length; index += 1)
      parts.push(root.chordPartName(modifiers[index]))
    const key = String(root.bindingData && root.bindingData.key || "")
    if (key)
      parts.push(key)
    return parts
  }
  property color foreground: "#f2f2f2"
  property color mutedForeground: "#a7a7a7"
  property color accent: "#8fbfff"
  property color hoverColor: "#22ffffff"
  property string fontFamily: "sans-serif"

  signal visibilityChangeRequested(string bindingId, bool visibleInHud)
  signal editRequested(string bindingId, var anchorItem)

  function chordPartName(value) {
    return I18n.modifier(root.language, String(value || ""))
  }

  function requestToggle() {
    if (!root.interactive)
      return
    root.visibilityChangeRequested(
      String(root.bindingData.presentation_id || root.bindingData.id || ""),
      !root.visibleInHud
    )
  }

  function requestEdit() {
    if (!root.interactive || !root.editable)
      return
    root.editRequested(String(root.bindingData.id || ""), root)
  }

  function containsPoint(item, point) {
    return point.x >= item.x && point.x <= item.x + item.width
      && point.y >= item.y && point.y <= item.y + item.height
  }

  implicitHeight: root.compactLayout ? 84 : 56
  enabled: root.interactive
  opacity: root.interactive ? 1 : 0.5
  color: pointerHandler.hovered || activeFocus ? root.hoverColor : "transparent"
  radius: 8
  activeFocusOnTab: false

  Keys.onReturnPressed: root.requestToggle()
  Keys.onEnterPressed: root.requestToggle()
  Keys.onSpacePressed: root.requestToggle()

  Item {
    id: chordCell

    objectName: "bindingChordCell"
    x: 12
    y: root.compactLayout ? 6 : Math.round((root.height - height) / 2)
    width: root.compactLayout
      ? Math.max(1, root.width - 24)
      : 340
    height: 32
    clip: true

    Row {
      objectName: "bindingChordParts"
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      Repeater {
        model: root.chordParts

        delegate: Row {
          id: chordPart

          required property int index
          required property var modelData
          height: 28
          spacing: 4

          Rectangle {
            width: Math.max(34, chordPartLabel.implicitWidth + 16)
            height: 28
            color: "#18ffffff"
            border.color: "#45ffffff"
            border.width: 1
            radius: 6

            Text {
              id: chordPartLabel

              anchors.centerIn: parent
              text: String(chordPart.modelData || "")
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 11
              font.bold: true
              elide: Text.ElideRight
            }
          }

          Text {
            visible: chordPart.index < root.chordParts.length - 1
            anchors.verticalCenter: parent.verticalCenter
            text: "+"
            color: root.mutedForeground
            font.family: root.fontFamily
            font.pixelSize: 11
            font.bold: true
          }
        }
      }
    }
  }

  Rectangle {
    id: editTarget

    objectName: "bindingEditTarget"
    anchors.right: parent.right
    anchors.rightMargin: 12
    y: root.compactLayout ? 44 : Math.round((root.height - height) / 2)
    width: 104
    height: 32
    radius: 6
    color: editHandler.hovered || activeFocus ? "#18ffffff" : "transparent"
    border.color: root.editable ? "#45ffffff" : "#22ffffff"
    border.width: 1
    enabled: root.interactive && root.editable
    activeFocusOnTab: enabled

    Keys.onReturnPressed: root.requestEdit()
    Keys.onEnterPressed: root.requestEdit()
    Keys.onSpacePressed: root.requestEdit()

    Text {
      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignHCenter
      text: root.editText
      color: root.editable ? root.foreground : root.mutedForeground
      font.family: root.fontFamily
      font.pixelSize: 12
      font.bold: root.editable
      elide: Text.ElideRight
    }

    HoverHandler {
      id: editHandler
    }

    TapHandler {
      onTapped: root.requestEdit()
    }
  }

  Rectangle {
    id: visibilityTarget

    objectName: "bindingVisibilityTarget"
    anchors.right: editTarget.left
    anchors.rightMargin: 8
    y: root.compactLayout ? 44 : Math.round((root.height - height) / 2)
    width: 84
    height: 32
    radius: 6
    color: visibilityHandler.hovered || activeFocus ? "#18ffffff" : "transparent"
    border.color: "#45ffffff"
    border.width: 1
    enabled: root.interactive
    activeFocusOnTab: enabled

    Keys.onReturnPressed: root.requestToggle()
    Keys.onEnterPressed: root.requestToggle()
    Keys.onSpacePressed: root.requestToggle()

    Text {
      anchors.centerIn: parent
      text: root.visibleInHud
        ? I18n.text(root.language, "common.shown", {})
        : I18n.text(root.language, "common.hidden", {})
      color: root.visibleInHud ? root.accent : root.mutedForeground
      font.family: root.fontFamily
      font.pixelSize: 12
      font.bold: root.visibleInHud
    }

    HoverHandler {
      id: visibilityHandler
    }

    TapHandler {
      onTapped: root.requestToggle()
    }
  }

  Item {
    id: descriptionCell

    objectName: "bindingDescriptionCell"
    x: root.compactLayout ? 12 : chordCell.x + chordCell.width + 12
    y: root.compactLayout ? 42 : 0
    width: root.compactLayout
      ? Math.max(0, visibilityTarget.x - x - 12)
      : Math.max(0, visibilityTarget.x - x - 12)
    height: root.compactLayout ? Math.max(0, root.height - y - 4) : root.height
    clip: true

    Column {
      width: parent.width
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1

      Text {
        width: parent.width
        text: String(root.bindingData.description || "")
        color: root.visibleInHud ? root.foreground : root.mutedForeground
        font.family: root.fontFamily
        font.pixelSize: 13
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: root.reasonText !== ""
        text: root.reasonText
        color: root.mutedForeground
        font.family: root.fontFamily
        font.pixelSize: 11
        elide: Text.ElideRight
      }
    }
  }

  HoverHandler {
    id: pointerHandler
  }

  TapHandler {
    onTapped: function(point) {
      if (root.containsPoint(visibilityTarget, point.position)
          || root.containsPoint(editTarget, point.position))
        return
      root.forceActiveFocus()
      root.requestToggle()
    }
  }
}
