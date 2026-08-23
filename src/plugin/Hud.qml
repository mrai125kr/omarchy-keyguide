pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "I18n.js" as I18n
import "VisibilityModel.js" as VisibilityModel

PanelWindow {
  id: root

  property bool hudVisible: false
  property string language: "en"
  property var modifiers: []
  property var bindings: []
  property var settings: ({})

  readonly property real hudScale: Math.max(0.75, Math.min(1.5, Number(settings.scale || 1)))
  readonly property real hudOpacity: Math.max(0.2, Math.min(1, Number(settings.opacity || 0.94)))
  readonly property string hudPosition: String(settings.position || "center")
  readonly property color hudBackground: settings.followTheme === false ? "#151515" : Color.popups.background
  readonly property color hudForeground: settings.followTheme === false ? "#f2f2f2" : Color.popups.text
  readonly property color hudAccent: settings.followTheme === false ? "#8fbfff" : Color.accent
  readonly property color hudBorder: settings.followTheme === false ? Util.alpha(hudForeground, 0.22) : Color.popups.border
  readonly property color hudChipBackground: Util.alpha(hudForeground, 0.1)
  readonly property color hudChipBorder: Util.alpha(hudForeground, 0.28)
  readonly property var hudBorderSpec: settings.followTheme === false ? Border.flat(hudBorder, Math.max(1, Style.space(1))) : Border.surfaceSpec("popups", "border", hudBorder, Math.max(1, Style.space(1)))
  readonly property int outerMargin: Math.round(Style.space(32) * hudScale)
  readonly property int cardPadding: Math.round(Style.space(18) * hudScale)
  readonly property int headerHeight: Math.round(Style.space(34) * hudScale)
  readonly property int rowHeight: Math.round(Style.space(42) * hudScale)
  readonly property int columnGap: Math.round(Style.space(28) * hudScale)
  readonly property int baseColumnWidth: Math.round(Style.space(300) * hudScale)
  readonly property int usableHeight: Math.max(rowHeight, height - outerMargin * 2 - cardPadding * 2 - headerHeight)
  readonly property int rowsPerColumn: Math.max(1, Math.floor(usableHeight / rowHeight))
  readonly property int columnCount: Math.max(1, Math.ceil(bindings.length / rowsPerColumn))
  readonly property int usableWidth: Math.max(columnCount, width - outerMargin * 2 - cardPadding * 2 - columnGap * (columnCount - 1))
  readonly property int columnWidth: Math.max(1, Math.min(baseColumnWidth, Math.floor(usableWidth / columnCount)))
  readonly property int renderedRowCount: bindingRepeater.count
  readonly property var displayModifiers: modifiers.map(function(modifier) {
    return I18n.modifier(root.language, modifier)
  })
  readonly property real cardLeft: card.x
  readonly property real cardTop: card.y
  readonly property real cardRight: card.x + card.width
  readonly property real cardBottom: card.y + card.height
  readonly property var focusedScreen: {
    const monitor = Hyprland.focusedMonitor
    const screens = Quickshell.screens || []
    if (monitor) {
      for (let index = 0; index < screens.length; index += 1) {
        if (screens[index] && screens[index].name === monitor.name)
          return screens[index]
      }
    }
    return screens.length > 0 ? screens[0] : null
  }

  function cardX(cardWidth) {
    if (hudPosition === "left")
      return outerMargin
    if (hudPosition === "right")
      return width - outerMargin - cardWidth
    return Math.round((width - cardWidth) / 2)
  }

  function cardY(cardHeight) {
    if (hudPosition === "top")
      return outerMargin
    if (hudPosition === "bottom")
      return height - outerMargin - cardHeight
    return Math.round((height - cardHeight) / 2)
  }

  function presentationIconSource(binding) {
    const iconName = String(binding && binding.icon || "")
    if (!iconName)
      return ""
    const resolved = String(Quickshell.iconPath(iconName, true) || "")
    return resolved || "image://icon/" + iconName
  }

  function surfaceIsLight() {
    return root.hudBackground.r * 0.2126
      + root.hudBackground.g * 0.7152
      + root.hudBackground.b * 0.0722 > 0.55
  }

  screen: focusedScreen
  visible: hudVisible && focusedScreen !== null && bindings.length > 0
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  color: "transparent"
  WlrLayershell.namespace: "mrai-keyguide"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}

  BorderSurface {
    id: card

    padding: root.cardPadding
    width: card.contentLeftInset + bindingGrid.width + card.contentRightInset
    height: card.contentTopInset + root.headerHeight + bindingGrid.height + card.contentBottomInset
    x: root.cardX(card.width)
    y: root.cardY(card.height)
    color: Util.alpha(root.hudBackground, root.hudOpacity)
    borderSpec: root.hudBorderSpec
    radius: Style.cornerRadius

    Text {
      id: heading

      objectName: "hudHeading"
      x: card.contentLeftInset
      y: card.contentTopInset
      width: bindingGrid.width
      height: root.headerHeight
      text: I18n.text(root.language, "hud.heading", {
        modifiers: root.displayModifiers.join(" + ")
      })
      color: root.hudForeground
      font.family: Style.font.family
      font.pixelSize: Math.round(Style.font.heading * root.hudScale)
      font.weight: Font.DemiBold
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }

    Grid {
      id: bindingGrid

      x: card.contentLeftInset
      y: card.contentTopInset + root.headerHeight
      rows: root.rowsPerColumn
      flow: Grid.TopToBottom
      rowSpacing: 0
      columnSpacing: root.columnGap

      Repeater {
        id: bindingRepeater
        model: root.bindings

        delegate: Item {
          id: bindingRow
          required property var modelData

          width: root.columnWidth
          height: root.rowHeight

          RowLayout {
            anchors.fill: bindingRow
            spacing: Math.max(Style.space(6), Math.round(Style.space(8) * root.hudScale))

            Rectangle {
              Layout.preferredWidth: Math.min(bindingRow.width * 0.42, Math.max(Style.space(54), keyLabel.implicitWidth + Style.space(18)))
              Layout.preferredHeight: Math.round(Style.space(27) * root.hudScale)
              color: root.hudChipBackground
              border.color: root.hudChipBorder
              border.width: Math.max(1, Style.space(1))
              radius: Math.max(Style.space(4), Math.round(Style.cornerRadius * 0.55))

              Text {
                id: keyLabel
                anchors.centerIn: parent
                width: parent.width - Style.space(10)
                text: String(bindingRow.modelData.key || "")
                color: root.hudForeground
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.bodySmall * root.hudScale)
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }
            }

            Image {
              id: presentationIcon

              objectName: "hudPresentationIcon-"
                + String(bindingRow.modelData.id || "")
              Layout.preferredWidth: visible
                ? Math.round(Style.space(20) * root.hudScale) : 0
              Layout.preferredHeight: Math.round(Style.space(20) * root.hudScale)
              sourceSize.width: Math.round(Style.space(20) * root.hudScale)
              sourceSize.height: Math.round(Style.space(20) * root.hudScale)
              source: root.presentationIconSource(bindingRow.modelData)
              visible: String(source || "") !== ""
              fillMode: Image.PreserveAspectFit
              smooth: true

              Text {
                objectName: "hudPresentationIconFallback-"
                  + String(bindingRow.modelData.id || "")
                anchors.centerIn: parent
                visible: presentationIcon.status === Image.Error
                text: VisibilityModel.fallbackIconGlyph(
                  String(bindingRow.modelData.displayKind || "action"))
                color: VisibilityModel.typeAccent(
                  String(bindingRow.modelData.displayKind || "action"),
                  root.surfaceIsLight(), root.hudAccent)
                font.family: Style.font.family
                font.pixelSize: Math.round(
                  Style.font.caption * root.hudScale)
                font.weight: Font.DemiBold
              }
            }

            Text {
              objectName: "hudDescription-"
                + String(bindingRow.modelData.id || "")
              Layout.fillWidth: true
              text: String(bindingRow.modelData.description || "")
              color: root.hudForeground
              font.family: Style.font.family
              font.pixelSize: Math.round(Style.font.body * root.hudScale)
              elide: Text.ElideRight
              maximumLineCount: 1
              wrapMode: Text.NoWrap
            }

            Rectangle {
              id: typeBadge

              readonly property string displayKind: String(
                bindingRow.modelData.displayKind || "action")
              readonly property color typeAccent: VisibilityModel.typeAccent(
                displayKind, root.surfaceIsLight(), root.hudAccent)
              objectName: "hudTypeBadge-"
                + String(bindingRow.modelData.id || "")
              visible: bindingRow.width >= Math.round(
                Style.space(230) * root.hudScale)
              Layout.preferredWidth: visible
                ? typeBadgeLabel.implicitWidth + Style.space(14) : 0
              Layout.preferredHeight: Math.round(Style.space(22) * root.hudScale)
              radius: height / 2
              color: Qt.rgba(typeAccent.r, typeAccent.g, typeAccent.b, 0.16)
              border.width: Math.max(1, Style.space(1))
              border.color: Qt.rgba(
                typeAccent.r, typeAccent.g, typeAccent.b, 0.42)

              Text {
                id: typeBadgeLabel

                objectName: "hudTypeBadgeLabel-"
                  + String(bindingRow.modelData.id || "")
                anchors.centerIn: parent
                text: I18n.text(root.language,
                  VisibilityModel.typeBadgeKey(typeBadge.displayKind), {})
                color: typeBadge.typeAccent
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.caption * root.hudScale)
                font.weight: Font.DemiBold
              }
            }
          }
        }
      }
    }
  }
}
