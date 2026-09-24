# tmux1c

Terminal workspaces you can open with one command. Each profile has a named
tmux session; start it again to reattach without losing panes or shell state.

## Install or update

~~~bash
curl -fsSL https://agent1c.ai/tmux1c.sh | sh
1c
~~~

Rerun the same command to update. The public installer verifies the SHA-256
checksums of the files it downloads before running the setup script. You can
also clone this repository and run `bash install.sh` directly. Supported
environments are
**Ubuntu, Debian, Fedora, Arch Linux, openSUSE Leap/Tumbleweed, Alpine Linux,
and Termux on Android**. The installer states the supported list and detected
environment before it changes files. Other environments are rejected.

The installer copies `1c` to `~/.local/bin` and runs the interactive first-run
script once. That script asks about NVIDIA graphics, lists missing packages,
and asks **separately** before installing each one using the detected distro's
package manager. It offers tmux if missing and htop for CPU-monitor panes.
Declining optional packages leaves usable shell panes. If installation was
noninteractive, run `1c setup` later; invoking a profile also triggers pending
first-run setup. `1c check` shows missing commands without making changes.
Run `1c setup` any time to review your choices again. If `~/.local/bin` isn't
on PATH, the installer prints the line to add to your shell startup file.

**No arguments opens the menu.** Use the up/down arrows and Enter to start a
profile. `q` or Esc quits; `j`/`k` also move the selection. Use `1c list` for
the exact command names and `1c doctor` to see which optional apps you have.

## Profiles

| Command | Layout |
| --- | --- |
| `1c ide` | File manager over small live Git status on left; tall `micro` over build/log shell in middle; Pi over htop on right |
| `1c agent-workshop` | Live Git status, big Pi pane, tests shell, general shell |
| `1c model-lab` | Pi with an Ollama model-status pane; nvtop and htop on right |
| `1c git-review` | Large lazygit, working shell, GitHub PR status |
| `1c service-watch` | Large lnav/log pane; service shell over htop |
| `1c meeting-desk` | Calendar, meeting notes, scratch shell, side shell |
| `1c comms` | Telegram and WhatsApp side by side; notes below |
| `1c research-desk` | Bookmarks, Browsh, notes, search shell |
| `1c terminal-cinema` | Living caca or video shell, queue shell, Soloist, cava |
| `1c travel-light` | Large shell and small file manager; no running monitors |
| `1c dashboard` | htop left; nvtop over shell on right |
| `1c focus` | htop left; shell right |
| `1c shell` | One full-size shell |

All profiles have a top tmux status bar with date and a clock updated once per
second, using tmux's built-in formatting rather than an extra process. They
start in the directory where you invoked `1c`. Detach with `Ctrl-b d`, or zoom
the selected pane temporarily with `Ctrl-b z`. From inside tmux, `1c PROFILE`
switches to that profile's session.

## Apps and fallbacks

First run offers the missing distro packages for tmux, htop, git, micro, mc,
lazygit, lnav, calcurse, cava, and gh. On Arch it also offers yazi. **nvtop is
offered only after a Yes to NVIDIA** on a regular Linux distro. If you answer
No, GPU panes stay blank terminal shells, even if nvtop happens to be installed.
CPU panes prefer `htop` and fall back to `top` if it is declined or unavailable.
File panes prefer `mc`, then `yazi`; editor panes prefer `micro`, then `vi`.
Packages that aren't in your configured distro repositories are reported as
failed, and setup moves to the next item. Git status refreshes every ten
seconds only while a profile using it is open.

Some profiles use your own machine-specific commands: `pi`, `gcal`,
`telegramy`, `whatsappy`, `bookmarks`, `exa-search`, `living-caca`, and
`soloist`. If Node.js 22.19+ and npm are already present, first run can offer
Pi's official npm package as a separate opt-in install. The remaining custom
commands are diagnosed without pretending they are distro packages. Install
and authenticate them separately; tmux1c doesn't copy credentials or start
them outside their selected profile. Pi is the only agent command used for now;
installing Pi itself does not recreate your local Ollama model and custom
wrapper configuration.

For IDE log-following or Service watch, set `TMUX1C_LOG` *when creating the
session*:

~~~bash
TMUX1C_LOG=/path/to/app.log 1c service-watch
TMUX1C_LOG=/path/to/build.log 1c ide
~~~

Without a log path, the pane stays a shell. Meeting, Comms, and Research notes
are local daily files under `~/.local/share/tmux1c/notes/`. If a session
already exists, `1c` resumes it with its original working directory and
environment; close that session with `tmux kill-session -t 1c-PROFILE` if you
want to recreate it with a different project or log path.
