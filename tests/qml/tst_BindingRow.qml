import QtQuick
import QtQuick.Window
import QtTest
import "../../src/plugin/components" as Components

TestCase {
  name: "BindingRow"
  when: windowShown

  Component {
    id: testWindowComponent

    Window {
      width: 1000
      height: 400
      visible: true
    }
  }

  Component {
    id: rowComponent

    Components.BindingRow {
      width: 480
      height: implicitHeight
    }
  }

  function findNamed(object, name, depth) {
    if (!object || depth > 16)
      return null
    if (object.objectName === name)
      return object
    const children = object.children || []
    for (let index = 0; index < children.length; index += 1) {
      const found = findNamed(children[index], name, depth + 1)
      if (found)
        return found
    }
    return null
  }

  Component {
    id: spyComponent

    SignalSpy {}
  }

  function test_toggle_requests_presentation_visibility_only() {
    const runtimeBinding = {
      id: "terminal-id",
      modifiers: ["SUPER"],
      key: "RETURN",
      description: "Terminal"
    }
    const row = createTemporaryObject(rowComponent, this, {
      bindingData: runtimeBinding,
      visibleInHud: true
    })
    const spy = createTemporaryObject(spyComponent, this, {
      target: row,
      signalName: "visibilityChangeRequested"
    })

    verify(row !== null)
    verify(spy !== null)
    row.requestToggle()

    compare(spy.count, 1)
    compare(spy.signalArguments[0][0], "terminal-id")
    compare(spy.signalArguments[0][1], false)
    compare(runtimeBinding.key, "RETURN")
    compare(runtimeBinding.modifiers.join("+"), "SUPER")
  }

  function test_noninteractive_group_row_cannot_request_visibility_change() {
    const row = createTemporaryObject(rowComponent, this, {
      bindingData: {
        id: "terminal-id",
        modifiers: ["SUPER"],
        key: "RETURN",
        description: "Terminal"
      },
      visibleInHud: false,
      interactive: false
    })
    const spy = createTemporaryObject(spyComponent, this, {
      target: row,
      signalName: "visibilityChangeRequested"
    })

    verify(row !== null)
    verify(spy !== null)
    verify(!row.enabled)
    verify(!row.activeFocusOnTab)
    row.requestToggle()
    compare(spy.count, 0)
  }

  function test_visibility_and_change_emit_independent_signals() {
    const row = createTemporaryObject(rowComponent, this, {
      bindingData: { id: "alpha", key: "A", description: "Alpha" }, editable: true
    })
    let visibilityCount = 0
    let editCount = 0
    let editAnchor = null
    row.visibilityChangeRequested.connect(function() { visibilityCount += 1 })
    row.editRequested.connect(function(bindingId, anchorItem) {
      editCount += 1
      editAnchor = anchorItem
    })

    row.requestToggle()
    compare(visibilityCount, 1)
    compare(editCount, 0)
    row.requestEdit()
    compare(visibilityCount, 1)
    compare(editCount, 1)
    compare(editAnchor, row)
    compare(row.editText, "Change")
  }

  function test_unavailable_row_names_reason_without_blocking_visibility() {
    const row = createTemporaryObject(rowComponent, this, {
      bindingData: { id: "copy", key: "C", description: "Copy" },
      editable: false, editReason: "Action cannot be reconstructed"
    })

    compare(row.editText, "Unavailable")
    compare(row.reasonText, "Action cannot be reconstructed")
    verify(row.interactive)
  }

  function test_unavailable_row_preserves_an_empty_edit_reason() {
    const row = createTemporaryObject(rowComponent, this, {
      bindingData: { id: "copy", key: "C", description: "Copy" },
      editable: false, editReason: ""
    })

    compare(row.editText, "Unavailable")
    compare(row.reasonText, "")
  }

  function test_complete_chord_uses_named_modifier_and_key_parts() {
    const row = createTemporaryObject(rowComponent, this, {
      width: 900,
      bindingData: {
        id: "terminal-id",
        modifiers: ["SUPER", "ALT"],
        key: "T",
        description: "Terminal"
      }
    })

    verify(row !== null)
    compare(row.chordParts.join(","), "Super,Alt,T")
  }

  function test_action_type_badge_uses_the_shared_label_and_color_without_parentheses() {
    const row = createTemporaryObject(rowComponent, this, {
      width: 900,
      language: "en",
      surface: "#080d1f",
      bindingData: {
        id: "bluetooth-id", modifiers: ["SUPER", "CTRL"], key: "B",
        description: "Bluetooth", displayKind: "systemUi"
      }
    })

    verify(row !== null)
    const badge = findNamed(row, "bindingTypeBadge", 0)
    const label = findNamed(row, "bindingTypeBadgeLabel", 0)
    verify(badge !== null, "registered shortcut type badge is missing")
    verify(label !== null, "registered shortcut type badge label is missing")
    verify(badge.width > 0)
    compare(label.text, "SYSTEM UI")
    compare(String(label.color), "#ff8fb8")
    verify(label.text.indexOf("(") === -1)
    verify(label.text.indexOf(")") === -1)
  }

  function test_registered_row_shows_icon_exact_title_and_full_role_context() {
    const row = createTemporaryObject(rowComponent, this, {
      width: 900,
      language: "ko",
      iconResolver: function(iconName) {
        return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='2' height='2'/%3E"
      },
      bindingData: {
        id: "codex-id", modifiers: ["SUPER", "CTRL", "SHIFT"], key: "A",
        description: "Codex", displayKind: "cmd", roleKind: "agent",
        icon: "utilities-terminal"
      }
    })

    verify(row !== null)
    wait(0)
    const icon = findNamed(row, "bindingPresentationIcon", 0)
    const title = findNamed(row, "bindingTitleLabel", 0)
    const typeLabel = findNamed(row, "bindingTypeBadgeLabel", 0)
    const roleLabel = findNamed(row, "bindingRoleBadgeLabel", 0)
    verify(icon !== null, "registered shortcut icon is missing")
    verify(title !== null, "registered shortcut title is missing")
    verify(roleLabel !== null, "registered shortcut role badge is missing")
    verify(String(icon.source || "") !== "")
    compare(icon.width, 24)
    compare(title.text, "Codex")
    compare(typeLabel.text, "CMD")
    compare(roleLabel.text, "에이전트")
  }

  function test_type_role_cluster_is_centered_in_dedicated_column() {
    const testWindow = createTemporaryObject(testWindowComponent, null)
    verify(testWindow !== null)
    const plainRow = createTemporaryObject(rowComponent, testWindow.contentItem, {
      width: 900,
      language: "en",
      bindingData: {
        id: "terminal-id", modifiers: ["SUPER"], key: "RETURN",
        description: "Terminal", displayKind: "cmd", roleKind: ""
      }
    })
    const browserRow = createTemporaryObject(rowComponent, testWindow.contentItem, {
      width: 900,
      language: "en",
      bindingData: {
        id: "browser-id", modifiers: ["SUPER", "SHIFT"], key: "B",
        description: "Chromium", displayKind: "desktopApp",
        roleKind: "browser"
      }
    })

    verify(plainRow !== null)
    verify(browserRow !== null)
    wait(0)
    const plainDescription = findNamed(plainRow, "bindingDescriptionCell", 0)
    const browserDescription = findNamed(browserRow, "bindingDescriptionCell", 0)
    const plainCell = findNamed(plainRow, "bindingTypeRoleCell", 0)
    const browserCell = findNamed(browserRow, "bindingTypeRoleCell", 0)
    const plainCluster = findNamed(plainRow, "bindingBadgeCluster", 0)
    const browserCluster = findNamed(browserRow, "bindingBadgeCluster", 0)
    const browserRole = findNamed(browserRow, "bindingRoleBadge", 0)
    verify(plainDescription !== null)
    verify(browserDescription !== null)
    verify(plainCell !== null)
    verify(browserCell !== null)
    verify(plainCluster !== null)
    verify(browserCluster !== null)
    verify(browserRole !== null)
    verify(browserRole.visible, "the role-bearing fixture did not show its role badge")
    const plainCenter = plainCluster.mapToItem(
      plainCell, plainCluster.width / 2, 0).x
    const browserCenter = browserCluster.mapToItem(
      browserCell, browserCluster.width / 2, 0).x
    verify(Math.abs(plainCenter - plainCell.width / 2) <= 1,
           "the type badge is not centered in the type/role column")
    verify(Math.abs(browserCenter - browserCell.width / 2) <= 1,
           "the type and role badges are not centered as one group")
    const plainDescriptionRight = plainDescription.mapToItem(
      plainRow, plainDescription.width, 0).x
    const plainTypeLeft = plainCell.mapToItem(plainRow, 0, 0).x
    verify(plainTypeLeft - plainDescriptionRight >= 15.5,
           "the title and type/role columns do not have a distinct gutter")
  }

  function test_type_role_column_keeps_double_gap_before_hud() {
    const testWindow = createTemporaryObject(testWindowComponent, null)
    verify(testWindow !== null)
    const widths = [900, 720]
    for (let index = 0; index < widths.length; index += 1) {
      const row = createTemporaryObject(rowComponent, testWindow.contentItem, {
        width: widths[index],
        language: "ko",
        bindingData: {
          id: "browser-" + widths[index],
          modifiers: ["SUPER", "SHIFT"], key: "B",
          description: "Chromium", displayKind: "desktopApp",
          roleKind: "browser"
        }
      })

      verify(row !== null)
      wait(0)
      const cell = findNamed(row, "bindingTypeRoleCell", 0)
      const visibility = findNamed(row, "bindingVisibilityTarget", 0)
      verify(cell !== null)
      verify(visibility !== null)
      const cellRight = cell.mapToItem(row, cell.width, 0).x
      const hudLeft = visibility.mapToItem(row, 0, 0).x
      verify(Math.abs(hudLeft - cellRight - 24) <= 0.01,
             "type/role and HUD columns do not keep the 24px gutter at width "
               + widths[index])
    }
  }

  function test_five_column_layout_compacts_before_title_is_crushed() {
    const narrowRow = createTemporaryObject(rowComponent, this, {
      width: 899,
      bindingData: {
        id: "narrow", modifiers: ["SUPER"], key: "RETURN",
        description: "Terminal", displayKind: "cmd"
      }
    })
    const fullRow = createTemporaryObject(rowComponent, this, {
      width: 900,
      bindingData: {
        id: "full", modifiers: ["SUPER"], key: "RETURN",
        description: "Terminal", displayKind: "cmd"
      }
    })

    verify(narrowRow !== null)
    verify(fullRow !== null)
    verify(narrowRow.compactLayout,
           "the five-column row stayed on one line after its title space collapsed")
    verify(!fullRow.compactLayout,
           "the five-column row did not use the available full-width layout")
  }

  function test_type_role_column_contains_localized_desktop_browser_pair() {
    const testWindow = createTemporaryObject(testWindowComponent, null)
    verify(testWindow !== null)
    const languages = ["en", "ko", "ja", "zh_CN", "es"]
    for (let index = 0; index < languages.length; index += 1) {
      const row = createTemporaryObject(rowComponent, testWindow.contentItem, {
        width: 900,
        language: languages[index],
        bindingData: {
          id: "browser-" + languages[index],
          modifiers: ["SUPER", "SHIFT"], key: "B",
          description: "Chromium", displayKind: "desktopApp",
          roleKind: "browser"
        }
      })

      verify(row !== null)
      wait(0)
      const cell = findNamed(row, "bindingTypeRoleCell", 0)
      const cluster = findNamed(row, "bindingBadgeCluster", 0)
      verify(cell !== null)
      verify(cluster !== null)
      const clusterLeft = cluster.mapToItem(cell, 0, 0).x
      const clusterRight = cluster.mapToItem(cell, cluster.width, 0).x
      verify(clusterLeft >= -0.01 && clusterRight <= cell.width + 0.01,
             "localized type/role badges overflowed their column for "
               + languages[index] + ": left=" + clusterLeft
               + " right=" + clusterRight + " width=" + cell.width)
    }
  }

  function test_title_keeps_sixteen_pixel_gap_before_type_role_column() {
    const testWindow = createTemporaryObject(testWindowComponent, null)
    verify(testWindow !== null)
    const row = createTemporaryObject(rowComponent, testWindow.contentItem, {
      width: 900,
      language: "ko",
      iconResolver: function(iconName) {
        return "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='2' height='2'/%3E"
      },
      bindingData: {
        id: "browser-id", modifiers: ["SUPER", "SHIFT"], key: "B",
        description: "Chromium", displayKind: "desktopApp",
        roleKind: "browser", icon: "chromium"
      }
    })

    verify(row !== null)
    wait(0)
    const cell = findNamed(row, "bindingDescriptionCell", 0)
    const title = findNamed(row, "bindingTitleLabel", 0)
    const typeCell = findNamed(row, "bindingTypeRoleCell", 0)
    verify(cell !== null)
    verify(title !== null)
    verify(typeCell !== null)
    const titleRight = title.mapToItem(cell, title.width, 0).x
    verify(titleRight <= cell.width + 0.01,
           "the title painted outside the action/title column")
    const descriptionRight = cell.mapToItem(row, cell.width, 0).x
    const typeLeft = typeCell.mapToItem(row, 0, 0).x
    verify(typeLeft - descriptionRight >= 15.5,
           "the action/title and type/role columns do not keep a 16px gutter")
  }

  function test_control_columns_align_for_different_chord_and_reason_lengths() {
    const shortRow = createTemporaryObject(rowComponent, this, {
      width: 900,
      fontFamily: "monospace",
      bindingData: {
        id: "short-id", modifiers: ["SUPER"], key: "F", description: "Browser"
      },
      editable: true
    })
    const longRow = createTemporaryObject(rowComponent, this, {
      width: 900,
      fontFamily: "monospace",
      bindingData: {
        id: "long-id", modifiers: ["SUPER", "CTRL", "SHIFT", "ALT"],
        key: "BACKSPACE", description: "A deliberately long action title"
      },
      editable: false,
      editReason: "Action cannot be reconstructed"
    })

    verify(shortRow !== null)
    verify(longRow !== null)
    compare(longRow.chordParts.join(","), "Super,Ctrl,Shift,Alt,BACKSPACE")
    const shortVisibility = findNamed(shortRow, "bindingVisibilityTarget", 0)
    const longVisibility = findNamed(longRow, "bindingVisibilityTarget", 0)
    const shortEdit = findNamed(shortRow, "bindingEditTarget", 0)
    const longEdit = findNamed(longRow, "bindingEditTarget", 0)
    const longChordCell = findNamed(longRow, "bindingChordCell", 0)
    const longChord = findNamed(longRow, "bindingChordParts", 0)
    verify(shortVisibility !== null)
    verify(longVisibility !== null)
    verify(shortEdit !== null)
    verify(longEdit !== null)
    verify(longChordCell !== null)
    verify(longChord !== null)
    compare(longChordCell.width, 316)
    compare(shortVisibility.x, longVisibility.x)
    compare(shortVisibility.width, longVisibility.width)
    compare(shortEdit.x, longEdit.x)
    compare(shortEdit.width, longEdit.width)
    const wideChordRight = longChord.mapToItem(
      longChordCell, longChord.width, 0).x
    verify(wideChordRight <= longChordCell.width + 0.01,
           "wide maximum chord was clipped by its fixed column: chord="
             + wideChordRight + " column=" + longChordCell.width)

    const compactRow = createTemporaryObject(rowComponent, this, {
      width: 480,
      fontFamily: "monospace",
      bindingData: {
        id: "compact-id", modifiers: ["SUPER", "CTRL", "SHIFT", "ALT"],
        key: "BACKSPACE", description: "Compact maximum chord"
      }
    })
    const compactCell = findNamed(compactRow, "bindingChordCell", 0)
    const compactChord = findNamed(compactRow, "bindingChordParts", 0)
    verify(compactCell !== null)
    verify(compactChord !== null)
    const compactChordRight = compactChord.mapToItem(
      compactCell, compactChord.width, 0).x
    verify(compactChordRight <= compactCell.width + 0.01,
           "compact maximum chord was clipped by the action controls")
  }
}
