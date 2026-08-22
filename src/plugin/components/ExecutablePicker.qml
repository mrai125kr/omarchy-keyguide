pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Qt.labs.folderlistmodel

FocusScope {
  id: root

  property string homePath: "/"
  property string currentFolderPath: "/"
  property string selectedPath: ""
  property bool showHidden: false
  property bool browsingActive: false
  property color foreground: "#f2f2f2"
  property color mutedForeground: "#a7a7a7"
  property color background: "#151821"
  property color surface: "#1d2230"
  property color accent: "#8fbfff"
  property color errorForeground: "#ff8a8a"
  property string errorText: ""
  property string fontFamily: "sans-serif"
  readonly property bool modelShowsHidden: folderModel.showHidden

  signal selectionAccepted(string path)
  signal canceled()
  signal showHiddenRequested(bool visible)

  function localPath(fileUrl) {
    const value = String(fileUrl || "")
    if (value.indexOf("file://") !== 0)
      return value
    try {
      return decodeURIComponent(value.slice(7))
    } catch (error) {
      return ""
    }
  }

  function fileUrl(path) {
    const parts = String(path || "/").split("/")
    for (let index = 0; index < parts.length; index += 1)
      parts[index] = encodeURIComponent(parts[index])
    return "file://" + parts.join("/")
  }

  function parentPath(path) {
    const value = String(path || "/").replace(/\/+$/, "") || "/"
    if (value === "/")
      return "/"
    const split = value.lastIndexOf("/")
    return split <= 0 ? "/" : value.slice(0, split)
  }

  function navigateTo(path) {
    let value = root.localPath(path)
    if (!value || value.charAt(0) !== "/")
      return false
    value = value.replace(/\/+$/, "") || "/"
    root.currentFolderPath = value
    folderPathField.text = value
    return true
  }

  function openAt(executablePath, requestedHome) {
    root.homePath = String(requestedHome || "/") || "/"
    root.selectedPath = String(executablePath || "")
    const initialFolder = root.selectedPath.charAt(0) === "/"
      ? root.parentPath(root.selectedPath) : root.homePath
    root.navigateTo(initialFolder)
    selectedPathField.text = root.selectedPath
    folderPathField.forceActiveFocus()
    folderPathField.selectAll()
  }

  function goHome() {
    return root.navigateTo(root.homePath)
  }

  function goUp() {
    return root.navigateTo(root.parentPath(root.currentFolderPath))
  }

  function acceptSelection() {
    const path = String(root.selectedPath || "")
    if (!path.trim())
      return false
    root.selectionAccepted(path)
    return true
  }

  function handleKeyPress(key, modifiers) {
    if (key !== Qt.Key_Escape || modifiers !== Qt.NoModifier)
      return false
    root.canceled()
    return true
  }

  Keys.onPressed: function(event) {
    event.accepted = root.handleKeyPress(event.key, event.modifiers)
  }

  implicitWidth: 760
  implicitHeight: 580

  FolderListModel {
    id: folderModel
    folder: root.browsingActive ? root.fileUrl(root.currentFolderPath) : ""
    showDirs: true
    showFiles: true
    showDirsFirst: true
    showDotAndDotDot: false
    showHidden: root.showHidden
    sortField: FolderListModel.Name
  }

  Column {
    anchors.fill: parent
    spacing: 12

    Text {
      text: "Choose executable"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: 18
      font.bold: true
    }

    Row {
      width: parent.width
      spacing: 8

      QQC.Button {
        id: homeButton

        objectName: "shortcutExecutableHomeButton"
        text: "Home"
        onClicked: root.goHome()
      }

      QQC.Button {
        id: upButton

        objectName: "shortcutExecutableUpButton"
        text: "Up"
        onClicked: root.goUp()
      }

      QQC.TextField {
        id: folderPathField
        objectName: "shortcutExecutableFolderPath"
        width: Math.max(0, parent.width - homeButton.width - upButton.width
          - goButton.width - parent.spacing * 3)
        placeholderText: "Folder address"
        text: root.currentFolderPath
        selectByMouse: true
        onAccepted: root.navigateTo(text)
      }

      QQC.Button {
        id: goButton

        objectName: "shortcutExecutableGoButton"
        text: "Go"
        onClicked: root.navigateTo(folderPathField.text)
      }
    }

    Rectangle {
      width: parent.width
      height: Math.max(220, parent.height - 196
        - (pickerError.visible ? pickerError.implicitHeight + 12 : 0))
      color: root.surface
      border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
      border.width: 1
      radius: 8
      clip: true

      ListView {
        id: fileList
        objectName: "shortcutExecutableFileList"
        anchors.fill: parent
        anchors.margins: 6
        model: folderModel
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1

        delegate: Rectangle {
          id: fileRow

          required property int index
          required property string fileName
          required property url fileUrl
          required property bool fileIsDir

          width: fileList.width
          height: 38
          color: fileMouse.containsMouse || fileList.currentIndex === index
            ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.14)
            : "transparent"
          radius: 6

          Text {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: (fileRow.fileIsDir ? "▸  " : "    ") + fileRow.fileName
            color: fileRow.fileIsDir ? root.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: 13
            elide: Text.ElideMiddle
          }

          MouseArea {
            id: fileMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              fileList.currentIndex = fileRow.index
              if (fileRow.fileIsDir) {
                root.navigateTo(root.localPath(fileRow.fileUrl))
              } else {
                root.selectedPath = root.localPath(fileRow.fileUrl)
                selectedPathField.text = root.selectedPath
              }
            }
            onDoubleClicked: {
              if (!fileRow.fileIsDir) {
                root.selectedPath = root.localPath(fileRow.fileUrl)
                selectedPathField.text = root.selectedPath
                root.acceptSelection()
              }
            }
          }
        }

        QQC.ScrollBar.vertical: QQC.ScrollBar {}

        Text {
          anchors.centerIn: parent
          visible: folderModel.status === FolderListModel.Ready
            && folderModel.count === 0
          text: "This folder is empty"
          color: root.mutedForeground
          font.family: root.fontFamily
          font.pixelSize: 13
        }
      }
    }

    QQC.CheckBox {
      id: hiddenToggle
      objectName: "shortcutExecutableShowHidden"
      text: "Show hidden files and folders"
      checked: root.showHidden
      onToggled: root.showHiddenRequested(checked)
    }

    Text {
      id: pickerError

      objectName: "shortcutExecutableError"
      width: parent.width
      visible: root.errorText !== ""
      text: root.errorText
      color: root.errorForeground
      font.family: root.fontFamily
      font.pixelSize: 12
      wrapMode: Text.WordWrap
    }

    Row {
      width: parent.width
      spacing: 8

      QQC.TextField {
        id: selectedPathField
        objectName: "shortcutExecutableSelectedPath"
        width: parent.width - chooseButton.width - cancelButton.width - parent.spacing * 2
        placeholderText: "Executable path"
        text: root.selectedPath
        selectByMouse: true
        onTextEdited: root.selectedPath = text
        onAccepted: root.acceptSelection()
      }

      QQC.Button {
        id: chooseButton
        objectName: "shortcutExecutableSelectButton"
        text: "Choose"
        enabled: String(root.selectedPath || "").trim() !== ""
        onClicked: root.acceptSelection()
      }

      QQC.Button {
        id: cancelButton
        objectName: "shortcutExecutableCancelButton"
        text: "Cancel"
        onClicked: root.canceled()
      }
    }
  }
}
