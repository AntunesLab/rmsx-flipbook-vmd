"""Run VMD with a live console and collect its complete test output.

Some POSIX VMD builds reenter their console while redrawing. Redirecting only
stdout, or supplying stdin EOF, can block redraw or exit before rendering.
A PTY on all three streams preserves the console contract without a fake pass.
"""
from __future__ import annotations
import errno
import os
import signal
import subprocess
import sys
import time


def run(command, *, cwd=None, env=None, timeout=None, stream=False):
    if os.name != "posix":
        # Native Windows VMD has a different console implementation. Keep input
        # live; its graphical/renderer qualification still requires a real run.
        read_fd, write_fd = os.pipe()
        try:
            result = subprocess.run(command, cwd=cwd, env=env, stdin=read_fd,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    timeout=timeout, text=True, errors="replace")
            if stream:
                sys.stdout.write(result.stdout)
            return result
        finally:
            os.close(read_fd)
            os.close(write_fd)
    import pty
    import select
    master, slave = pty.openpty()
    process = None
    output = bytearray()
    began = time.monotonic()
    expired = False
    try:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdin=slave,
                                   stdout=slave, stderr=slave, start_new_session=True)
        os.close(slave)
        slave = None
        while True:
            if timeout is not None and time.monotonic() - began >= timeout:
                expired = True
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                break
            readable, _, _ = select.select([master], [], [], 0.1)
            if readable:
                try:
                    chunk = os.read(master, 65536)
                except OSError as exc:
                    if exc.errno == errno.EIO:
                        break
                    raise
                if not chunk:
                    break
                output.extend(chunk)
                if stream:
                    sys.stdout.write(chunk.decode(errors="replace"))
                    sys.stdout.flush()
            elif process.poll() is not None:
                break
        code = process.wait()
        text = output.decode(errors="replace").replace("\r\n", "\n")
        if expired:
            raise subprocess.TimeoutExpired(command, timeout, output=text)
        return subprocess.CompletedProcess(command, code, stdout=text)
    finally:
        if process is not None and process.poll() is None:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        os.close(master)
        if slave is not None:
            os.close(slave)
