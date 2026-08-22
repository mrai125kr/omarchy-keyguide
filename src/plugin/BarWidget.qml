pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "mrai.keyguide"

  readonly property var shell: root.bar ? root.bar.shell : null
  readonly property var service: root.shell && typeof root.shell.serviceFor === "function"
    ? root.shell.serviceFor(root.moduleName) : null
  readonly property bool opened: panel.open
  readonly property bool active: root.service && root.service.settings
    ? root.service.settings.enabled === true : false
  readonly property bool saving: root.service
    ? root.service.settingsSaveActive === true : false
  property bool cursorActive: false
  property int cursorIndex: 0
  property url keyguideIconSource: Quickshell.iconPath("omarchy-keyguide", true)
  readonly property string statusText: {
    if (!root.service) return "Keyguide service is unavailable"
    const error = String(root.service.settingsSaveError || root.service.lastError || "")
    return error || (root.saving ? "Saving…" : "")
  }

  function open() {
    panel.open = true
  }

  function close() {
    panel.open = false
  }

  function togglePanel() {
    panel.open = !panel.open
  }

  function setEnabled(enabled) {
    return root.service && typeof root.service.patchSettings === "function"
      ? root.service.patchSettings({ enabled: enabled === true }) : false
  }

  function setOpacity(opacity) {
    const bounded = Math.max(0.20, Math.min(1.00, Number(opacity)))
    return root.service && typeof root.service.patchSettings === "function"
      ? root.service.patchSettings({ opacity: bounded }) : false
  }

  function openSettings() {
    root.close()
    return root.shell && typeof root.shell.summon === "function"
      ? root.shell.summon(root.moduleName) : false
  }

  function selectCursor(index) {
    root.cursorActive = true
    root.cursorIndex = Math.max(0, Math.min(2, Number(index)))
  }

  function moveCursor(dx, dy) {
    if (!root.cursorActive) {
      root.selectCursor(0)
      return
    }
    if (dy !== 0) {
      root.selectCursor((root.cursorIndex + (dy < 0 ? -1 : 1) + 3) % 3)
      return
    }
    if (dx !== 0 && root.cursorIndex === 1 && !root.saving) {
      const current = root.service && root.service.settings
        ? Number(root.service.settings.opacity) : 0.94
      root.setOpacity(current + (dx < 0 ? -0.05 : 0.05))
    }
  }

  function activateCursor() {
    if (!root.cursorActive || root.saving)
      return
    if (root.cursorIndex === 0)
      root.setEnabled(!root.active)
    else if (root.cursorIndex === 2)
      root.openSettings()
  }

  function switchPanel(direction) {
    return root.bar && typeof root.bar.switchPanelFrom === "function"
      ? root.bar.switchPanelFrom(root, direction) : false
  }

  readonly property bool popoutSwitchClosing: panel.popoutSwitchClosing

  onOpenedChanged: if (root.opened) root.cursorActive = false

  function closeForPopoutSwitch() {
    panel.popoutSwitchClosing = true
    root.close()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    objectName: "keyguideBarButton"
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        Image {
          id: keyguideBarIconImage
          objectName: "keyguideBarIconImage"
          anchors.fill: parent
          source: root.keyguideIconSource
          fillMode: Image.PreserveAspectFit
          opacity: root.active ? 1.0 : 0.42
          sourceSize.width: width * Screen.devicePixelRatio
          sourceSize.height: height * Screen.devicePixelRatio
        }

        Text {
          objectName: "keyguideBarIconFallback"
          anchors.fill: parent
          visible: keyguideBarIconImage.status !== Image.Ready
          text: "⌨"
          opacity: root.active ? 1.0 : 0.42
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.bar.iconFont
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
    active: root.active
    tooltipText: "Keyguide"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton)
        root.togglePanel()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      objectName: "keyguidePanelKeyCatcher"
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.spacing.md

        RowLayout {
          Layout.fillWidth: true

          Text {
            Layout.fillWidth: true
            text: "Shortcut HUD"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          ToggleSwitch {
            objectName: "keyguideEnabledToggle"
            checked: root.active
            busy: root.saving
            enabled: root.service !== null && !root.saving
            hasCursor: root.cursorActive && root.cursorIndex === 0
            foreground: root.bar ? root.bar.foreground : Color.foreground
            onHovered: function(isHovered) { if (isHovered) root.selectCursor(0) }
            onToggled: root.setEnabled(!root.active)
          }
        }

        RowLayout {
          Layout.fillWidth: true

          Text {
            Layout.fillWidth: true
            text: "Opacity"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            text: Math.round(opacitySlider.value * 100) + "%"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        CursorSurface {
          id: opacityCursor
          objectName: "keyguideOpacityCursor"
          Layout.fillWidth: true
          Layout.preferredHeight: opacitySlider.implicitHeight + Style.spacing.controlGap
          enabled: root.service !== null && !root.saving
          hasCursor: root.cursorActive && root.cursorIndex === 1
          foreground: root.bar ? root.bar.foreground : Color.foreground
          outline: true

          PanelSlider {
            id: opacitySlider
            objectName: "keyguideOpacitySlider"
            anchors.fill: parent
            anchors.leftMargin: Style.space(6)
            anchors.rightMargin: Style.space(6)
            bar: root.bar
            minimum: 0.20
            maximum: 1.00
            step: 0.05
            value: root.service && root.service.settings
              ? Number(root.service.settings.opacity) : 0.94
            onReleased: function(nextValue) { root.setOpacity(nextValue) }
          }

          HoverHandler {
            onHoveredChanged: if (hovered) root.selectCursor(1)
          }
        }

        RowLayout {
          Layout.fillWidth: true

          Text {
            Layout.fillWidth: true
            text: "Settings"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.bodySmall
          }

          PanelActionButton {
            objectName: "keyguideSettingsButton"
            iconText: "⚙"
            tooltipText: "Open Keyguide settings"
            foreground: root.bar ? root.bar.foreground : Color.foreground
            enabled: root.shell !== null && !root.saving
            hasCursor: root.cursorActive && root.cursorIndex === 2
            onHovered: function(isHovered) { if (isHovered) root.selectCursor(2) }
            onClicked: root.openSettings()
          }
        }

        Text {
          objectName: "keyguideStatusText"
          Layout.fillWidth: true
          visible: root.statusText !== ""
          text: root.statusText
          color: root.statusText === "Saving…"
            ? (root.bar ? root.bar.foreground : Color.foreground)
            : (root.bar ? root.bar.urgent : Color.urgent)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
