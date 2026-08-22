from __future__ import annotations

import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest


PROJECT_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = PROJECT_ROOT / "src" / "backend"
WRAPPER = [sys.executable, "-m", "keyguide_backend.bounded_process"]


def run_wrapper(
    command: list[str], *, stdout_limit: int, stderr_limit: int, timeout: float = 5
) -> subprocess.CompletedProcess[bytes]:
    environment = os.environ.copy()
    environment["PYTHONPATH"] = str(BACKEND_ROOT)
    return subprocess.run(
        WRAPPER
        + [
            "--stdout-limit",
            str(stdout_limit),
            "--stderr-limit",
            str(stderr_limit),
            "--",
            *command,
        ],
        check=False,
        capture_output=True,
        env=environment,
        timeout=timeout,
    )


class BoundedProcessTests(unittest.TestCase):
    def wrapper_environment(self) -> dict[str, str]:
        environment = os.environ.copy()
        environment["PYTHONPATH"] = str(BACKEND_ROOT)
        return environment

    def test_preserves_utf8_split_across_raw_writes(self) -> None:
        result = run_wrapper(
            [
                sys.executable,
                "-c",
                (
                    "import os,time; data='가'.encode(); "
                    "os.write(1,data[:1]); time.sleep(0.05); os.write(1,data[1:])"
                ),
            ],
            stdout_limit=3,
            stderr_limit=16,
        )

        self.assertEqual(0, result.returncode)
        self.assertEqual("가", result.stdout.decode("utf-8"))
        self.assertEqual(b"", result.stderr)

    def test_exact_limit_succeeds_and_limit_plus_one_fails_per_channel(self) -> None:
        exact = run_wrapper(
            [sys.executable, "-c", "import os; os.write(1,b'abcd')"],
            stdout_limit=4,
            stderr_limit=4,
        )
        stdout_overflow = run_wrapper(
            [sys.executable, "-c", "import os; os.write(1,b'abcde')"],
            stdout_limit=4,
            stderr_limit=4,
        )
        stderr_overflow = run_wrapper(
            [sys.executable, "-c", "import os; os.write(2,b'abcde')"],
            stdout_limit=4,
            stderr_limit=4,
        )

        self.assertEqual((0, b"abcd"), (exact.returncode, exact.stdout))
        self.assertEqual((120, b"abcd"), (stdout_overflow.returncode, stdout_overflow.stdout))
        self.assertEqual((121, b"abcd"), (stderr_overflow.returncode, stderr_overflow.stderr))

    def test_concurrent_delimiter_free_output_does_not_deadlock(self) -> None:
        result = run_wrapper(
            [
                sys.executable,
                "-c",
                (
                    "import os,threading; "
                    "a=threading.Thread(target=lambda:os.write(1,b'x'*200000)); "
                    "b=threading.Thread(target=lambda:os.write(2,b'y'*200000)); "
                    "a.start(); b.start(); a.join(); b.join()"
                ),
            ],
            stdout_limit=250_000,
            stderr_limit=250_000,
        )

        self.assertEqual(0, result.returncode)
        self.assertEqual(200_000, len(result.stdout))
        self.assertEqual(200_000, len(result.stderr))

    def test_overflow_kills_a_sigterm_ignoring_process_group(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            pid_path = Path(directory) / "child.pid"
            command = [
                sys.executable,
                "-c",
                (
                    "import os,pathlib,signal,time; "
                    "signal.signal(signal.SIGTERM,signal.SIG_IGN); "
                    f"pathlib.Path({str(pid_path)!r}).write_text(str(os.getpid())); "
                    "os.write(1,b'overflow'); time.sleep(30)"
                ),
            ]

            started = time.monotonic()
            result = run_wrapper(
                command, stdout_limit=4, stderr_limit=64, timeout=3
            )
            elapsed = time.monotonic() - started

            self.assertEqual(120, result.returncode)
            self.assertLess(elapsed, 2)
            child_pid = int(pid_path.read_text())
            with self.assertRaises(ProcessLookupError):
                os.kill(child_pid, 0)

    def test_overflow_kills_sigterm_ignoring_descendants_after_parent_exits(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            pid_path = Path(directory) / "descendant.pid"
            descendant = (
                "import os,pathlib,signal,time; "
                "signal.signal(signal.SIGTERM,signal.SIG_IGN); "
                f"pathlib.Path({str(pid_path)!r}).write_text(str(os.getpid())); "
                "time.sleep(30)"
            )
            parent = (
                "import os,pathlib,subprocess,sys,time; "
                f"path=pathlib.Path({str(pid_path)!r}); "
                f"subprocess.Popen([sys.executable,'-c',{descendant!r}]); "
                "\nwhile not path.exists(): time.sleep(0.01)\n"
                "os.write(1,b'overflow'); time.sleep(30)"
            )
            descendant_pid = 0
            try:
                result = run_wrapper(
                    [sys.executable, "-c", parent],
                    stdout_limit=4,
                    stderr_limit=64,
                    timeout=3,
                )
                self.assertEqual(120, result.returncode)
                descendant_pid = int(pid_path.read_text())
                state_path = Path("/proc") / str(descendant_pid) / "stat"
                if state_path.exists():
                    self.assertEqual("Z", state_path.read_text().split()[2])
            finally:
                if descendant_pid:
                    try:
                        os.kill(descendant_pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass

    def test_reserved_child_exit_code_is_remapped(self) -> None:
        result = run_wrapper(
            [sys.executable, "-c", "raise SystemExit(120)"],
            stdout_limit=16,
            stderr_limit=16,
        )

        self.assertEqual(122, result.returncode)

    def test_external_term_kills_a_pipe_detached_ignoring_descendant(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            pid_path = Path(directory) / "detached-descendant.pid"
            descendant = (
                "import os,pathlib,signal,time; "
                "signal.signal(signal.SIGTERM,signal.SIG_IGN); "
                f"pathlib.Path({str(pid_path)!r}).write_text(str(os.getpid())); "
                "time.sleep(30)"
            )
            parent = (
                "import subprocess,sys,time; "
                f"subprocess.Popen([sys.executable,'-c',{descendant!r}], "
                "stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL); "
                "time.sleep(30)"
            )
            wrapper = subprocess.Popen(
                WRAPPER
                + [
                    "--stdout-limit",
                    "64",
                    "--stderr-limit",
                    "64",
                    "--",
                    sys.executable,
                    "-c",
                    parent,
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=self.wrapper_environment(),
            )
            descendant_pid = 0
            try:
                deadline = time.monotonic() + 2
                while not pid_path.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(pid_path.exists())
                descendant_pid = int(pid_path.read_text())
                wrapper.send_signal(signal.SIGTERM)
                wrapper.communicate(timeout=3)

                self.assertEqual(128 + signal.SIGTERM, wrapper.returncode)
                state_path = Path("/proc") / str(descendant_pid) / "stat"
                if state_path.exists():
                    self.assertEqual("Z", state_path.read_text().split()[2])
            finally:
                if wrapper.poll() is None:
                    wrapper.kill()
                    wrapper.wait()
                if descendant_pid:
                    try:
                        os.kill(descendant_pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass

    def test_external_term_kills_a_pipe_closed_ignoring_group_leader(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            pid_path = Path(directory) / "leader.pid"
            helper = (
                "import os,pathlib,signal,time; "
                "signal.signal(signal.SIGTERM,signal.SIG_IGN); "
                f"pathlib.Path({str(pid_path)!r}).write_text(str(os.getpid())); "
                "os.close(1); os.close(2); time.sleep(30)"
            )
            wrapper = subprocess.Popen(
                WRAPPER
                + [
                    "--stdout-limit",
                    "64",
                    "--stderr-limit",
                    "64",
                    "--",
                    sys.executable,
                    "-c",
                    helper,
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env=self.wrapper_environment(),
            )
            helper_pid = 0
            try:
                deadline = time.monotonic() + 2
                while not pid_path.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(pid_path.exists())
                helper_pid = int(pid_path.read_text())
                wrapper.send_signal(signal.SIGTERM)
                wrapper.communicate(timeout=3)

                self.assertEqual(128 + signal.SIGTERM, wrapper.returncode)
                state_path = Path("/proc") / str(helper_pid) / "stat"
                if state_path.exists():
                    self.assertEqual("Z", state_path.read_text().split()[2])
            finally:
                if wrapper.poll() is None:
                    wrapper.kill()
                    wrapper.wait()
                if helper_pid:
                    try:
                        os.kill(helper_pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass


if __name__ == "__main__":
    unittest.main()
