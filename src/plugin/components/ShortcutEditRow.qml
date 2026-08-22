import QtQuick

Rectangle {
  id: root

  property var bindingData: ({})
  property bool managed: false
  property bool interactive: bindingData && bindingData.editable === true
  property color foreground: "#f2f2f2"
  property color mutedForeground: "#a7a7a7"
  property color accent: "#8fbfff"
  property color hoverColor: "#22ffffff"
  property string fontFamily: "sans-serif"
  readonly property string statusText: root.interactive ? "Edit key" : "Read only"

  signal editRequested(string bindingId)

  function requestEdit() {
    if (!root.interactive)
      return
    root.editRequested(String(root.bindingData.id || ""))
  }

  enabled: root.interactive
  opacity: root.interactive ? 1 : 0.55
  color: pointerHandler.hovered || activeFocus ? root.hoverColor : "transparent"
  radius: 8
  activeFocusOnTab: root.interactive

  Keys.onReturnPressed: root.requestEdit()
  Keys.onEnterPressed: root.requestEdit()
  Keys.onSpacePressed: root.requestEdit()

  Row {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 12

    Rectangle {
      width: Math.max(72, keyLabel.implicitWidth + 20)
      height: 30
      anchors.verticalCenter: parent.verticalCenter
      color: "#18ffffff"
      border.color: "#35ffffff"
      border.width: 1
      radius: 6

      Text {
        id: keyLabel
        anchors.centerIn: parent
        text: String(root.bindingData.key || "")
        color: root.foreground
        font.family: root.fontFamily
        font.bold: true
        elide: Text.ElideRight
      }
    }

    Text {
      width: Math.max(1, parent.width - x - editLabel.width - parent.spacing)
      anchors.verticalCenter: parent.verticalCenter
      text: String(root.bindingData.description || "") + (root.managed ? " · Managed" : "")
      color: root.interactive ? root.foreground : root.mutedForeground
      font.family: root.fontFamily
      elide: Text.ElideRight
    }

    Text {
      id: editLabel
      anchors.verticalCenter: parent.verticalCenter
      text: root.statusText
      color: root.interactive ? root.accent : root.mutedForeground
      font.family: root.fontFamily
      font.bold: root.interactive
    }
  }

  HoverHandler { id: pointerHandler }

  TapHandler {
    onTapped: {
      root.forceActiveFocus()
      root.requestEdit()
    }
  }
}
