import QtQuick
import Quickshell

ShellRoot {
  id: testRoot

  property int phase: 0
  property int phaseTicks: 0
  property var service: null
  property var hud: null
  readonly property var boundedProcessPrefix: [
    "/usr/bin/python3",
    String(Qt.resolvedUrl("src/backend/keyguide_backend/bounded_process.py")).replace("file://", "")
  ]

  Item {
    id: serviceHost
  }

  QtObject {
    id: lockService
    property bool locked: false
  }

  QtObject {
    id: shellStub

    function serviceFor(pluginId) {
      return pluginId === "omarchy.lock" ? lockService : null
    }
  }

  function fail(message) {
    lockService.locked = true
    console.error("KEYGUIDE_HUD_TEST_FAIL: " + message)
    Qt.quit()
  }

  function loadedHud() {
    if (!service)
      return null
    const children = service.children || []
    for (let index = 0; index < children.length; index += 1) {
      const child = children[index]
      if (child && "item" in child && child.item && "hudVisible" in child.item && "bindings" in child.item) {
        return child.item
      }
    }
    return null
  }

  function findBorderSurface(object, depth) {
    if (!object || depth > 5)
      return null
    if ("padding" in object && "contentLeftInset" in object && "borderLeft" in object) {
      return object
    }
    const children = ("children" in object && object.children) ? object.children : []
    for (let index = 0; index < children.length; index += 1) {
      const result = findBorderSurface(children[index], depth + 1)
      if (result)
        return result
    }
    if ("contentItem" in object && object.contentItem && object.contentItem !== object) {
      return findBorderSurface(object.contentItem, depth + 1)
    }
    return null
  }

  function findKeyChip(object, depth) {
    if (!object || depth > 12)
      return null
    if (!("padding" in object) && "border" in object && object.border && Number(object.border.width) > 0 && object.width < 300 && object.height < 100) {
      return object
    }
    const children = ("children" in object && object.children) ? object.children : []
    for (let index = 0; index < children.length; index += 1) {
      const result = findKeyChip(children[index], depth + 1)
      if (result)
        return result
    }
    if ("contentItem" in object && object.contentItem && object.contentItem !== object)
      return findKeyChip(object.contentItem, depth + 1)
    return null
  }

  function bindingDescriptions(object, descriptions, result, depth) {
    if (!object || depth > 12)
      return
    if ("text" in object && descriptions.indexOf(String(object.text)) !== -1)
      result.push(String(object.text))
    const children = ("children" in object && object.children) ? object.children : []
    for (let index = 0; index < children.length; index += 1)
      bindingDescriptions(children[index], descriptions, result, depth + 1)
    if ("contentItem" in object && object.contentItem && object.contentItem !== object)
      bindingDescriptions(object.contentItem, descriptions, result, depth + 1)
  }

  function findNamed(object, name, depth) {
    if (!object || depth > 12)
      return null
    if (String(object.objectName || "") === name)
      return object
    const children = ("children" in object && object.children) ? object.children : []
    for (let index = 0; index < children.length; index += 1) {
      const result = findNamed(children[index], name, depth + 1)
      if (result)
        return result
    }
    if ("contentItem" in object && object.contentItem && object.contentItem !== object)
      return findNamed(object.contentItem, name, depth + 1)
    return null
  }

  function colorNear(actual, red, green, blue, alpha) {
    if (!actual || actual.r === undefined)
      return false
    const epsilon = 0.002
    return Math.abs(actual.r - red) <= epsilon && Math.abs(actual.g - green) <= epsilon && Math.abs(actual.b - blue) <= epsilon && Math.abs(actual.a - alpha) <= epsilon
  }

  Component.onCompleted: {
    const component = Qt.createComponent(Qt.resolvedUrl("src/plugin/Service.qml"), Component.PreferSynchronous)
    if (component.status !== Component.Ready) {
      fail("Service failed to load: " + component.errorString())
      return
    }
    service = component.createObject(serviceHost, {
      shell: shellStub,
      boundedProcessCommandPrefix: boundedProcessPrefix,
      settingsPath: "",
      observerCommand: ["/usr/bin/python3", "-c", "import time; print('{\"super\":true,\"ctrl\":true,\"shift\":false,\"alt\":false,\"actionPressed\":false,\"wheelPulse\":0}', flush=True); time.sleep(30)"],
      bindingsCommand: ["/usr/bin/printf", "[{\"id\":\"terminal\",\"presentation_id\":\"terminal\",\"modifiers\":[\"SUPER\",\"CTRL\"],\"key\":\"RETURN\",\"description\":\"Terminal\",\"dispatcher\":\"exec\",\"argument\":\"terminal\",\"mouse\":false,\"editable\":true,\"action_kind\":\"exec\",\"action_argument\":\"terminal\",\"edit_reason\":\"\"},{\"id\":\"browser\",\"presentation_id\":\"browser\",\"modifiers\":[\"SUPER\"],\"key\":\"B\",\"description\":\"Browser\",\"dispatcher\":\"exec\",\"argument\":\"browser\",\"mouse\":false,\"editable\":true,\"action_kind\":\"exec\",\"action_argument\":\"browser\",\"edit_reason\":\"\"}]"],
      settingsCommand: ["/usr/bin/printf", "{\"version\":2,\"enabled\":true,\"position\":\"center\",\"scale\":1.0,\"opacity\":0.94,\"groups\":[\"SUPER+CTRL\"],\"hiddenBindingIds\":[],\"followTheme\":false,\"language\":\"en\"}"]
    })
    if (!service)
      fail("Service createObject returned null")
  }

  Timer {
    interval: 25
    repeat: true
    running: true

    onTriggered: {
      testRoot.phaseTicks += 1
      if (testRoot.phaseTicks > 100) {
        testRoot.fail("phase " + testRoot.phase + " timed out waiting for a loaded HUD")
        return
      }
      if (!testRoot.service)
        return
      if (!testRoot.hud)
        testRoot.hud = testRoot.loadedHud()

      if (testRoot.phase === 0 && testRoot.hud && testRoot.service.hudVisible) {
        if (testRoot.hud.hudVisible !== true) {
          testRoot.fail("Service visibility did not propagate to Hud.qml")
          return
        }
        if (testRoot.hud.modifiers.length !== 2 || testRoot.hud.modifiers[0] !== "SUPER" || testRoot.hud.modifiers[1] !== "CTRL") {
          testRoot.fail("Service modifiers did not propagate to Hud.qml")
          return
        }
        if (testRoot.hud.bindings.length !== 1 || testRoot.hud.bindings[0].id !== "terminal") {
          testRoot.fail("filtered Service bindings did not propagate to Hud.qml")
          return
        }
        testRoot.service.settings = Object.assign(
          {}, testRoot.service.settings, { language: "zh_CN" })
        const heading = testRoot.findNamed(testRoot.hud, "hudHeading", 0)
        if (!heading || String(heading.text) !== "Super + Ctrl 快捷键") {
          testRoot.fail("live HUD heading did not use Simplified Chinese")
          return
        }
        if (!("language" in testRoot.hud) || testRoot.hud.language !== "zh_CN") {
          testRoot.fail("Service language did not propagate to Hud.qml")
          return
        }
        const card = testRoot.findBorderSurface(testRoot.hud, 0)
        if (!card) {
          testRoot.fail("could not inspect the live HUD card")
          return
        }
        if (card.padding !== testRoot.hud.cardPadding) {
          testRoot.fail("HUD card padding is not included in its content insets")
          return
        }
        if (!testRoot.colorNear(card.color, 21 / 255, 21 / 255, 21 / 255, 0.94)) {
          testRoot.fail("fixed palette did not reach the live HUD card background")
          return
        }
        if (!testRoot.colorNear(card.borderSpec.color, 242 / 255, 242 / 255, 242 / 255, 0.22)) {
          testRoot.fail("fixed palette did not reach the live HUD card border")
          return
        }
        const chip = testRoot.findKeyChip(card, 0)
        if (!chip) {
          testRoot.fail("could not inspect the live HUD key chip")
          return
        }
        if (!testRoot.colorNear(chip.color, 242 / 255, 242 / 255, 242 / 255, 0.1)) {
          testRoot.fail("fixed palette did not reach the live HUD key-chip fill")
          return
        }
        if (!testRoot.colorNear(chip.border.color, 242 / 255, 242 / 255, 242 / 255, 0.28)) {
          testRoot.fail("fixed palette did not reach the live HUD key-chip border")
          return
        }
        testRoot.service.allBindings = [
          {id: "enter", modifiers: ["SUPER", "CTRL"], key: "ENTER", description: "Visual enter", mouse: false},
          {id: "space", modifiers: ["SUPER", "CTRL"], key: "SPACE", description: "Visual space", mouse: false},
          {id: "comma", modifiers: ["SUPER", "CTRL"], key: "COMMA", description: "Visual comma", mouse: false},
          {id: "left", modifiers: ["SUPER", "CTRL"], key: "LEFT", description: "Visual left", mouse: false},
          {id: "two", modifiers: ["SUPER", "CTRL"], key: "2", description: "Visual two", mouse: false},
          {id: "alpha", modifiers: ["SUPER", "CTRL"], key: "A", description: "Visual alpha", mouse: false},
          {id: "bravo", modifiers: ["SUPER", "CTRL"], key: "B", description: "Visual bravo", mouse: false},
          {id: "mouse", modifiers: ["SUPER", "CTRL"], key: "MOUSE_RIGHT", description: "Visual mouse", mouse: true}
        ]
        testRoot.phase = 1
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 1 && testRoot.hud.renderedRowCount === 8) {
        const expectedDescriptions = [
          "Visual enter", "Visual space", "Visual comma", "Visual left",
          "Visual two", "Visual alpha", "Visual bravo", "Visual mouse"
        ]
        const renderedDescriptions = []
        testRoot.bindingDescriptions(
          testRoot.hud,
          expectedDescriptions,
          renderedDescriptions,
          0
        )
        if (renderedDescriptions.join("|") !== expectedDescriptions.join("|")) {
          testRoot.fail(
            "Hud.qml delegate order was " + renderedDescriptions.join("|")
              + ", expected " + expectedDescriptions.join("|")
          )
          return
        }
        const many = []
        for (let index = 0; index < 42; index += 1)
          many.push({id: "many-" + index, modifiers: ["SUPER", "CTRL"], key: "K" + index, description: "Action " + index, mouse: false})
        testRoot.service.allBindings = many
        testRoot.service.settings = Object.assign({}, testRoot.service.settings, {scale: 0.75})
        testRoot.phase = 2
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 2 && testRoot.hud.renderedRowCount === 42) {
        if (testRoot.hud.cardLeft < 0 || testRoot.hud.cardTop < 0
            || testRoot.hud.cardRight > testRoot.hud.width
            || testRoot.hud.cardBottom > testRoot.hud.height) {
          testRoot.fail("42-row minimum-scale HUD escaped the rendered screen")
          return
        }
        lockService.locked = true
        testRoot.phase = 3
        testRoot.phaseTicks = 0
        return
      }

      if (testRoot.phase === 3 && !testRoot.service.observerRunning) {
        if (testRoot.service.hudVisible || testRoot.hud.hudVisible) {
          testRoot.fail("locked visibility did not propagate to Hud.qml")
          return
        }
        console.log("KEYGUIDE_HUD_TEST_PASS")
        Qt.quit()
      }
    }
  }
}
