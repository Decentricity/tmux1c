"""Exercise tmux1c layouts and its keyboard menu with a fake tmux binary."""

import os
import pty
import select
import subprocess
import tempfile
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILES = {
    "ide": 5, "agent-workshop": 3, "model-lab": 3, "git-review": 2,
    "service-watch": 2, "meeting-desk": 3, "comms": 2, "research-desk": 3,
    "terminal-cinema": 3, "travel-light": 1, "dashboard": 2, "focus": 1, "shell": 0,
}
APPS = (
    "micro", "pi", "yazi", "lazygit", "lnav", "ollama", "gcal",
    "telegramy", "whatsappy", "bookmarks", "browsh", "living-caca",
    "soloist", "cava", "gh", "nvtop",
)


def run_tty(args, env, cwd, keys=None):
    pid, fd = pty.fork()
    if pid == 0:
        os.chdir(cwd)
        os.execvpe("bash", ["bash", str(ROOT / "bin/1c"), *args], env)
    deadline = time.monotonic() + 8
    output = bytearray()
    sent = keys is None
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
        if not sent and b"Choose a workspace" in output:
            os.write(fd, keys)
            sent = True
        result, status = os.waitpid(pid, os.WNOHANG)
        if result:
            os.close(fd)
            assert os.waitstatus_to_exitcode(status) == 0, output.decode(errors="replace")
            return output.decode(errors="replace")
    else:
        os.kill(pid, 9)
        os.waitpid(pid, 0)
        raise AssertionError("Launcher timed out")
    _, status = os.waitpid(pid, 0)
    os.close(fd)
    assert os.waitstatus_to_exitcode(status) == 0, output.decode(errors="replace")
    return output.decode(errors="replace")


with tempfile.TemporaryDirectory() as directory:
    temp = Path(directory)
    bindir = temp / "bin"
    bindir.mkdir()
    state = temp / "state"
    state.mkdir()
    log = temp / "tmux.log"
    (bindir / "tmux").write_text(
        "#!/usr/bin/env bash\n"
        "printf '%s\\n' \"$*\" >>\"$TMUX1C_TEST_LOG\"\n"
        "case \"$1\" in\n"
        "  has-session) test -f \"$TMUX1C_TEST_STATE/${3#=}\" ;;\n"
        "  new-session)\n"
        "    while (($#)); do\n"
        "      if [[ $1 == -s ]]; then touch \"$TMUX1C_TEST_STATE/$2\"; break; fi\n"
        "      shift\n"
        "    done\n"
        "    printf '0\\n' >\"$TMUX1C_TEST_STATE/counter\"\n"
        "    printf '%%0\\n' ;;\n"
        "  split-window)\n"
        "    n=$(<\"$TMUX1C_TEST_STATE/counter\")\n"
        "    printf '%s\\n' \"$((n+1))\" >\"$TMUX1C_TEST_STATE/counter\"\n"
        "    printf '%%%s\\n' \"$((n+1))\" ;;\n"
        "esac\n"
    )
    (bindir / "tmux").chmod(0o755)
    for app in APPS:
        (bindir / app).write_text("#!/bin/sh\nexit 0\n")
        (bindir / app).chmod(0o755)
    project = temp / "project"
    project.mkdir()
    subprocess.run(["git", "init", "-q", str(project)], check=True)
    config = temp / ".config/tmux1c"
    config.mkdir(parents=True)
    (config / "first-run.done").touch()
    (config / "gpu").write_text("none\n")
    env = dict(os.environ, HOME=str(temp), PATH=f"{bindir}:{os.environ['PATH']}",
               TMUX1C_TEST_LOG=str(log), TMUX1C_TEST_STATE=str(state),
               TMUX1C_LOG=str(temp / "app log.txt"), TERM="xterm-256color")

    subprocess.run(["bash", "-n", str(ROOT / "bin/1c"), str(ROOT / "install.sh")], check=True)
    listed = subprocess.check_output(["bash", str(ROOT / "bin/1c"), "list"], env=env, text=True)
    assert len(listed.splitlines()) == len(PROFILES)
    for profile, expected_splits in PROFILES.items():
        log.write_text("")
        run_tty([profile], env, project)
        entries = log.read_text().splitlines()
        assert sum(row.startswith("split-window ") for row in entries) == expected_splits, profile
        assert f"status-left  1c / {profile} " in log.read_text(), profile
        assert "status-position top" in log.read_text(), profile
        assert "status-interval 1" in log.read_text(), profile
        if profile in ("ide", "agent-workshop", "model-lab"):
            assert any(row.endswith("-l pi") for row in entries), profile
        if profile == "ide":
            assert any(row == "select-pane -t %1" for row in entries), entries
            assert any(row == "send-keys -t %1 -l micro" for row in entries), entries
        if profile == "service-watch":
            assert any('lnav "$TMUX1C_LOG"' in row for row in entries), entries
        if profile in ("model-lab", "dashboard"):
            assert not any(row.endswith("-l nvtop") for row in entries), profile
        run_tty([profile], env, project)
        assert sum(row.startswith("new-session ") for row in log.read_text().splitlines()) == 1

    (config / "gpu").write_text("nvidia\n")
    (state / "1c-dashboard").unlink()
    log.write_text("")
    run_tty(["dashboard"], env, project)
    assert any(row.endswith("-l nvtop") for row in log.read_text().splitlines())

    log.write_text("")
    run_tty([], env, project, keys=b"\x1b[B\r")
    assert any("new-session -d -s 1c-agent-workshop " in row
               for row in log.read_text().splitlines()) is False  # session was reused
    assert any("attach-session -t 1c-agent-workshop" in row
               for row in log.read_text().splitlines())
    print("13 layouts, session reuse, arrow menu, and shell syntax passed")
