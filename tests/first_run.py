"""First-run consent, package order, NVIDIA handling, and Termux detection."""

import os
import pty
import select
import subprocess
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def converse(command, env, answer):
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe("bash", ["bash", str(command)], env)
    output = bytearray()
    responded = 0
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        readable, _, _ = select.select([fd], [], [], 0.1)
        if readable:
            try:
                chunk = os.read(fd, 16384)
            except OSError:
                break
            if not chunk:
                break
            output.extend(chunk)
            while output.count(b"[y/N] ") > responded:
                question = output.split(b"[y/N] ")[responded].splitlines()[-1].decode(errors="replace")
                os.write(fd, answer(question).encode() + b"\n")
                responded += 1
        result, status = os.waitpid(pid, os.WNOHANG)
        if result:
            os.close(fd)
            return os.waitstatus_to_exitcode(status), output.decode(errors="replace")
    else:
        os.kill(pid, 9)
        os.waitpid(pid, 0)
        raise AssertionError("first-run prompt timed out")
    _, status = os.waitpid(pid, 0)
    os.close(fd)
    return os.waitstatus_to_exitcode(status), output.decode(errors="replace")


with tempfile.TemporaryDirectory() as directory:
    temp = Path(directory)
    bindir = temp / "bin"
    bindir.mkdir()
    for executable in ("bash", "dirname", "uname", "mkdir", "touch", "chmod"):
        (bindir / executable).symlink_to(f"/usr/bin/{executable}")
    (bindir / "id").write_text("#!/bin/sh\nif [ \"$1\" = -u ]; then printf '0\\n'; fi\n")
    (bindir / "id").chmod(0o755)
    apt_log = temp / "apt.log"
    (bindir / "apt-get").write_text(
        "#!/usr/bin/env bash\n"
        "printf '%s\\n' \"$*\" >>\"$TMUX1C_TEST_APT_LOG\"\n"
        "if [[ $1 == install ]]; then\n"
        "  name=${@: -1}\n"
        "  printf '#!/bin/sh\\nexit 0\\n' >\"$TMUX1C_TEST_BIN/$name\"\n"
        "  chmod +x \"$TMUX1C_TEST_BIN/$name\"\n"
        "fi\n"
    )
    (bindir / "apt-get").chmod(0o755)
    env = dict(os.environ, HOME=str(temp), PATH=str(bindir),
               TMUX1C_TEST_APT_LOG=str(apt_log), TMUX1C_TEST_BIN=str(bindir))

    declined_home = temp / "declined"
    declined_home.mkdir()
    code, output = converse(
        ROOT / "first-run.sh", dict(env, HOME=str(declined_home)),
        lambda question: "n",
    )
    assert code != 0 and "tmux is required" in output, output
    assert not apt_log.exists()
    assert not (declined_home / ".config/tmux1c/first-run.done").exists()

    code, output = converse(
        ROOT / "first-run.sh", env,
        lambda question: "y" if "Install tmux" in question else "n",
    )
    assert code == 0, output
    assert "Supported: Ubuntu, Debian, Fedora, Arch Linux" in output
    assert "Install htop" in output
    assert "Install nvtop" not in output
    assert apt_log.read_text().splitlines() == ["install -y tmux"]
    assert (temp / ".config/tmux1c/gpu").read_text() == "none\n"
    assert (temp / ".config/tmux1c/first-run.done").exists()

    code, output = converse(
        ROOT / "first-run.sh", env,
        lambda question: "y" if "NVIDIA GPU?" in question else "n",
    )
    assert code == 0, output
    assert "Install nvtop" in output
    assert apt_log.read_text().splitlines() == ["install -y tmux"]
    assert (temp / ".config/tmux1c/gpu").read_text() == "nvidia\n"

    (bindir / "node").write_text("#!/bin/sh\nprintf '22.19.0\\n'\n")
    (bindir / "node").chmod(0o755)
    npm_log = temp / "npm.log"
    (bindir / "npm").write_text(
        "#!/usr/bin/env bash\n"
        "printf '%s\\n' \"$*\" >>\"$TMUX1C_TEST_NPM_LOG\"\n"
        "mkdir -p \"$HOME/.local/bin\"\n"
        "printf '#!/bin/sh\\nexit 0\\n' >\"$HOME/.local/bin/pi\"\n"
        "chmod +x \"$HOME/.local/bin/pi\"\n"
    )
    (bindir / "npm").chmod(0o755)
    pi_env = dict(env, TMUX1C_TEST_NPM_LOG=str(npm_log))
    code, output = converse(
        ROOT / "first-run.sh", pi_env,
        lambda question: "y" if "Install Pi from" in question else "n",
    )
    assert code == 0, output
    assert npm_log.read_text().strip() == (
        "install -g --ignore-scripts --prefix "
        f"{temp / '.local'} @earendil-works/pi-coding-agent"
    )
    assert (temp / ".local/bin/pi").exists()

    (bindir / "pkg").write_text("#!/bin/sh\nexit 0\n")
    (bindir / "pkg").chmod(0o755)
    termux_env = dict(env, PREFIX="/data/data/com.termux/files/usr")
    diagnosis = subprocess.check_output(
        ["/usr/bin/bash", str(ROOT / "first-run.sh"), "--check"],
        env=termux_env, text=True,
    )
    assert "Detected: Termux (Android) (termux)" in diagnosis

    copied_bin = temp / "installed"
    copied_data = temp / "share"
    install_env = dict(os.environ, HOME=str(temp),
                       TMUX1C_BIN_DIR=str(copied_bin),
                       TMUX1C_DATA_DIR=str(copied_data),
                       TMUX1C_CONFIG_DIR=str(temp / "another-config"))
    installer = subprocess.run(
        ["bash", str(ROOT / "install.sh")], env=install_env,
        text=True, capture_output=True,
    )
    assert installer.returncode == 0, installer.stderr
    assert "Supported: Ubuntu, Debian" in installer.stdout
    assert "Run 1c setup" in installer.stdout
    assert (copied_bin / "1c").stat().st_mode & 0o111
    assert (copied_data / "first-run.sh").exists()
    assert (copied_data / "lib/platform.sh").exists()
    (bindir / "uname").unlink()
    (bindir / "uname").write_text("#!/bin/sh\nprintf 'Darwin\\n'\n")
    (bindir / "uname").chmod(0o755)
    unsupported = subprocess.run(
        ["/usr/bin/bash", str(ROOT / "install.sh")],
        env=dict(env, TMUX1C_BIN_DIR=str(temp / "unsupported-bin"),
                 TMUX1C_DATA_DIR=str(temp / "unsupported-share")),
        text=True, capture_output=True,
    )
    assert unsupported.returncode != 0
    assert "Unsupported environment" in unsupported.stderr
    assert not (temp / "unsupported-bin").exists()
    print("First-run consent, per-package installs, GPU choice, Pi, and Termux detection passed")
