import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class InputHeaderCompatibilityTests(unittest.TestCase):
    def test_action_filter_builds_with_older_linux_input_headers(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_root = Path(temporary_directory)
            linux_include = temporary_root / "linux"
            linux_include.mkdir()
            (linux_include / "input-event-codes.h").write_text(
                """\
#define KEY_RESERVED 0
#define KEY_A 30
#define BTN_MISC 0x100
#define BTN_LEFT 0x110
#define BTN_TASK 0x117
#define KEY_OK 0x160
#define BTN_DPAD_UP 0x220
#define BTN_TRIGGER_HAPPY1 0x2c0
""",
                encoding="utf-8",
            )
            source = temporary_root / "input_header_compatibility.c"
            source.write_text(
                """\
#include "input_codes.h"

#include <assert.h>

int main(void)
{
    assert(input_code_is_keyboard_action(KEY_A));
    assert(!input_code_is_keyboard_action(0x220U));
    assert(!input_code_is_keyboard_action(0x227U));
    return 0;
}
""",
                encoding="utf-8",
            )
            executable = temporary_root / "input_header_compatibility"
            compile_result = subprocess.run(
                [
                    "cc",
                    "-std=c17",
                    "-Wall",
                    "-Wextra",
                    "-Wpedantic",
                    "-Werror",
                    f"-I{temporary_root}",
                    f"-I{ROOT / 'src/observer'}",
                    str(source),
                    "-o",
                    str(executable),
                ],
                cwd=ROOT,
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertEqual(0, compile_result.returncode, compile_result.stderr)
            run_result = subprocess.run(
                [str(executable)],
                cwd=ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(0, run_result.returncode, run_result.stderr)


if __name__ == "__main__":
    unittest.main()
