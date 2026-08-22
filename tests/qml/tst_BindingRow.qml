import QtQuick
import QtTest
import "../../src/plugin/components" as Components

TestCase {
  name: "BindingRow"

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
    compare(shortVisibility.x, longVisibility.x)
    compare(shortVisibility.width, longVisibility.width)
    compare(shortEdit.x, longEdit.x)
    compare(shortEdit.width, longEdit.width)
    const wideChordRight = longChord.mapToItem(
      longChordCell, longChord.width, 0).x
    verify(wideChordRight <= longChordCell.width + 0.01,
           "wide maximum chord was clipped by its fixed column")

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
