import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCANNED_SOURCE_DIRS = ("src", "scripts")
UPSTREAM_MARKER = "SPDX-FileCopyrightText: upstream"


def scan_headers(marker: str) -> list[str]:
    matches: list[str] = []
    for directory in SCANNED_SOURCE_DIRS:
        for path in sorted((ROOT / directory).rglob("*")):
            if path.is_file() and marker in path.read_text(
                encoding="utf-8", errors="ignore"
            ):
                matches.append(path.relative_to(ROOT).as_posix())
    return matches


class LicenseNoticeTests(unittest.TestCase):
    def test_clean_room_notice_matches_source_tree(self):
        self.assertEqual([], scan_headers(UPSTREAM_MARKER))

        notice = (ROOT / "NOTICE").read_text(encoding="utf-8")
        self.assertIn("No third-party source code is copied in the MVP", notice)


if __name__ == "__main__":
    unittest.main()
