# tmux1c

A small, terminal-first tmux preset launcher. `1c` opens a persistent tmux
workspace, reusing the same session next time you run the preset.

## Install

```bash
git clone https://github.com/Decentricity/tmux1c.git
cd tmux1c
bash install.sh
```

The installer checks for tmux, installs it through a detected package manager
if needed, and copies `1c` to `~/.local/bin`. It supports apt, dnf, pacman,
apk, zypper, Homebrew, and pkg. It prints a PATH instruction if that directory
isn't in your current PATH. It doesn't change your shell startup files.

Install `htop` and `nvtop` separately for the full dashboard; missing monitors
fall back to `top`. On machines without a GPU or with unsupported drivers,
`nvtop` may exit; the other panes and the clock continue working.

## Presets

| Command | Layout |
| --- | --- |
| `1c` | Interactive preset menu |
| `1c dashboard` | htop left; nvtop top right; regular shell bottom right |
| `1c focus` | htop left; regular shell right |
| `1c shell` | One regular tmux shell |
| `1c doctor` | Show installed/missing dependencies |
| `1c list` | List presets |

Every preset gets a **top tmux status bar** with date and a clock updating once
per second. It uses tmux's built-in time formatting, without a separate clock
process. The workspace starts in the current directory. Detach with `Ctrl-b d`
and resume using the same command; inside tmux, `1c dashboard` switches clients.

No system-wide tmux configuration is changed, and no shell aliases are needed.
The session names are `1c-dashboard`, `1c-focus`, and `1c-shell`.
