# tmux1c

Terminal workspaces you can open with one command. Each profile has a named
tmux session; start it again to reattach without losing panes or shell state.

## Install or update

~~~bash
git clone https://github.com/Decentricity/tmux1c.git
cd tmux1c
bash install.sh
1c
~~~

For an existing checkout, use `git pull` and rerun `bash install.sh`. The repo
is private; GitHub access is required to clone it. The installer checks for
tmux, installs it when absent through apt, dnf, pacman, apk, zypper, Homebrew,
or pkg, then installs the launcher at `~/.local/bin/1c`. If that location isn't
on PATH, it prints the line to add to your shell startup file.

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

The installer installs **tmux only**. Other apps are opt-in; profiles open
usable shell panes with guidance when an app is missing. `htop` and `nvtop`
fall back to `top`. File panes prefer `yazi`, then `mc`. Editor panes prefer
`micro`, then `vi`. Git status refreshes every ten seconds only while a profile
using it is open.

Some profiles use your own machine-specific commands: `pi`, `gcal`,
`telegramy`, `whatsappy`, `bookmarks`, `exa-search`, `living-caca`, and
`soloist`. Install and authenticate them separately; tmux1c doesn't copy
credentials or start them outside their selected profile. Pi is the only
agent command used for now.

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
