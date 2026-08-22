"""Adaptive one-page column layout contract tests."""

from __future__ import annotations

import unittest
from contextlib import redirect_stdout
import io
import json
import math
import sys
from unittest.mock import patch

from keyguide_backend.layout import layout_columns
from keyguide_backend import __main__ as cli


class ColumnLayoutTests(unittest.TestCase):
    """Every active binding must remain on the single HUD page."""

    def test_25_items_fit_on_a_1080p_layout(self) -> None:
        """Under-counting columns would hide the final Super+Alt rows."""
        result = layout_columns(
            25,
            available_height=900,
            row_height=48,
            max_width=1800,
            column_width=300,
        )

        self.assertEqual(18, result.rows)
        self.assertEqual(2, result.columns)
        self.assertEqual(1, result.pages)
        self.assertGreaterEqual(result.rows * result.columns, 25)

    def test_37_items_fit_on_a_1080p_layout(self) -> None:
        """Using two columns here would omit the last Super+Shift row."""
        result = layout_columns(
            37,
            available_height=900,
            row_height=48,
            max_width=1800,
            column_width=300,
        )

        self.assertEqual(18, result.rows)
        self.assertEqual(3, result.columns)
        self.assertEqual(1, result.pages)
        self.assertGreaterEqual(result.rows * result.columns, 37)

    def test_42_items_fit_without_paging(self) -> None:
        """Adding a second page would hide active Super bindings behind navigation."""
        result = layout_columns(
            42,
            available_height=900,
            row_height=48,
            max_width=1800,
            column_width=300,
        )

        self.assertEqual(18, result.rows)
        self.assertEqual(3, result.columns)
        self.assertEqual(1, result.pages)
        self.assertGreaterEqual(result.rows * result.columns, 42)

    def test_scaled_laptop_width_compresses_columns_without_paging(self) -> None:
        """Returning multiple pages on a narrow monitor would hide bindings."""
        result = layout_columns(
            42,
            available_height=600,
            row_height=48,
            max_width=900,
            column_width=300,
        )

        self.assertEqual(12, result.rows)
        self.assertEqual(4, result.columns)
        self.assertEqual(225, result.column_width)
        self.assertEqual(1, result.pages)
        self.assertGreaterEqual(result.rows * result.columns, 42)

    def test_minimum_scale_geometry_that_cannot_fit_is_rejected(self) -> None:
        """Clamping scale at 0.75 must not report four 150px columns as fitting."""
        with self.assertRaises(ValueError):
            layout_columns(
                42,
                available_height=600,
                row_height=48,
                max_width=600,
                column_width=300,
            )

    def test_item_count_must_be_a_non_boolean_integer(self) -> None:
        """Fractional or boolean row counts cannot represent HUD bindings."""
        for item_count in (True, 42.5):
            with self.subTest(item_count=item_count):
                with self.assertRaises(ValueError):
                    layout_columns(
                        item_count,
                        available_height=600,
                        row_height=48,
                        max_width=900,
                        column_width=300,
                    )

    def test_geometry_values_must_be_finite_and_non_boolean(self) -> None:
        """Accepting invalid geometry could emit dimensions QML cannot render."""
        invalid_geometry = (
            {"row_height": True},
            {"column_width": True},
            {"max_width": math.inf},
            {"column_width": math.nan},
        )
        for override in invalid_geometry:
            with self.subTest(override=override):
                arguments = {
                    "available_height": 600,
                    "row_height": 48,
                    "max_width": 900,
                    "column_width": 300,
                }
                arguments.update(override)
                with self.assertRaises(ValueError):
                    layout_columns(42, **arguments)

    def test_invalid_geometry_is_rejected(self) -> None:
        """A zero row height would otherwise cause an invalid division."""
        with self.assertRaises(ValueError):
            layout_columns(
                1,
                available_height=900,
                row_height=0,
                max_width=1800,
                column_width=300,
            )

    def test_layout_cli_serializes_a_one_page_result(self) -> None:
        """A CLI shape mismatch would prevent the QML HUD from using the layout."""
        output = io.StringIO()
        with (
            patch.object(
                sys,
                "argv",
                [
                    "keyguide_backend",
                    "layout",
                    '{"itemCount": 42, "availableHeight": 900}',
                ],
            ),
            redirect_stdout(output),
        ):
            self.assertEqual(0, cli.main())

        self.assertEqual(
            {
                "rows": 18,
                "columns": 3,
                "pages": 1,
                "scale": 1.0,
                "column_width": 300,
            },
            json.loads(output.getvalue()),
        )


if __name__ == "__main__":
    unittest.main()
