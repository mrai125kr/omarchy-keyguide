import QtQuick
import "../HudModel.js" as HudModel
import "../I18n.js" as I18n
import "../VisibilityModel.js" as VisibilityModel

Item {
  id: root

  property string language: "en"
  property var settings: ({})
  property var bindings: []
  property var previewModifiers: ["SUPER"]
  property color themeBackground: "#20242a"
  property color themeForeground: "#f2f2f2"
  property color themeAccent: "#8fbfff"
  property color themeBorder: Qt.alpha(themeForeground, 0.22)
  property string fontFamily: "sans-serif"
  property var iconResolver: null

  function arrayFrom(value) {
    if (!value || typeof value.length !== "number" || typeof value === "string")
      return []
    const result = []
    for (let index = 0; index < value.length; index += 1)
      result.push(value[index])
    return result
  }

  function bindingsForModel(value) {
    return root.arrayFrom(value).map(function (binding) {
      if (!binding || typeof binding !== "object")
        return binding
      const normalized = {}
      for (const key in binding)
        normalized[key] = binding[key]
      normalized.modifiers = root.arrayFrom(binding.modifiers)
      return normalized
    })
  }

  readonly property real previewOpacity: Math.max(0.2, Math.min(1.0, Number(root.settings.opacity === undefined ? 0.94 : root.settings.opacity)))
  readonly property real previewScale: Math.max(0.75, Math.min(1.5, Number(root.settings.scale === undefined ? 1.0 : root.settings.scale)))
  readonly property string previewGroupName: root.arrayFrom(root.previewModifiers).join("+")
  readonly property bool previewGroupEnabled: root.settings.groups === undefined || root.arrayFrom(root.settings.groups).indexOf(root.previewGroupName) !== -1
  readonly property var visibleBindings: root.previewGroupEnabled ? HudModel.forGroup(root.bindingsForModel(root.bindings), root.arrayFrom(root.previewModifiers), root.arrayFrom(root.settings.hiddenBindingIds)) : []
  readonly property var displayModifiers: root.arrayFrom(root.previewModifiers).map(function(modifier) {
    return I18n.modifier(root.language, modifier)
  })
  readonly property int renderedRowCount: previewList.count
  readonly property bool previewCardVisible: root.settings.enabled !== false
  readonly property string previewPosition: ["center", "top", "bottom", "left", "right"].indexOf(String(root.settings.position || "center")) !== -1 ? String(root.settings.position || "center") : "center"
  readonly property real previewCardX: previewCard.x
  readonly property real previewCardY: previewViewport.y + previewCard.y
  readonly property real previewCardOpacity: previewCard.opacity
  readonly property color previewCardBackground: previewCard.color
  readonly property string previewHeadingText: I18n.text(
    root.language, "hud.heading", { modifiers: root.displayModifiers.join(" + ") })
  readonly property string previewOpacityText: I18n.text(
    root.language, "settings.opacity", {}) + " "
    + Math.round(root.previewOpacity * 100) + "%"
  readonly property color previewStageTopColor: "#34445a"
  readonly property color previewStageBottomColor: "#121821"
  readonly property color previewBackground: root.settings.followTheme === false ? "#151515" : root.themeBackground
  readonly property color previewForeground: root.settings.followTheme === false ? "#f2f2f2" : root.themeForeground
  readonly property color previewAccent: root.settings.followTheme === false ? "#8fbfff" : root.themeAccent
  readonly property color previewBorder: root.settings.followTheme === false ? Qt.alpha(root.previewForeground, 0.22) : root.themeBorder
  readonly property color previewChipBackground: Qt.alpha(root.previewForeground, 0.1)
  readonly property color previewChipBorder: Qt.alpha(root.previewForeground, 0.28)
  readonly property real previewAnnotationHeight: 38
  readonly property real previewMargin: 16
  readonly property real previewTextHeight: 30
  readonly property real previewRowHeight: previewTextHeight + 8
  readonly property real previewRowsHeight: previewList.count > 0
    ? previewList.count * previewRowHeight + (previewList.count - 1) * previewList.spacing
    : 44
  readonly property real previewNaturalCardHeight: 16 + 26 + 8 + previewRowsHeight + 12

  function cardX(cardWidth) {
    const paintedWidth = cardWidth * root.previewScale
    const transformInset = (paintedWidth - cardWidth) / 2
    if (root.previewPosition === "left")
      return root.previewMargin + transformInset
    if (root.previewPosition === "right")
      return previewViewport.width - root.previewMargin - paintedWidth + transformInset
    return (previewViewport.width - cardWidth) / 2
  }

  function cardY(cardHeight) {
    const paintedHeight = cardHeight * root.previewScale
    const transformInset = (paintedHeight - cardHeight) / 2
    if (root.previewPosition === "top")
      return root.previewMargin + transformInset
    if (root.previewPosition === "bottom")
      return previewViewport.height - root.previewMargin - paintedHeight + transformInset
    return (previewViewport.height - cardHeight) / 2
  }

  function presentationIconSource(binding) {
    const iconName = String(binding && binding.icon || "")
    if (!iconName)
      return ""
    if (typeof root.iconResolver === "function") {
      const resolved = String(root.iconResolver(iconName) || "")
      if (resolved)
        return resolved
    }
    return "image://icon/" + iconName
  }

  function surfaceIsLight() {
    return root.previewBackground.r * 0.2126
      + root.previewBackground.g * 0.7152
      + root.previewBackground.b * 0.0722 > 0.55
  }

  Rectangle {
    id: previewStage

    objectName: "hudPreviewStage"
    anchors.fill: parent
    radius: 12
    clip: true
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: root.previewStageTopColor
      }
      GradientStop {
        position: 1.0
        color: root.previewStageBottomColor
      }
    }

    Item {
      id: previewViewport

      objectName: "hudPreviewViewport"
      x: 0
      y: root.previewAnnotationHeight
      width: parent.width
      height: Math.max(1, parent.height - y)
      clip: true

      Rectangle {
        id: previewCard

        objectName: "hudPreviewCard"
        visible: root.previewCardVisible
        width: Math.min(parent.width * 0.82, 430, Math.max(1, (parent.width - root.previewMargin * 2) / root.previewScale))
        height: Math.min(root.previewNaturalCardHeight, 330, Math.max(1, (parent.height - root.previewMargin * 2) / root.previewScale))
        x: root.cardX(width)
        y: root.cardY(height)
        color: Qt.alpha(root.previewBackground, root.previewOpacity)
        opacity: 1.0
        scale: root.previewScale
        radius: 12
        border.color: root.previewBorder
        border.width: 1
        clip: true

        Text {
        id: heading

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        height: 26
        text: root.previewHeadingText
        color: root.previewForeground
        font.family: root.fontFamily
        font.pixelSize: 16
        font.bold: true
        elide: Text.ElideRight
      }

        ListView {
        id: previewList

        objectName: "hudPreviewList"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: heading.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 8
        anchors.bottomMargin: 12
        model: root.visibleBindings
        spacing: 2
        clip: true
        interactive: false

        delegate: Item {
          required property var modelData

          width: ListView.view.width
          height: root.previewRowHeight

          Rectangle {
            id: keyChip

            objectName: "hudPreviewKeyChip-" + String(modelData.id || "")
            width: Math.max(0, Math.min(94, parent.width * 0.48))
            height: root.previewTextHeight
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: root.previewChipBackground
            border.color: root.previewChipBorder
            border.width: 1
            radius: 5

            Text {
              anchors.fill: parent
              anchors.margins: 4
              text: String(modelData.key || "")
              color: root.previewForeground
              font.family: root.fontFamily
              font.pixelSize: 10
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              wrapMode: Text.WrapAnywhere
              maximumLineCount: 2
              elide: Text.ElideRight
            }
          }

          Image {
            id: presentationIcon

            objectName: "hudPreviewPresentationIcon-"
              + String(modelData.id || "")
            anchors.left: parent.left
            anchors.leftMargin: keyChip.width + 8
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            sourceSize.width: 22
            sourceSize.height: 22
            source: root.presentationIconSource(modelData)
            visible: String(source || "") !== ""
            fillMode: Image.PreserveAspectFit
            smooth: true

            Text {
              objectName: "hudPreviewPresentationIconFallback-"
                + String(modelData.id || "")
              anchors.centerIn: parent
              visible: presentationIcon.status === Image.Error
              text: VisibilityModel.fallbackIconGlyph(
                String(modelData.displayKind || "action"))
              color: VisibilityModel.typeAccent(
                String(modelData.displayKind || "action"),
                root.surfaceIsLight(), root.previewAccent)
              font.family: root.fontFamily
              font.pixelSize: 11
              font.bold: true
            }
          }

          Rectangle {
            id: typeBadge

            readonly property string displayKind: String(
              modelData && modelData.displayKind || "action")
            readonly property color typeAccent: VisibilityModel.typeAccent(
              displayKind, root.surfaceIsLight(), root.previewAccent)
            objectName: "hudPreviewTypeBadge-" + String(modelData.id || "")
            visible: parent.width >= 180
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? typeBadgeLabel.implicitWidth + 14 : 0
            height: 22
            radius: height / 2
            color: Qt.rgba(typeAccent.r, typeAccent.g, typeAccent.b, 0.16)
            border.width: 1
            border.color: Qt.rgba(
              typeAccent.r, typeAccent.g, typeAccent.b, 0.42)

            Text {
              id: typeBadgeLabel

              objectName: "hudPreviewTypeBadgeLabel-"
                + String(modelData.id || "")
              anchors.centerIn: parent
              text: I18n.text(root.language,
                VisibilityModel.typeBadgeKey(typeBadge.displayKind), {})
              color: typeBadge.typeAccent
              font.family: root.fontFamily
              font.pixelSize: 9
              font.bold: true
            }
          }

          Text {
            id: descriptionText

            objectName: "hudPreviewDescription-" + String(modelData.id || "")
            anchors.left: parent.left
            anchors.leftMargin: keyChip.width + 8
              + (presentationIcon.visible ? presentationIcon.width + 6 : 0)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, (typeBadge.visible ? typeBadge.x - 6
              : parent.width) - x)
            height: root.previewTextHeight
            text: String(modelData.description || "")
            color: root.previewForeground
            font.family: root.fontFamily
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
        }

        Text {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 8
          anchors.rightMargin: 8
          visible: previewList.count === 0
          text: I18n.text(root.language, "hud.emptyGroup", {})
          color: Qt.alpha(root.previewForeground, 0.65)
          font.family: root.fontFamily
          font.pixelSize: 12
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          maximumLineCount: 2
          elide: Text.ElideRight
        }
        }
      }
    }

    Rectangle {
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: 6
      anchors.rightMargin: 10
      width: opacityLabel.implicitWidth + 18
      height: 26
      color: "#cc111720"
      border.color: "#55ffffff"
      border.width: 1
      radius: 13
      z: 2

      Text {
        id: opacityLabel

        objectName: "hudPreviewOpacityLabel"
        anchors.centerIn: parent
        text: root.previewOpacityText
        color: "#f2f2f2"
        font.family: root.fontFamily
        font.pixelSize: 11
        font.bold: true
      }
    }
  }
}
