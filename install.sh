#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
install_dir=${TMUX1C_BIN_DIR:-"$HOME/.local/bin"}

install_tmux() {
  local -a elevate=()
  if [[ $(id -u) -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      elevate=(sudo)
    else
      printf '%s\n' 'tmux is missing and sudo is unavailable. Install tmux with your package manager.' >&2
      exit 1
    fi
  fi

  if command -v apt-get >/dev/null 2>&1; then
    "${elevate[@]}" apt-get install -y tmux
  elif command -v dnf >/dev/null 2>&1; then
    "${elevate[@]}" dnf install -y tmux
  elif command -v pacman >/dev/null 2>&1; then
    "${elevate[@]}" pacman -S --needed tmux
  elif command -v apk >/dev/null 2>&1; then
    "${elevate[@]}" apk add tmux
  elif command -v zypper >/dev/null 2>&1; then
    "${elevate[@]}" zypper install -y tmux
  elif command -v brew >/dev/null 2>&1; then
    brew install tmux
  elif command -v pkg >/dev/null 2>&1; then
    "${elevate[@]}" pkg install -y tmux
  else
    printf '%s\n' 'Unknown package manager. Install tmux manually and rerun install.sh.' >&2
    exit 1
  fi
  command -v tmux >/dev/null 2>&1 || {
    printf '%s\n' 'Package manager finished, but tmux is still missing from PATH.' >&2
    exit 1
  }
}

if ! command -v tmux >/dev/null 2>&1; then
  printf '%s\n' 'Installing tmux...'
  install_tmux
fi

mkdir -p "$install_dir"
install -m 0755 "$script_dir/bin/1c" "$install_dir/1c"
printf 'Installed 1c to %s/1c\n' "$install_dir"

case ":$PATH:" in
  *":$install_dir:"*) ;;
  *) printf 'Add this to your shell startup file, then open a new shell:\n  export PATH="%s:$PATH"\n' "$install_dir" ;;
esac
printf '%s\n' 'Try: 1c dashboard   (or just 1c for the menu)'
if ! command -v htop >/dev/null 2>&1 || ! command -v nvtop >/dev/null 2>&1; then
  printf '%s\n' 'Optional: install htop and nvtop for both dashboard monitors (top is the fallback).'
fi
