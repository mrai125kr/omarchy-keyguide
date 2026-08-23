pragma ComponentBehavior: Bound

import QtQuick
import "../I18n.js" as I18n
import "../VisibilityModel.js" as VisibilityModel

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
  readonly property bool compactLayout: width < 900
  readonly property int titleTypeGap: 16
  readonly property int typeHudGap: 24
  readonly property real typeRoleColumnWidth: root.compactLayout
    ? Math.min(224, Math.max(108, Math.round(root.width * 0.28)))
    : 224
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
  property color surface: "#151515"
  property color hoverColor: "#22ffffff"
  property string fontFamily: "sans-serif"
  property var iconResolver: null
  readonly property string displayKind: String(
    root.bindingData && root.bindingData.displayKind || "action")
  readonly property string roleKind: String(
    root.bindingData && root.bindingData.roleKind || "")
  readonly property color typeAccentColor: VisibilityModel.typeAccent(
    root.displayKind, root.surfaceIsLight(), root.accent)

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

  function surfaceIsLight() {
    return root.surface.r * 0.2126 + root.surface.g * 0.7152
      + root.surface.b * 0.0722 > 0.55
  }

  function presentationIconSource() {
    const iconName = String(root.bindingData && root.bindingData.icon || "")
    if (!iconName)
      return ""
    if (typeof root.iconResolver === "function") {
      const resolved = String(root.iconResolver(iconName) || "")
      if (resolved)
        return resolved
    }
    return "image://icon/" + iconName
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
      : 316
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
    width: Math.max(0, typeRoleCell.x - x - root.titleTypeGap)
    height: root.compactLayout ? Math.max(0, root.height - y - 4) : root.height
    clip: true

    Column {
      width: parent.width
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1

      Item {
        id: bindingPresentationLine

        width: parent.width
        height: 26

        Image {
          id: bindingPresentationIcon

          objectName: "bindingPresentationIcon"
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: 24
          height: 24
          sourceSize.width: 24
          sourceSize.height: 24
          source: root.presentationIconSource()
          visible: String(source || "") !== ""
          fillMode: Image.PreserveAspectFit
          smooth: true

          Text {
            objectName: "bindingPresentationIconFallback"
            anchors.centerIn: parent
            visible: bindingPresentationIcon.status === Image.Error
            text: VisibilityModel.fallbackIconGlyph(root.displayKind)
            color: root.typeAccentColor
            font.family: root.fontFamily
            font.pixelSize: 12
            font.bold: true
          }
        }

        Text {
          id: bindingTitleLabel

          objectName: "bindingTitleLabel"
          x: bindingPresentationIcon.visible
            ? bindingPresentationIcon.width + 8 : 0
          width: Math.max(0, parent.width - x)
          height: parent.height
          verticalAlignment: Text.AlignVCenter
          text: String(root.bindingData.description || "")
          color: root.visibleInHud ? root.foreground : root.mutedForeground
          font.family: root.fontFamily
          font.pixelSize: 13
          elide: Text.ElideRight
        }

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

  Item {
    id: typeRoleCell

    objectName: "bindingTypeRoleCell"
    x: visibilityTarget.x - root.typeHudGap - width
    y: root.compactLayout ? 42 : 0
    width: root.typeRoleColumnWidth
    height: root.compactLayout ? Math.max(0, root.height - y - 4) : root.height
    clip: true

    Item {
      id: bindingBadgeCluster

      objectName: "bindingBadgeCluster"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      width: bindingTypeBadge.width + (bindingRoleBadge.visible
        ? 10 + bindingRoleBadge.width : 0)
      height: 24

      Rectangle {
        id: bindingTypeBadge

        objectName: "bindingTypeBadge"
        x: 0
        anchors.verticalCenter: parent.verticalCenter
        width: bindingTypeBadgeLabel.implicitWidth + 16
        height: 24
        radius: height / 2
        color: Qt.rgba(root.typeAccentColor.r, root.typeAccentColor.g,
                       root.typeAccentColor.b, 0.16)
        border.width: 1
        border.color: Qt.rgba(root.typeAccentColor.r,
          root.typeAccentColor.g, root.typeAccentColor.b, 0.42)

        Text {
          id: bindingTypeBadgeLabel

          objectName: "bindingTypeBadgeLabel"
          anchors.centerIn: parent
          text: I18n.text(root.language,
            VisibilityModel.typeBadgeKey(root.displayKind), {})
          color: root.typeAccentColor
          font.family: root.fontFamily
          font.pixelSize: 10
          font.bold: true
        }
      }

      Rectangle {
        id: bindingRoleBadge

        objectName: "bindingRoleBadge"
        visible: VisibilityModel.roleBadgeKey(root.roleKind) !== ""
          && !root.compactLayout
        x: bindingTypeBadge.width + 10
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? bindingRoleBadgeLabel.implicitWidth + 16 : 0
        height: 24
        radius: height / 2
        color: Qt.rgba(root.foreground.r, root.foreground.g,
                       root.foreground.b, 0.08)
        border.width: 1
        border.color: Qt.rgba(root.foreground.r, root.foreground.g,
                              root.foreground.b, 0.18)

        Text {
          id: bindingRoleBadgeLabel

          objectName: "bindingRoleBadgeLabel"
          anchors.centerIn: parent
          text: I18n.text(root.language,
            VisibilityModel.roleBadgeKey(root.roleKind), {})
          color: root.mutedForeground
          font.family: root.fontFamily
          font.pixelSize: 10
          font.bold: true
        }
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
