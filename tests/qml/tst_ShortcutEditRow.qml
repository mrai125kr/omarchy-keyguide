import QtQuick
import QtTest
import "../../src/plugin/components" as Components

TestCase {
  name: "ConsolidatedShortcutBindingRow"

  Component {
    id: rowComponent
    Components.BindingRow {
      width: 480
      height: implicitHeight
    }
  }

  function test_visibility_and_change_controls_are_independent() {
    const row = createTemporaryObject(rowComponent, this, {
      bindingData: {
        id: "binding-terminal", key: "RETURN", description: "Terminal"
      },
      editable: true,
      visibleInHud: true
    })
    verify(row !== null)
    let visibilityCount = 0
    let editCount = 0
    let requested = ""
    row.visibilityChangeRequested.connect(function() { visibilityCount += 1 })
    row.editRequested.connect(function(bindingId) {
      editCount += 1
      requested = bindingId
    })

    row.requestToggle()
    compare(visibilityCount, 1)
    compare(editCount, 0)
    row.requestEdit()

    compare(visibilityCount, 1)
    compare(editCount, 1)
    compare(requested, "binding-terminal")
    compare(row.editText, "Change")
  }

  function test_named_unavailable_reason_does_not_block_visibility() {
    const row = createTemporaryObject(rowComponent, this, {
      bindingData: {
        id: "binding-window", key: "W", description: "Close window"
      },
      editable: false,
      editReason: "Action cannot be reconstructed"
    })
    verify(row !== null)
    let visibilityCount = 0
    let editCount = 0
    row.visibilityChangeRequested.connect(function() { visibilityCount += 1 })
    row.editRequested.connect(function() { editCount += 1 })

    row.requestToggle()
    row.requestEdit()

    compare(visibilityCount, 1)
    compare(editCount, 0)
    compare(row.editText, "Unavailable")
    compare(row.reasonText, "Action cannot be reconstructed")
    verify(row.interactive)
  }
}
