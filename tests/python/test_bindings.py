"""Active Hyprland binding provider contract tests."""

from contextlib import redirect_stdout
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

from keyguide_backend import bindings, shortcuts
from keyguide_backend import __main__ as cli
from keyguide_backend.groups import canonical_modifiers


FIXTURES = Path(__file__).parents[1] / "fixtures"


class BindingProviderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.omarchy = (FIXTURES / "omarchy-keybindings.txt").read_text()
        cls.hyprctl = (FIXTURES / "hyprctl-binds.txt").read_text()
        cls.source_records = (
            FIXTURES / "omarchy-keybinding-records.txt"
        ).read_text()

    @staticmethod
    def _runtime_record(key: str, description: str) -> str:
        return f"""\
bindd
\tmodmask: 64
\tkey: {key}
\tkeycode: 0
\tdescription: {description}
\tdispatcher: exec
\targ: named-command
"""

    def test_groups_active_bindings_by_exact_modifiers(self) -> None:
        """Each display chord is placed only in its exact modifier group."""
        active = bindings.parse(self.omarchy, self.hyprctl)

        super_only = [item for item in active if item.modifiers == ("SUPER",)]
        self.assertEqual(42, len(super_only))
        self.assertTrue(
            any(
                item.key == "RETURN" and item.description == "Terminal"
                for item in super_only
            )
        )
        browser = next(item for item in active if item.description == "Browser")
        self.assertEqual(("SUPER", "SHIFT"), browser.modifiers)

    def test_unmanaged_binding_starts_without_semantic_presentation_metadata(self) -> None:
        binding = bindings.Binding(
            id="binding-demo",
            modifiers=("SUPER",),
            key="D",
            description="Vendor Tool",
            dispatcher="exec",
            argument="vendor-tool",
            mouse=False,
            editable=True,
        )

        self.assertEqual(
            ("", "", "", ""),
            (
                binding.selection_kind,
                binding.selection_id,
                binding.label_key,
                binding.title_override,
            ),
        )

    def test_runtime_modifier_order_is_canonical(self) -> None:
        """Out-of-order runtime modifiers would miss their exact HUD group."""
        self.assertEqual(
            ("SUPER", "CTRL", "SHIFT"),
            bindings._runtime_modifiers("SUPER SHIFT CTRL"),
        )

    def test_canonical_modifiers_rejects_unknown_modifier_names(self) -> None:
        """An unknown modifier must not become a different display chord."""
        self.assertIsNone(canonical_modifiers(("SUPER", "META")))

    def test_canonical_modifiers_rejects_duplicate_modifier_names(self) -> None:
        """A repeated modifier must not silently become a valid chord."""
        self.assertIsNone(canonical_modifiers(("SUPER", "SUPER")))

    def test_preserves_display_fields_and_attaches_runtime_metadata(self) -> None:
        """Menu key/name fields stay authoritative while runtime metadata is joined."""
        active = bindings.parse(self.omarchy, self.hyprctl)

        terminal = next(item for item in active if item.description == "Terminal")
        self.assertEqual("__lua", terminal.dispatcher)
        self.assertEqual("105", terminal.argument)
        self.assertFalse(terminal.editable)

    def test_source_records_make_reconstructable_lua_runtime_binding_editable(
        self,
    ) -> None:
        """Source metadata, not volatile Lua registry IDs, authorizes editing."""
        menu = "SUPER + RETURN → Terminal\nSUPER + F → Full screen\n"
        runtime = self._runtime_record("RETURN", "Terminal").replace(
            "dispatcher: exec\n\targ: named-command", "dispatcher: __lua\n\targ: 275"
        ) + self._runtime_record("F", "Full screen").replace(
            "dispatcher: exec\n\targ: named-command", "dispatcher: __lua\n\targ: 277"
        )
        records = (
            "SUPER + RETURN → Terminal\texec\tomarchy-launch-terminal\n"
            "SUPER + F → Full screen\tlua\thl.dsp.window.fullscreen({ mode = \"fullscreen\" })\n"
        )

        terminal, fullscreen = bindings.parse(menu, runtime, records)

        self.assertTrue(terminal.editable)
        self.assertEqual(
            ("exec", "omarchy-launch-terminal", ""),
            (terminal.action_kind, terminal.action_argument, terminal.edit_reason),
        )
        self.assertTrue(fullscreen.editable)
        self.assertEqual(
            ("lua", 'hl.dsp.window.fullscreen({ mode = "fullscreen" })'),
            (fullscreen.action_kind, fullscreen.action_argument),
        )
        self.assertEqual(("__lua", "275"), (terminal.dispatcher, terminal.argument))

    def test_source_record_without_reconstructable_action_has_named_reason(self) -> None:
        """An active callback stays visible but is unavailable without source action."""
        active = bindings.parse(
            "SUPER + C → Universal copy\n",
            self._runtime_record("C", "Universal copy").replace(
                "dispatcher: exec", "dispatcher: __lua"
            ),
            "SUPER + C → Universal copy\t\t\n",
        )

        self.assertFalse(active[0].editable)
        self.assertIsNone(active[0].action_kind)
        self.assertIsNone(active[0].action_argument)
        self.assertEqual("Action cannot be reconstructed", active[0].edit_reason)

    def test_malformed_source_record_has_named_reason_when_its_display_is_known(
        self,
    ) -> None:
        """A truncated source record cannot silently inherit a runtime command."""
        active = bindings.parse(
            "SUPER + A → Alpha\n",
            self._runtime_record("A", "Alpha"),
            "SUPER + A → Alpha\texec\n",
        )

        self.assertFalse(active[0].editable)
        self.assertEqual("Malformed action record", active[0].edit_reason)

    def test_source_action_rejects_del_and_c1_control_characters(self) -> None:
        """Non-ASCII control characters cannot become persisted source actions."""
        for control in ("\x7f", "\x80", "\x9f"):
            with self.subTest(control=ord(control)):
                active = bindings.parse(
                    "SUPER + A → Alpha\n",
                    self._runtime_record("A", "Alpha"),
                    f"SUPER + A → Alpha\texec\talpha{control}command\n",
                )

                self.assertFalse(active[0].editable)
                self.assertIsNone(active[0].action_kind)
                self.assertIsNone(active[0].action_argument)
                self.assertEqual("Malformed action record", active[0].edit_reason)

    def test_duplicate_exact_source_records_are_ambiguous(self) -> None:
        """Conflicting source actions for one displayed row are never selected."""
        active = bindings.parse(
            "SUPER + A → Alpha\n",
            self._runtime_record("A", "Alpha"),
            "SUPER + A → Alpha\texec\tfirst\n"
            "SUPER + A → Alpha\texec\tsecond\n",
        )

        self.assertFalse(active[0].editable)
        self.assertEqual("Ambiguous action metadata", active[0].edit_reason)

    def test_mouse_binding_reason_precedes_source_action_metadata(self) -> None:
        """Reconstructable pointer actions are unavailable to the keyboard editor."""
        active = bindings.parse(
            "SUPER + LEFT MOUSE BUTTON → Move window\n",
            self._runtime_record("mouse:272", "Move window"),
            "SUPER + LEFT MOUSE BUTTON → Move window\texec\tmove-window\n",
        )

        self.assertFalse(active[0].editable)
        self.assertEqual("Mouse binding", active[0].edit_reason)

    def test_unsupported_key_reason_precedes_source_action_metadata(self) -> None:
        """A source command cannot authorize an editor key spelling it cannot emit."""
        active = bindings.parse(
            "SUPER + code:201 → Hardware action\n",
            self._runtime_record("code:201", "Hardware action"),
            "SUPER + code:201 → Hardware action\texec\thardware-command\n",
        )

        self.assertFalse(active[0].editable)
        self.assertEqual("Unsupported key", active[0].edit_reason)

    def test_duplicate_runtime_chord_reason_precedes_source_action_metadata(self) -> None:
        """A source action cannot resolve which of two active chord actions to move."""
        active = bindings.parse(
            "SUPER + A → Alpha\n",
            self._runtime_record("A", "Alpha")
            + self._runtime_record("A", "Also alpha"),
            "SUPER + A → Alpha\texec\talpha-command\n",
        )

        self.assertFalse(active[0].editable)
        self.assertEqual("Duplicate chord", active[0].edit_reason)

    def test_unsupported_source_action_kind_has_named_reason(self) -> None:
        """Only the explicitly supported source action kinds may be persisted."""
        active = bindings.parse(
            "SUPER + A → Alpha\n",
            self._runtime_record("A", "Alpha"),
            "SUPER + A → Alpha\tdispatch\talpha-command\n",
        )

        self.assertFalse(active[0].editable)
        self.assertEqual("Unsupported action kind", active[0].edit_reason)

    def test_source_fixture_normalizes_terminal_but_not_arbitrary_callback(self) -> None:
        """The production-shaped fixture proves known actions do not use Lua IDs."""
        active = bindings.parse(self.omarchy, self.hyprctl, self.source_records)
        terminal = next(item for item in active if item.description == "Terminal")
        copy = next(item for item in active if item.description == "Universal copy")

        self.assertEqual(("exec", "omarchy-launch-terminal"), (
            terminal.action_kind,
            terminal.action_argument,
        ))
        self.assertTrue(terminal.editable)
        self.assertFalse(copy.editable)
        self.assertEqual("Action cannot be reconstructed", copy.edit_reason)

    def test_parse_source_records_canonicalizes_display_chords(self) -> None:
        """Source records share the canonical exact-match fields used by runtime rows."""
        records = bindings.parse_source_records(
            "SUPER CTRL + comma → Test action\texec\ttest-command\n"
        )

        self.assertEqual(1, len(records))
        self.assertEqual(
            (("SUPER", "CTRL"), "COMMA", "Test action", "exec", "test-command"),
            (
                records[0].modifiers,
                records[0].key,
                records[0].description,
                records[0].action_kind,
                records[0].action_argument,
            ),
        )

    def test_matches_readable_mouse_and_keycode_names(self) -> None:
        """Hyprland pointer/keycode spellings still join to readable menu rows."""
        active = bindings.parse(self.omarchy, self.hyprctl)

        move = next(item for item in active if item.description == "Move window")
        workspace = next(
            item for item in active if item.description == "Switch to workspace 1"
        )
        keycode_only = next(
            item for item in active if item.description == "Pseudo window"
        )
        self.assertEqual("111", move.argument)
        self.assertTrue(move.mouse)
        self.assertEqual("109", workspace.argument)
        self.assertEqual("119", keycode_only.argument)

    def test_stable_identity_excludes_registry_pointer(self) -> None:
        """A volatile Lua registry argument cannot alter presentation identity."""
        first = next(
            item
            for item in bindings.parse(self.omarchy, self.hyprctl)
            if item.description == "Keybindings"
        )
        changed_pointer = self.hyprctl.replace("arg: 101", "arg: 999", 1)
        reparsed = next(
            item
            for item in bindings.parse(self.omarchy, changed_pointer)
            if item.description == "Keybindings"
        )

        self.assertEqual(
            bindings.stable_id(first.modifiers, first.key, first.description),
            first.id,
        )
        self.assertEqual(first.id, reparsed.id)
        self.assertNotEqual(first.argument, reparsed.argument)

    def test_filters_reserved_keyguide_internal_records(self) -> None:
        """Implementation-only Keyguide chords never appear in the user model."""
        active = bindings.parse(self.omarchy, self.hyprctl)

        self.assertFalse(
            any(item.description == "Keyguide internal observer" for item in active)
        )

    def test_omits_display_row_without_an_active_runtime_binding(self) -> None:
        """A menu-only row cannot be presented as an active Hyprland binding."""
        omarchy = """\
SUPER + RETURN                      → Terminal
SHIFT ALT + L                       → Copy URL from Web App
"""
        hyprctl = """\
bindd
	modmask: 64
	key: RETURN
	keycode: 0
	description: Terminal
	dispatcher: exec
	arg: terminal
"""

        active = bindings.parse(omarchy, hyprctl)

        self.assertEqual(["Terminal"], [item.description for item in active])

    def test_omits_stale_menu_row_instead_of_joining_same_description_on_other_key(
        self,
    ) -> None:
        """Description equality must never authorize a command from another chord."""
        omarchy = "SUPER + A → Alpha\n"
        hyprctl = self._runtime_record("B", "Alpha") + self._runtime_record(
            "A", "Other"
        )

        active = bindings.parse(omarchy, hyprctl)

        self.assertEqual([], active)

    def test_omits_display_chord_with_unknown_modifier_before_runtime_join(self) -> None:
        """A malformed display chord must not join an unrelated bare-key binding."""
        omarchy = "SUPER META + X → Open shell\n"
        hyprctl = """\
bindd
\tmodmask: 0
\tkey: X
\tkeycode: 0
\tdescription: Open shell
\tdispatcher: exec
\targ: shell
"""

        self.assertEqual([], bindings.parse(omarchy, hyprctl))

    def test_chord_collision_makes_reconstructable_action_read_only(self) -> None:
        """A second runtime action on one chord prevents safe shortcut editing."""
        omarchy = """\
SUPER + X → First action
SUPER + X → Second action
"""
        hyprctl = """\
bindd
	modmask: 64
	key: X
	keycode: 0
	description: First action
	dispatcher: exec
	arg: first-command

bindd
	modmask: 64
	key: X
	keycode: 0
	description: Second action
	dispatcher: exec
	arg: second-command
"""

        active = bindings.parse(omarchy, hyprctl)

        self.assertEqual(2, len(active))
        self.assertEqual(
            ["first-command", "second-command"],
            [item.argument for item in active],
        )
        self.assertTrue(all(not item.editable for item in active))

    def test_unsupported_keycode_binding_is_read_only_even_when_exec_is_reconstructable(self) -> None:
        """The editor must not emit a key spelling outside its finite safe set."""
        omarchy = "SUPER + code:201 → Hardware action\n"
        hyprctl = """\
bindd
\tmodmask: 64
\tkey: code:201
\tkeycode: 0
\tdescription: Hardware action
\tdispatcher: exec
\targ: hardware-command
"""

        active = bindings.parse(omarchy, hyprctl)

        self.assertEqual(1, len(active))
        self.assertFalse(active[0].editable)

    def test_load_runtime_bindings_includes_non_menu_collision_chords(self) -> None:
        """Free-key checks must include runtime records omitted from the menu output."""
        hyprctl = """\
bindd
\tmodmask: 64
\tkey: Q
\tkeycode: 0
\tdescription: Hidden runtime action
\tdispatcher: exec
\targ: hidden-command
"""
        calls: list[tuple[str, ...]] = []

        runtime = bindings.load_runtime_bindings(
            lambda command: calls.append(command) or hyprctl
        )

        self.assertEqual([("hyprctl", "binds")], calls)
        self.assertEqual(
            [("SUPER",), "Q", "Hidden runtime action", "exec", "hidden-command"],
            [
                runtime[0].modifiers,
                runtime[0].key,
                runtime[0].description,
                runtime[0].dispatcher,
                runtime[0].argument,
            ],
        )

    def test_runtime_and_menu_keys_share_case_insensitive_canonical_names(self) -> None:
        """Real Hyprland key spellings must join and collide with editor names."""
        cases = (
            ("Home", "HOME"),
            ("Delete", "DELETE"),
            ("Return", "RETURN"),
            ("Enter", "RETURN"),
            ("comma", "COMMA"),
            (",", "COMMA"),
        )
        for runtime_key, expected in cases:
            with self.subTest(runtime_key=runtime_key):
                runtime = bindings.parse_runtime_bindings(
                    self._runtime_record(runtime_key, "Named key")
                )
                active = bindings.parse(
                    f"SUPER + {runtime_key} → Named key\n",
                    self._runtime_record(runtime_key, "Named key"),
                )

                self.assertEqual(expected, runtime[0].key)
                self.assertEqual(runtime_key, active[0].key)
                self.assertEqual(
                    bindings.stable_id(("SUPER",), runtime_key, "Named key"),
                    active[0].id,
                )

    def test_named_key_upgrade_keeps_existing_hidden_binding_identity(self) -> None:
        """Collision canonicalization must not rewrite persisted presentation IDs."""
        active = bindings.parse(self.omarchy, self.hyprctl)
        home = next(item for item in active if item.description == "Restore window width")

        self.assertEqual("Home", home.key)
        self.assertEqual(
            bindings.stable_id(("SUPER",), "Home", "Restore window width"),
            home.id,
        )

    def test_runtime_binding_without_description_is_retained_for_collisions(self) -> None:
        """An undescribed user bind still occupies its runtime chord."""
        runtime = bindings.parse_runtime_bindings(
            self._runtime_record("Home", "")
        )

        self.assertEqual(1, len(runtime))
        self.assertEqual(("SUPER",), runtime[0].modifiers)
        self.assertEqual("HOME", runtime[0].key)
        self.assertEqual("", runtime[0].description)

    def test_load_active_bindings_uses_supported_plain_text_commands(self) -> None:
        """Collection delegates display and metadata to the supported commands."""
        outputs = {
            ("omarchy", "menu", "keybindings", "--print"): self.omarchy,
            ("hyprctl", "binds"): self.hyprctl,
            (
                "/usr/bin/bash",
                "-c",
                "source /usr/bin/omarchy-menu-keybindings --print >/dev/null; output_binding_records",
            ): self.source_records,
        }
        calls: list[tuple[str, ...]] = []

        def runner(command: tuple[str, ...]) -> str:
            calls.append(command)
            return outputs[command]

        active = bindings.load_active_bindings(runner)

        self.assertEqual(
            [
                ("omarchy", "menu", "keybindings", "--print"),
                ("hyprctl", "binds"),
                (
                    "/usr/bin/bash",
                    "-c",
                    "source /usr/bin/omarchy-menu-keybindings --print >/dev/null; output_binding_records",
                ),
            ],
            calls,
        )
        terminal = next(item for item in active if item.description == "Terminal")
        self.assertEqual("omarchy-launch-terminal", terminal.action_argument)

    def test_load_active_bindings_degrades_when_source_discovery_fails(self) -> None:
        """A source discovery failure must not discard the active HUD model."""
        source_command = (
            "/usr/bin/bash",
            "-c",
            "source /usr/bin/omarchy-menu-keybindings --print >/dev/null; output_binding_records",
        )
        outputs = {
            ("omarchy", "menu", "keybindings", "--print"): self.omarchy,
            ("hyprctl", "binds"): self.hyprctl,
        }
        calls: list[tuple[str, ...]] = []

        def runner(command: tuple[str, ...]) -> str:
            calls.append(command)
            if command == source_command:
                raise subprocess.CalledProcessError(1, command)
            return outputs[command]

        active = bindings.load_active_bindings(runner)

        terminal = next(item for item in active if item.description == "Terminal")
        self.assertFalse(terminal.editable)
        self.assertEqual("Action cannot be reconstructed", terminal.edit_reason)
        self.assertEqual(
            [
                ("omarchy", "menu", "keybindings", "--print"),
                ("hyprctl", "binds"),
                source_command,
            ],
            calls,
        )

    def test_bindings_cli_emits_the_complete_model_as_json(self) -> None:
        """The bindings command serializes every Binding field for QML consumers."""
        binding = bindings.Binding(
            id="binding-test",
            modifiers=("SUPER", "CTRL"),
            key="K",
            description="Keybindings",
            dispatcher="exec",
            argument="show-keys",
            mouse=False,
            editable=True,
            presentation_id="presentation-test",
        )
        output = io.StringIO()

        with (
            patch.object(
                shortcuts.ShortcutManager,
                "bindings",
                return_value=[binding],
            ),
            patch.object(sys, "argv", ["keyguide_backend", "bindings", "--json"]),
            redirect_stdout(output),
        ):
            status = cli.main()

        self.assertEqual(0, status)
        self.assertEqual(
            [
                {
                    "id": "binding-test",
                    "modifiers": ["SUPER", "CTRL"],
                    "key": "K",
                    "description": "Keybindings",
                    "dispatcher": "exec",
                    "argument": "show-keys",
                    "mouse": False,
                    "editable": True,
                    "action_kind": None,
                    "action_argument": None,
                    "edit_reason": "",
                    "presentation_id": "presentation-test",
                    "selection_kind": "",
                    "selection_id": "",
                    "label_key": "",
                    "title_override": "",
                }
            ],
            json.loads(output.getvalue()),
        )

    def test_bindings_cli_recovers_an_interrupted_reset_before_discovery(self) -> None:
        """A concurrent refresh must not observe one half of a reset transaction."""
        manager = Mock()
        manager.bindings.return_value = []
        output = io.StringIO()
        with tempfile.TemporaryDirectory() as directory:
            data_home = Path(directory) / "data"
            expected_settings_path = (
                data_home / "omarchy-keyguide" / "settings.json"
            )
            with (
                patch.dict(
                    os.environ,
                    {"XDG_DATA_HOME": str(data_home)},
                    clear=False,
                ),
                patch.object(shortcuts, "ShortcutManager", return_value=manager),
                patch.object(sys, "argv", ["keyguide_backend", "bindings", "--json"]),
                redirect_stdout(output),
            ):
                self.assertEqual(0, cli.main())

        manager.recover_reset_transaction.assert_called_once_with(
            expected_settings_path
        )
        manager.bindings.assert_called_once_with()
        self.assertEqual([], json.loads(output.getvalue()))


if __name__ == "__main__":
    unittest.main()
