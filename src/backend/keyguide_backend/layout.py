"""Pure one-page column calculations for the Keyguide HUD."""

from __future__ import annotations

from dataclasses import dataclass
import math


@dataclass(frozen=True)
class Layout:
    """Resolved dimensions for rendering one complete binding group."""

    rows: int
    columns: int
    pages: int
    scale: float
    column_width: int


def _is_finite_geometry(value: object) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(value)
    )


def layout_columns(
    item_count: int,
    available_height: int,
    row_height: int,
    max_width: int,
    column_width: int,
) -> Layout:
    """Fit every item into columns, never into a second HUD page.

    Width compression represents reducing horizontal padding and description
    allocation before type scale is reduced.  The returned scale therefore
    never drops below the accessibility floor of 0.75.
    """
    if not isinstance(item_count, int) or isinstance(item_count, bool):
        raise ValueError("item_count must be a non-boolean integer")
    if item_count < 0:
        raise ValueError("item_count must not be negative")
    geometry = (available_height, row_height, max_width, column_width)
    if not all(_is_finite_geometry(value) for value in geometry):
        raise ValueError("layout geometry must be finite and non-boolean")
    if any(value <= 0 for value in geometry):
        raise ValueError("layout geometry must be positive")

    rows = math.floor(available_height / row_height)
    if rows == 0:
        raise ValueError("available_height must fit at least one row")
    columns = max(1, math.ceil(item_count / rows))
    resolved_width = math.floor(min(column_width, max_width / columns))
    if resolved_width <= 0:
        raise ValueError("max_width must fit at least one column")

    compressed_width = column_width * 0.75
    scale = min(1.0, resolved_width / compressed_width)
    if scale < 0.75:
        raise ValueError("minimum-scale geometry cannot fit all columns")
    return Layout(
        rows=rows,
        columns=columns,
        pages=1,
        scale=scale,
        column_width=resolved_width,
    )
