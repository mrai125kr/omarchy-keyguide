"""Run a helper while enforcing exact byte limits on both output channels."""

from __future__ import annotations

import argparse
import errno
import os
import selectors
import signal
import subprocess
import sys
import time
from collections.abc import Sequence


STDOUT_LIMIT_EXIT = 120
STDERR_LIMIT_EXIT = 121
RESERVED_CHILD_EXIT = 122
START_FAILURE_EXIT = 127
TERMINATION_GRACE_SECONDS = 0.2
READ_SIZE = 64 * 1024


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--stdout-limit", required=True, type=int)
    parser.add_argument("--stderr-limit", required=True, type=int)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    return parser


def _write_all(descriptor: int, data: bytes) -> None:
    view = memoryview(data)
    while view:
        try:
            written = os.write(descriptor, view)
        except InterruptedError:
            continue
        if written <= 0:
            raise BrokenPipeError(errno.EPIPE, "output channel closed")
        view = view[written:]


def _signal_group(process: subprocess.Popen[bytes], value: int) -> None:
    try:
        os.killpg(process.pid, value)
    except ProcessLookupError:
        pass


def _group_exists(process: subprocess.Popen[bytes]) -> bool:
    try:
        os.killpg(process.pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def _terminate_group(process: subprocess.Popen[bytes]) -> None:
    _signal_group(process, signal.SIGTERM)
    deadline = time.monotonic() + TERMINATION_GRACE_SECONDS
    while _group_exists(process) and time.monotonic() < deadline:
        time.sleep(0.01)
    if _group_exists(process):
        _signal_group(process, signal.SIGKILL)
    process.wait()


def _normalized_child_exit(returncode: int) -> int:
    if returncode < 0:
        returncode = min(255, 128 - returncode)
    if returncode in {STDOUT_LIMIT_EXIT, STDERR_LIMIT_EXIT}:
        return RESERVED_CHILD_EXIT
    return returncode


def run(command: Sequence[str], stdout_limit: int, stderr_limit: int) -> int:
    if stdout_limit < 0 or stderr_limit < 0:
        raise ValueError("output limits must be non-negative")
    if not command:
        raise ValueError("a command is required after --")

    managed_signals = {signal.SIGINT, signal.SIGTERM}
    previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, managed_signals)
    try:
        process = subprocess.Popen(
            list(command),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            bufsize=0,
            start_new_session=True,
        )
    except OSError as error:
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        message = f"bounded_process: cannot start helper: {error}\n".encode(
            "utf-8", errors="replace"
        )
        _write_all(sys.stderr.fileno(), message[:stderr_limit])
        return START_FAILURE_EXIT

    try:
        assert process.stdout is not None
        assert process.stderr is not None
        stream_selector = selectors.DefaultSelector()
        stream_selector.register(
            process.stdout,
            selectors.EVENT_READ,
            ("stdout", sys.stdout.fileno(), stdout_limit),
        )
        stream_selector.register(
            process.stderr,
            selectors.EVENT_READ,
            ("stderr", sys.stderr.fileno(), stderr_limit),
        )
    except BaseException:
        _terminate_group(process)
        signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
        raise
    counts = {"stdout": 0, "stderr": 0}
    termination_signal = 0
    termination_deadline: float | None = None

    def request_termination(value: int, _frame: object) -> None:
        nonlocal termination_signal, termination_deadline
        if termination_signal == 0:
            termination_signal = value
            termination_deadline = time.monotonic() + TERMINATION_GRACE_SECONDS
            _signal_group(process, signal.SIGTERM)

    previous_sigterm = signal.signal(signal.SIGTERM, request_termination)
    previous_sigint = signal.signal(signal.SIGINT, request_termination)
    signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
    overflow_exit = 0
    try:
        while stream_selector.get_map():
            if (
                termination_deadline is not None
                and time.monotonic() >= termination_deadline
                and _group_exists(process)
            ):
                _signal_group(process, signal.SIGKILL)
                termination_deadline = None

            for key, _events in stream_selector.select(timeout=0.05):
                channel, output_descriptor, limit = key.data
                try:
                    chunk = os.read(key.fileobj.fileno(), READ_SIZE)
                except InterruptedError:
                    continue
                if not chunk:
                    stream_selector.unregister(key.fileobj)
                    key.fileobj.close()
                    continue

                available = max(0, limit - counts[channel])
                forwarded = chunk[:available]
                if forwarded:
                    _write_all(output_descriptor, forwarded)
                    counts[channel] += len(forwarded)
                if len(chunk) > len(forwarded):
                    overflow_exit = (
                        STDOUT_LIMIT_EXIT if channel == "stdout" else STDERR_LIMIT_EXIT
                    )
                    break
            if overflow_exit:
                break

        if overflow_exit:
            _terminate_group(process)
            return overflow_exit

        while process.poll() is None:
            if termination_signal:
                _terminate_group(process)
                return min(255, 128 + termination_signal)
            time.sleep(0.01)
        if termination_signal:
            _terminate_group(process)
            return min(255, 128 + termination_signal)
        returncode = process.wait()
        return _normalized_child_exit(returncode)
    except BrokenPipeError:
        _terminate_group(process)
        return 1
    finally:
        signal.signal(signal.SIGTERM, previous_sigterm)
        signal.signal(signal.SIGINT, previous_sigint)
        stream_selector.close()
        for stream in (process.stdout, process.stderr):
            if not stream.closed:
                stream.close()


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    command = list(arguments.command)
    if command and command[0] == "--":
        command.pop(0)
    try:
        return run(command, arguments.stdout_limit, arguments.stderr_limit)
    except ValueError as error:
        print(f"bounded_process: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
