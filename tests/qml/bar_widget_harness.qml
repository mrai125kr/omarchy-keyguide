import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: testRoot

  property var widget: null
  property var manifest: null
  property string pluginRoot: Quickshell.env("KEYGUIDE_TEST_PLUGIN_ROOT")

  function fail(message) {
    console.error("KEYGUIDE_BAR_WIDGET_TEST_FAIL: " + message)
    Qt.quit()
  }

  function findNamed(object, name, depth) {
    if (!object || depth > 16)
      return null
    if (String(object.objectName || "") === name)
      return object
    const children = ("children" in object && object.children) ? object.children : []
    for (let index = 0; index < children.length; index += 1) {
      const found = findNamed(children[index], name, depth + 1)
      if (found)
        return found
    }
    const data = ("data" in object && object.data) ? object.data : []
    for (let index = 0; index < data.length; index += 1) {
      if (children.indexOf(data[index]) !== -1)
        continue
      const found = findNamed(data[index], name, depth + 1)
      if (found)
        return found
    }
    if ("contentItem" in object && object.contentItem && object.contentItem !== object)
      return findNamed(object.contentItem, name, depth + 1)
    return null
  }

  function exerciseWidget() {
    const component = Qt.createComponent(
      "file://" + testRoot.pluginRoot + "/" + testRoot.manifest.entryPoints.barWidget,
      Component.PreferSynchronous
    )
    if (component.status !== Component.Ready) {
      testRoot.fail("BarWidget failed to load: " + component.errorString())
      return
    }
    testRoot.widget = component.createObject(widgetHost, {
      bar: fakeBar,
      settings: ({}),
      keyguideIconSource: "file://" + testRoot.pluginRoot.split("/.config/omarchy/plugins/")[0]
        + "/.local/share/icons/hicolor/scalable/apps/omarchy-keyguide.svg"
    })
    if (!testRoot.widget) {
      testRoot.fail("BarWidget createObject returned null")
      return
    }

    const icon = testRoot.findNamed(testRoot.widget, "keyguideBarButton", 0)
    const toggle = testRoot.findNamed(testRoot.widget, "keyguideEnabledToggle", 0)
    const slider = testRoot.findNamed(testRoot.widget, "keyguideOpacitySlider", 0)
    const settingsButton = testRoot.findNamed(testRoot.widget, "keyguideSettingsButton", 0)
    const iconImage = testRoot.findNamed(testRoot.widget, "keyguideBarIconImage", 0)
    const iconFallback = testRoot.findNamed(testRoot.widget, "keyguideBarIconFallback", 0)
    if (!icon || !toggle || !slider || !settingsButton || !iconImage || !iconFallback) {
      testRoot.fail("compact controls were not all discoverable: icon=" + !!icon
        + " image=" + !!iconImage + " fallback=" + !!iconFallback
        + " toggle=" + !!toggle + " slider=" + !!slider + " settings=" + !!settingsButton)
      return
    }
    if (iconImage.status !== Image.Ready || iconFallback.visible) {
      testRoot.fail("installed Keyguide icon did not render from its owned asset")
      return
    }

    const activeImageOpacity = iconImage.opacity
    const disabledSettings = JSON.parse(JSON.stringify(fakeService.settings))
    disabledSettings.enabled = false
    fakeService.settings = disabledSettings
    if (testRoot.widget.active !== false) {
      testRoot.fail("direct disabled setting did not update widget active state")
      return
    }
    if (iconImage.opacity === activeImageOpacity) {
      testRoot.fail("bar image icon opacity did not reflect disabled state")
      return
    }

    testRoot.widget.keyguideIconSource = ""
    if (iconImage.status === Image.Ready || !iconFallback.visible) {
      testRoot.fail("bar glyph fallback stayed hidden without an asset")
      return
    }
    const disabledFallbackColor = String(iconFallback.color)
    const disabledFallbackOpacity = iconFallback.opacity
    const enabledSettings = JSON.parse(JSON.stringify(fakeService.settings))
    enabledSettings.enabled = true
    fakeService.settings = enabledSettings
    if (testRoot.widget.active !== true) {
      testRoot.fail("direct enabled setting did not update widget active state")
      return
    }
    if (iconFallback.opacity === disabledFallbackOpacity
        && String(iconFallback.color) === disabledFallbackColor) {
      testRoot.fail("bar fallback icon rendering did not reflect active state")
      return
    }

    icon.triggerPress(Qt.LeftButton)
    if (testRoot.widget.opened !== true) {
      testRoot.fail("clicking the bar icon did not open the panel")
      return
    }
    toggle.toggled()
    slider.released(0.55)
    settingsButton.clicked()

    if (fakeService.patches.length !== 2) {
      testRoot.fail("expected two settings patches, got " + fakeService.patches.length)
      return
    }
    if (fakeService.patches[0].enabled !== false) {
      testRoot.fail("enabled patch was not false")
      return
    }
    if (Math.abs(fakeService.patches[1].opacity - 0.55) > 0.0001) {
      testRoot.fail("opacity patch was not 0.55")
      return
    }
    if (fakeShell.summonedId !== "mrai.keyguide") {
      testRoot.fail("Settings action summoned the wrong plugin")
      return
    }
    if (testRoot.widget.active !== false) {
      testRoot.fail("bar icon stayed active after disabling Keyguide")
      return
    }

    fakeService.settingsSaveActive = true
    fakeService.settingsSaveError = "write failed"
    const status = testRoot.findNamed(testRoot.widget, "keyguideStatusText", 0)
    if (toggle.enabled || slider.enabled || settingsButton.enabled) {
      testRoot.fail("compact controls stayed enabled during a settings save")
      return
    }
    if (!status || !status.visible || String(status.text).indexOf("write failed") === -1) {
      testRoot.fail("settings save error was not rendered in the compact panel")
      return
    }
    fakeService.settingsSaveError = ""
    fakeService.lastError = "observer unavailable"
    if (String(status.text).indexOf("observer unavailable") === -1) {
      testRoot.fail("service lastError was not rendered in the compact panel")
      return
    }

    fakeService.settingsSaveActive = false
    fakeService.settingsSaveError = ""
    fakeService.lastError = ""
    fakeShell.summonedId = ""
    const keyCatcher = testRoot.findNamed(testRoot.widget, "keyguidePanelKeyCatcher", 0)
    const opacityCursor = testRoot.findNamed(testRoot.widget, "keyguideOpacityCursor", 0)
    if (!keyCatcher || !opacityCursor) {
      testRoot.fail("keyboard panel cursor controls were not discoverable")
      return
    }
    keyCatcher.moveRequested(0, 1)
    if (!toggle.hasCursor) {
      testRoot.fail("first keyboard move did not select the enabled toggle")
      return
    }
    keyCatcher.activateRequested()
    keyCatcher.moveRequested(0, 1)
    if (!opacityCursor.hasCursor) {
      testRoot.fail("keyboard move did not select the opacity slider")
      return
    }
    keyCatcher.moveRequested(1, 0)
    keyCatcher.moveRequested(0, 1)
    if (!settingsButton.hasCursor) {
      testRoot.fail("keyboard move did not select the Settings action")
      return
    }
    keyCatcher.activateRequested()
    keyCatcher.tabRequested(-1)
    if (fakeService.patches.length !== 4
        || fakeService.patches[2].enabled !== true
        || Math.abs(fakeService.patches[3].opacity - 0.60) > 0.0001) {
      testRoot.fail("keyboard toggle or slider adjustment routed the wrong patch")
      return
    }
    if (fakeShell.summonedId !== "mrai.keyguide") {
      testRoot.fail("keyboard Settings activation did not summon the overlay")
      return
    }
    if (fakeBar.switchCalls !== 1 || fakeBar.lastSwitchDirection !== -1) {
      testRoot.fail("Tab did not delegate panel switching to the bar")
      return
    }

    testRoot.widget.close()
    console.log("KEYGUIDE_BAR_WIDGET_TEST_PASS")
    Qt.quit()
  }

  QtObject {
    id: fakeService

    property var settings: ({
      version: 1,
      enabled: true,
      position: "center",
      scale: 1.0,
      opacity: 0.94,
      groups: ["SUPER"],
      hiddenBindingIds: [],
      followTheme: true
    })
    property var patches: []
    property bool settingsSaveActive: false
    property string settingsSaveError: ""
    property string lastError: ""

    function patchSettings(patch) {
      const recorded = JSON.parse(JSON.stringify(patch))
      const nextPatches = patches.slice()
      nextPatches.push(recorded)
      patches = nextPatches
      const nextSettings = JSON.parse(JSON.stringify(settings))
      for (const key in patch)
        nextSettings[key] = patch[key]
      settings = nextSettings
      return true
    }
  }

  QtObject {
    id: fakeShell

    property string summonedId: ""

    function serviceFor(pluginId) {
      return pluginId === "mrai.keyguide" ? fakeService : null
    }

    function summon(pluginId) {
      summonedId = pluginId
      return true
    }
  }

  QtObject {
    id: fakeBar

    property var shell: fakeShell
    property bool vertical: false
    property int barSize: 36
    property string position: "top"
    property color barForeground: "#f2f2f2"
    property color foreground: "#f2f2f2"
    property color background: "#151515"
    property color urgent: "#ff6666"
    property string fontFamily: "sans-serif"
    property bool foregroundAnimationEnabled: false
    property var activePopout: null
    property var clickTargets: []
    property int switchCalls: 0
    property int lastSwitchDirection: 0

    function hideTooltip(target) {}
    function showTooltip(target, text) {}
    function registerClickTarget(target) {}
    function unregisterClickTarget(target) {}
    function requestPopout(target) { activePopout = target }
    function releasePopout(target) { if (activePopout === target) activePopout = null }
    function switchPanelFrom(owner, direction) {
      switchCalls += 1
      lastSwitchDirection = direction
      return true
    }
  }

  PanelWindow {
    id: barWindow
    visible: true
    implicitWidth: 320
    implicitHeight: 48
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Item {
      id: widgetHost
      width: 48
      height: 48
    }
  }

  FileView {
    id: manifestFile
    path: testRoot.pluginRoot + "/manifest.json"
    printErrors: false

    onLoaded: {
      try {
        testRoot.manifest = JSON.parse(text())
      } catch (error) {
        testRoot.fail("copied manifest is invalid: " + error)
        return
      }
      if (testRoot.manifest.entryPoints.barWidget !== "BarWidget.qml"
          || testRoot.manifest.barWidget.allowMultiple !== false) {
        testRoot.fail("copied manifest does not declare a single bar widget")
        return
      }
      Qt.callLater(testRoot.exerciseWidget)
    }

    onLoadFailed: function(error) {
      testRoot.fail("copied manifest did not load: " + error)
    }
  }
}
