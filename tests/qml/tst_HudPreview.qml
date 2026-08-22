import QtQuick
import QtTest
import "../../src/plugin/components" as Components

TestCase {
  name: "HudPreview"

  Component {
    id: previewComponent

    Components.HudPreview {
      width: 640
      height: 398
    }
  }

  function paintedCardBounds(preview) {
    const card = previewCard(preview)
    const topLeft = card.mapToItem(preview, 0, 0)
    const bottomRight = card.mapToItem(preview, card.width, card.height)
    return {
      left: topLeft.x,
      top: topLeft.y,
      right: bottomRight.x,
      bottom: bottomRight.y
    }
  }

  function previewCard(preview) {
    const card = findNamed(preview, "hudPreviewCard", 0)
    verify(card !== null)
    return card
  }

  function itemBounds(item, target) {
    const topLeft = item.mapToItem(target, 0, 0)
    const bottomRight = item.mapToItem(target, item.width, item.height)
    return {
      left: Math.min(topLeft.x, bottomRight.x),
      top: Math.min(topLeft.y, bottomRight.y),
      right: Math.max(topLeft.x, bottomRight.x),
      bottom: Math.max(topLeft.y, bottomRight.y)
    }
  }

  function intersects(first, second) {
    return first.left < second.right && first.right > second.left
      && first.top < second.bottom && first.bottom > second.top
  }

  function findTextItem(object, expectedText, depth) {
    if (!object || depth > 20)
      return null
    if (object.text !== undefined && String(object.text) === expectedText)
      return object
    const children = object.children || []
    for (let index = 0; index < children.length; index += 1) {
      const found = findTextItem(children[index], expectedText, depth + 1)
      if (found)
        return found
    }
    return null
  }

  function findNamed(object, name, depth) {
    if (!object || depth > 20)
      return null
    if (String(object.objectName || "") === name)
      return object
    const children = object.children || []
    for (let index = 0; index < children.length; index += 1) {
      const found = findNamed(children[index], name, depth + 1)
      if (found)
        return found
    }
    return null
  }

  function paintedTextBounds(textItem, target) {
    let paintedX = 0
    if (textItem.horizontalAlignment === Text.AlignHCenter)
      paintedX = (textItem.width - textItem.paintedWidth) / 2
    else if (textItem.horizontalAlignment === Text.AlignRight)
      paintedX = textItem.width - textItem.paintedWidth

    let paintedY = 0
    if (textItem.verticalAlignment === Text.AlignVCenter)
      paintedY = (textItem.height - textItem.paintedHeight) / 2
    else if (textItem.verticalAlignment === Text.AlignBottom)
      paintedY = textItem.height - textItem.paintedHeight

    const topLeft = textItem.mapToItem(target, paintedX, paintedY)
    const bottomRight = textItem.mapToItem(
      target,
      paintedX + textItem.paintedWidth,
      paintedY + textItem.paintedHeight
    )
    return {
      left: Math.min(topLeft.x, bottomRight.x),
      top: Math.min(topLeft.y, bottomRight.y),
      right: Math.max(topLeft.x, bottomRight.x),
      bottom: Math.max(topLeft.y, bottomRight.y)
    }
  }

  function verifyTextInsideCard(textItem, card, position, label) {
    const bounds = paintedTextBounds(textItem, card)
    verify(bounds.left >= -0.01, position + " " + label + " paints left of the card at " + bounds.left)
    verify(bounds.top >= -0.01, position + " " + label + " paints above the card at " + bounds.top)
    verify(bounds.right <= card.width + 0.01, position + " " + label + " paints right of the card at " + bounds.right)
    verify(bounds.bottom <= card.height + 0.01, position + " " + label + " paints below the card at " + bounds.bottom)
  }

  function verifyItemInside(item, container, context, label) {
    const topLeft = item.mapToItem(container, 0, 0)
    const bottomRight = item.mapToItem(container, item.width, item.height)
    verify(topLeft.x >= -0.01, context + " " + label + " starts left of the preview list")
    verify(topLeft.y >= -0.01, context + " " + label + " starts above the preview list")
    verify(bottomRight.x <= container.width + 0.01,
           context + " " + label + " ends right of the preview list")
    verify(bottomRight.y <= container.height + 0.01,
           context + " " + label + " ends below the preview list")
  }

  function colorNear(actual, expected, tolerance) {
    if (!actual || actual.r === undefined || !expected || expected.r === undefined)
      return false
    const epsilon = tolerance === undefined ? 0.002 : tolerance
    return Math.abs(actual.r - expected.r) <= epsilon && Math.abs(actual.g - expected.g) <= epsilon && Math.abs(actual.b - expected.b) <= epsilon && Math.abs(actual.a - expected.a) <= epsilon
  }

  function test_opacity_preview_uses_pending_value() {
    const preview = createTemporaryObject(previewComponent, this, {
      settings: {
        opacity: 0.8,
        scale: 1.0,
        followTheme: true,
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    compare(preview.previewOpacity, 0.8)

    preview.settings = {
      opacity: 0.55,
      scale: 1.0,
      followTheme: true,
      hiddenBindingIds: []
    }
    compare(preview.previewOpacity, 0.55)
    compare(preview.previewCardOpacity, 1.0)
    verify(Math.abs(preview.previewCardBackground.a - 0.55) < 0.001)
    compare(preview.previewOpacityText, "Opacity 55%")
    const stage = findNamed(preview, "hudPreviewStage", 0)
    const label = findNamed(preview, "hudPreviewOpacityLabel", 0)
    verify(stage !== null)
    verify(label !== null)
    compare(label.text, "Opacity 55%")
    verify(!colorNear(preview.previewStageTopColor,
                      preview.previewStageBottomColor))
  }

  function test_hud_chrome_is_localized_in_every_language() {
    const preview = createTemporaryObject(previewComponent, this, {
      bindings: [],
      previewModifiers: ["SUPER", "CTRL"],
      settings: {
        enabled: true,
        position: "center",
        opacity: 0.55,
        scale: 1.0,
        followTheme: true,
        groups: ["SUPER+CTRL"],
        hiddenBindingIds: []
      }
    })
    verify(preview !== null)
    const expected = {
      en: ["Super + Ctrl shortcuts", "Opacity 55%", "No visible shortcuts in this group."],
      ko: ["Super + Ctrl 단축키", "투명도 55%", "이 그룹에 표시할 단축키가 없습니다."],
      ja: ["Super + Ctrl ショートカット", "不透明度 55%", "このグループに表示できるショートカットはありません。"],
      zh_CN: ["Super + Ctrl 快捷键", "不透明度 55%", "此组中没有可显示的快捷键。"],
      es: ["Atajos de Super + Ctrl", "Opacidad 55%", "No hay atajos visibles en este grupo."]
    }
    for (const language in expected) {
      preview.language = language
      wait(0)
      compare(preview.previewHeadingText, expected[language][0], language + " heading")
      compare(preview.previewOpacityText, expected[language][1], language + " opacity")
      verify(findTextItem(preview, expected[language][2], 0) !== null,
             language + " empty-group guidance")
    }
  }

  function test_every_locale_extreme_scale_position_and_group_stays_bounded() {
    const locales = ["en", "ko", "ja", "zh_CN", "es"]
    const scales = [0.75, 1.5]
    const positions = ["center", "top", "bottom", "left", "right"]
    const groups = [
      ["SUPER"], ["SUPER", "CTRL"], ["SUPER", "SHIFT"], ["SUPER", "ALT"],
      ["SUPER", "CTRL", "SHIFT"], ["SUPER", "CTRL", "ALT"],
      ["SUPER", "SHIFT", "ALT"], ["SUPER", "CTRL", "SHIFT", "ALT"]
    ]
    const preview = createTemporaryObject(previewComponent, this, {
      width: 320,
      height: 398,
      settings: {
        enabled: true,
        position: "center",
        opacity: 0.8,
        scale: 1.0,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
    })
    verify(preview !== null)
    for (let localeIndex = 0; localeIndex < locales.length; localeIndex += 1) {
      preview.language = locales[localeIndex]
      for (let groupIndex = 0; groupIndex < groups.length; groupIndex += 1) {
        const modifiers = groups[groupIndex]
        const groupName = modifiers.join("+")
        const bindings = []
        for (let row = 0; row < 42; row += 1) {
          bindings.push({
            id: locales[localeIndex] + "-" + groupIndex + "-" + row,
            modifiers: modifiers,
            key: "K" + row,
            description: "Una descripción de acceso directo deliberadamente larga para comprobar el recorte " + row
          })
        }
        preview.bindings = bindings
        preview.previewModifiers = modifiers
        for (let scaleIndex = 0; scaleIndex < scales.length; scaleIndex += 1) {
          for (let positionIndex = 0; positionIndex < positions.length; positionIndex += 1) {
            const scale = scales[scaleIndex]
            const position = positions[positionIndex]
            const context = locales[localeIndex] + " " + groupName + " " + scale + " " + position
            preview.settings = {
              enabled: true,
              position: position,
              opacity: 0.8,
              scale: scale,
              followTheme: true,
              groups: [groupName],
              hiddenBindingIds: []
            }
            wait(0)
            compare(preview.renderedRowCount, 42, context + " row count")
            const bounds = paintedCardBounds(preview)
            verify(bounds.left >= 15.99, context + " card paints left of its margin")
            verify(bounds.top >= preview.previewAnnotationHeight + 15.99,
                   context + " card paints above its margin")
            verify(bounds.right <= preview.width - 15.99,
                   context + " card paints right of its margin")
            verify(bounds.bottom <= preview.height - 15.99,
                   context + " card paints below its margin")
          }
        }
      }
    }
  }

  function test_opacity_label_never_overlaps_positioned_hud_card() {
    const preview = createTemporaryObject(previewComponent, this, {
      width: 320,
      height: 360,
      settings: {
        enabled: true,
        position: "top",
        opacity: 0.55,
        scale: 1.0,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    const label = findNamed(preview, "hudPreviewOpacityLabel", 0)
    const card = previewCard(preview)
    verify(label !== null)
    const positions = ["top", "bottom", "left", "right", "center"]
    for (let index = 0; index < positions.length; index += 1) {
      const position = positions[index]
      preview.settings = {
        enabled: true,
        position: position,
        opacity: 0.55,
        scale: 1.0,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
      wait(0)
      verify(!intersects(itemBounds(label, preview), itemBounds(card, preview)),
             position + " HUD card overlaps the opacity label")
    }
  }

  function test_scale_preview_uses_pending_value() {
    const preview = createTemporaryObject(previewComponent, this, {
      settings: {
        opacity: 0.8,
        scale: 1.25,
        followTheme: true,
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    compare(preview.previewScale, 1.25)
  }

  function test_disabled_pending_setting_hides_preview_card() {
    const preview = createTemporaryObject(previewComponent, this, {
      settings: {
        enabled: false,
        opacity: 0.8,
        scale: 1.0,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    compare(preview.previewCardVisible, false)
  }

  function test_disabled_pending_group_renders_no_preview_rows() {
    const preview = createTemporaryObject(previewComponent, this, {
      bindings: [
        {
          id: "terminal-id",
          modifiers: ["SUPER"],
          key: "RETURN",
          description: "Terminal"
        }
      ],
      previewModifiers: ["SUPER"],
      settings: {
        enabled: true,
        opacity: 0.8,
        scale: 1.0,
        followTheme: true,
        groups: ["SUPER+CTRL"],
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    compare(preview.visibleBindings.length, 0)
    compare(preview.renderedRowCount, 0)
  }

  function test_position_preview_uses_pending_value() {
    const preview = createTemporaryObject(previewComponent, this, {
      settings: {
        enabled: true,
        position: "top",
        opacity: 0.8,
        scale: 1.0,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    const topY = preview.previewCardY

    preview.settings = {
      enabled: true,
      position: "bottom",
      opacity: 0.8,
      scale: 1.0,
      followTheme: true,
      groups: ["SUPER"],
      hiddenBindingIds: []
    }
    verify(preview.previewCardY > topY)

    preview.settings = {
      enabled: true,
      position: "left",
      opacity: 0.8,
      scale: 1.0,
      followTheme: true,
      groups: ["SUPER"],
      hiddenBindingIds: []
    }
    const leftX = preview.previewCardX

    preview.settings = {
      enabled: true,
      position: "right",
      opacity: 0.8,
      scale: 1.0,
      followTheme: true,
      groups: ["SUPER"],
      hiddenBindingIds: []
    }
    verify(preview.previewCardX > leftX)
  }

  function test_maximum_scale_edge_positions_keep_painted_card_inside_preview() {
    const preview = createTemporaryObject(previewComponent, this, {
      settings: {
        enabled: true,
        position: "top",
        opacity: 0.8,
        scale: 1.5,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    const positions = ["top", "bottom", "left", "right"]
    for (let index = 0; index < positions.length; index += 1) {
      const position = positions[index]
      preview.settings = {
        enabled: true,
        position: position,
        opacity: 0.8,
        scale: 1.5,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
      const bounds = paintedCardBounds(preview)
      verify(bounds.left >= 15.99, position + " preview clips its left edge at " + bounds.left)
      verify(bounds.top >= preview.previewAnnotationHeight + 15.99,
             position + " preview clips its top edge at " + bounds.top)
      verify(bounds.right <= preview.width - 15.99, position + " preview clips its right edge at " + bounds.right)
      verify(bounds.bottom <= preview.height - 15.99, position + " preview clips its bottom edge at " + bounds.bottom)

      if (position === "top")
        verify(Math.abs(bounds.top - (preview.previewAnnotationHeight + 16)) < 0.01)
      if (position === "bottom")
        verify(Math.abs(bounds.bottom - (preview.height - 16)) < 0.01)
      if (position === "left")
        verify(Math.abs(bounds.left - 16) < 0.01)
      if (position === "right")
        verify(Math.abs(bounds.right - (preview.width - 16)) < 0.01)
    }
  }

  function test_real_long_preview_row_stays_two_line_bounded_at_every_scale_and_edge() {
    const longKey = "mouse_up"
    // Exact active binding from tests/fixtures/hyprctl-binds.txt.
    const longDescription = "Scroll active workspace backward"
    const preview = createTemporaryObject(previewComponent, this, {
      width: 320,
      bindings: [
        {
          id: "fixture-scroll-active-workspace-backward",
          modifiers: ["SUPER"],
          key: longKey,
          description: longDescription
        }
      ],
      previewModifiers: ["SUPER"],
      settings: {
        enabled: true,
        position: "top",
        opacity: 0.8,
        scale: 0.75,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    tryCompare(preview, "renderedRowCount", 1)
    const scales = [0.75, 1.0, 1.5]
    const positions = ["top", "bottom", "left", "right"]
    for (let scaleIndex = 0; scaleIndex < scales.length; scaleIndex += 1) {
      const scale = scales[scaleIndex]
      for (let positionIndex = 0; positionIndex < positions.length; positionIndex += 1) {
        const position = positions[positionIndex]
        const context = "scale " + scale + " " + position
        preview.settings = {
          enabled: true,
          position: position,
          opacity: 0.8,
          scale: scale,
          followTheme: true,
          groups: ["SUPER"],
          hiddenBindingIds: []
        }
        wait(0)

        const card = previewCard(preview)
        const cardBounds = paintedCardBounds(preview)
        const keyText = findTextItem(card, longKey, 0)
        const descriptionText = findTextItem(card, longDescription, 0)
        verify(keyText !== null, context + " key text was not rendered")
        verify(descriptionText !== null, context + " description text was not rendered")
        verify(keyText.lineCount >= 1 && keyText.lineCount <= 2,
               context + " key used " + keyText.lineCount + " lines")
        compare(descriptionText.lineCount, 2,
                context + " long description did not use its bounded second line")
        verify(cardBounds.left >= 15.99, context + " card paints left of its margin")
        verify(cardBounds.top >= preview.previewAnnotationHeight + 15.99,
               context + " card paints above its margin")
        verify(cardBounds.right <= preview.width - 15.99, context + " card paints right of its margin")
        verify(cardBounds.bottom <= preview.height - 15.99, context + " card paints below its margin")
        verifyTextInsideCard(keyText, card, context, "key")
        verifyTextInsideCard(descriptionText, card, context, "description")
      }
    }
  }

  function test_every_group_position_and_scale_keeps_long_rows_inside_the_preview_list() {
    const groups = [
      ["SUPER"], ["SUPER", "CTRL"], ["SUPER", "SHIFT"], ["SUPER", "ALT"],
      ["SUPER", "CTRL", "SHIFT"], ["SUPER", "CTRL", "ALT"],
      ["SUPER", "SHIFT", "ALT"], ["SUPER", "CTRL", "SHIFT", "ALT"]
    ]
    const bindings = groups.map(function(modifiers, index) {
      return {
        id: "long-preview-" + index,
        modifiers: modifiers,
        key: "A-VERY-LONG-KEY-" + index,
        description: "A deliberately long description that must use two lines " + index
      }
    })
    const preview = createTemporaryObject(previewComponent, this, {
      width: 120,
      // Preserve the original 200px HUD viewport plus the annotation lane.
      height: 238,
      bindings: bindings,
      previewModifiers: groups[0],
      settings: {
        enabled: true,
        position: "center",
        opacity: 0.8,
        scale: 1.0,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    const positions = ["center", "top", "bottom", "left", "right"]
    const scales = [0.75, 1.0, 1.5]
    for (let groupIndex = 0; groupIndex < groups.length; groupIndex += 1) {
      const modifiers = groups[groupIndex]
      const groupName = modifiers.join("+")
      const key = "A-VERY-LONG-KEY-" + groupIndex
      const description = "A deliberately long description that must use two lines " + groupIndex
      preview.previewModifiers = modifiers
      for (let scaleIndex = 0; scaleIndex < scales.length; scaleIndex += 1) {
        for (let positionIndex = 0; positionIndex < positions.length; positionIndex += 1) {
          const scale = scales[scaleIndex]
          const position = positions[positionIndex]
          const context = groupName + " scale " + scale + " " + position
          preview.settings = {
            enabled: true,
            position: position,
            opacity: 0.8,
            scale: scale,
            followTheme: true,
            groups: [groupName],
            hiddenBindingIds: []
          }
          wait(0)

          const card = previewCard(preview)
          const list = findNamed(card, "hudPreviewList", 0)
          const chip = findNamed(card, "hudPreviewKeyChip-long-preview-" + groupIndex, 0)
          const descriptionText = findNamed(card, "hudPreviewDescription-long-preview-" + groupIndex, 0)
          const keyText = findTextItem(chip, key, 0)
          verify(list !== null, context + " preview list was not rendered")
          verify(chip !== null, context + " key chip was not rendered")
          verify(keyText !== null, context + " key text was not rendered")
          verify(descriptionText !== null, context + " description was not rendered")
          verify(chip.width <= list.width,
                 context + " key chip exceeds the preview list")
          verify(descriptionText.x >= chip.x + chip.width,
                 context + " description does not follow the actual chip width")
          compare(descriptionText.lineCount, 2,
                  context + " long description did not use its bounded second line")
          verifyItemInside(chip, list, context, "key chip")
          verifyItemInside(descriptionText, list, context, "description")
          verifyTextInsideCard(keyText, card, context, "key")
          verifyTextInsideCard(descriptionText, card, context, "description")
        }
      }
    }
  }

  function test_fixed_palette_covers_every_preview_surface() {
    const preview = createTemporaryObject(previewComponent, this, {
      themeBackground: "#010203",
      themeForeground: "#112233",
      themeAccent: "#445566",
      settings: {
        enabled: true,
        position: "center",
        opacity: 0.8,
        scale: 1.0,
        followTheme: false,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    verify(colorNear(preview.previewBackground, Qt.rgba(21 / 255, 21 / 255, 21 / 255, 1)))
    verify(colorNear(preview.previewForeground, Qt.rgba(242 / 255, 242 / 255, 242 / 255, 1)))
    verify(colorNear(preview.previewAccent, Qt.rgba(143 / 255, 191 / 255, 255 / 255, 1)))
    verify(colorNear(preview.previewBorder, Qt.rgba(242 / 255, 242 / 255, 242 / 255, 0.22)))
    verify(colorNear(preview.previewChipBackground, Qt.rgba(242 / 255, 242 / 255, 242 / 255, 0.1)))
    verify(colorNear(preview.previewChipBorder, Qt.rgba(242 / 255, 242 / 255, 242 / 255, 0.28)))
  }

  function test_follow_theme_palette_covers_every_preview_surface() {
    const preview = createTemporaryObject(previewComponent, this, {
      themeBackground: "#010203",
      themeForeground: "#112233",
      themeAccent: "#445566",
      settings: {
        enabled: true,
        position: "center",
        opacity: 0.8,
        scale: 1.0,
        followTheme: true,
        groups: ["SUPER"],
        hiddenBindingIds: []
      }
    })

    verify(preview !== null)
    verify("themeBorder" in preview)
    preview.themeBorder = "#778899"
    verify(colorNear(preview.previewBackground, Qt.rgba(1 / 255, 2 / 255, 3 / 255, 1)))
    verify(colorNear(preview.previewForeground, Qt.rgba(17 / 255, 34 / 255, 51 / 255, 1)))
    verify(colorNear(preview.previewAccent, Qt.rgba(68 / 255, 85 / 255, 102 / 255, 1)))
    verify(colorNear(preview.previewBorder, Qt.rgba(119 / 255, 136 / 255, 153 / 255, 1)))
    verify(colorNear(preview.previewChipBackground, Qt.rgba(17 / 255, 34 / 255, 51 / 255, 0.1)))
    verify(colorNear(preview.previewChipBorder, Qt.rgba(17 / 255, 34 / 255, 51 / 255, 0.28)))
  }

  function test_hidden_items_remain_runtime_entries() {
    const runtimeBindings = [
      {
        id: "hidden-id",
        modifiers: ["SUPER"],
        key: "H",
        description: "Hidden in preview"
      },
      {
        id: "visible-id",
        modifiers: ["SUPER"],
        key: "V",
        description: "Visible in preview"
      }
    ]
    const preview = createTemporaryObject(previewComponent, this, {
      bindings: runtimeBindings,
      previewModifiers: ["SUPER"],
      settings: {
        opacity: 0.8,
        scale: 1.0,
        followTheme: true,
        hiddenBindingIds: ["hidden-id"]
      }
    })

    verify(preview !== null)
    compare(preview.visibleBindings.length, 1)
    compare(preview.renderedRowCount, 1)
    compare(preview.visibleBindings[0].id, "visible-id")
    compare(runtimeBindings.length, 2)
    compare(runtimeBindings[0].id, "hidden-id")
  }
}
