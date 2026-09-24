#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$script_dir/lib/platform.sh"
config_dir=${TMUX1C_CONFIG_DIR:-"$HOME/.config/tmux1c"}
check_only=false
case "${1:-}" in
  '') ;;
  --check) check_only=true ;;
  *) printf '%s\n' 'Usage: bash first-run.sh [--check]' >&2; exit 2 ;;
esac

supported_platforms
if ! detect_platform; then
  printf '%s\n' 'Unsupported environment. No packages were installed.' >&2
  exit 1
fi
printf 'Detected: %s (%s)\n' "$PLATFORM_LABEL" "$PLATFORM"
if [[ -d $HOME/.local/bin ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi
if [[ $check_only == false && ( ! -t 0 || ! -t 1 ) ]]; then
  printf '%s\n' 'Interactive terminal required. Use --check for a read-only diagnosis.' >&2
  exit 1
fi

ask_yes_no() {
  local answer
  while :; do
    printf '%s [y/N] ' "$1"
    IFS= read -r answer </dev/tty || return 1
    case "$answer" in
      y|Y|yes|YES|Yes) return 0 ;;
      n|N|no|NO|No|'') return 1 ;;
      *) printf '%s\n' 'Please answer y or n.' ;;
    esac
  done
}

gpu=none
if [[ -r $config_dir/gpu ]]; then
  IFS= read -r gpu <"$config_dir/gpu" || true
  [[ $gpu == nvidia ]] || gpu=none
fi
if [[ $check_only == false ]]; then
  if ask_yes_no 'Does this machine have an NVIDIA GPU?'; then
    gpu=nvidia
  else
    gpu=none
  fi
  mkdir -p -m 700 "$config_dir"
  printf '%s\n' "$gpu" >"$config_dir/gpu"
fi
if [[ $gpu == nvidia ]]; then
  printf '%s\n' 'NVIDIA selected: nvtop can be offered for installation.'
else
  printf '%s\n' 'No NVIDIA selected: GPU panes will stay ordinary blank shells.'
fi

# Each entry is a single package-manager transaction, only after consent.
deps=(tmux htop git micro mc lazygit lnav calcurse cava gh)
if [[ $PLATFORM == pacman ]]; then deps+=(yazi); fi
if [[ $gpu == nvidia && $PLATFORM != termux ]]; then deps+=(nvtop); fi
missing=()
for name in "${deps[@]}"; do
  if ! command -v "$name" >/dev/null 2>&1; then missing+=("$name"); fi
done

printf '\n%s\n' 'Package-manager dependencies:'
if ((${#missing[@]} == 0)); then
  printf '%s\n' '  All available.'
else
  for name in "${missing[@]}"; do
    printf '  missing: %-10s package: %s\n' "$name" "$(package_for "$name")"
  done
fi

manual=(ollama gcal telegramy whatsappy browsh bookmarks exa-search living-caca mplay-caca soloist)
if [[ $PLATFORM != pacman ]]; then manual+=(yazi); fi
printf '\n%s\n' 'Custom or separately configured commands (diagnosis only):'
manual_missing=0
for name in "${manual[@]}"; do
  if ! command -v "$name" >/dev/null 2>&1; then
    printf '  missing: %s\n' "$name"
    manual_missing=1
  fi
done
if ((manual_missing == 0)); then printf '%s\n' '  All available.'; fi
printf '%s\n' 'These need separate setup or credentials; no unofficial installer is run.'

pi_available=false
if ! command -v pi >/dev/null 2>&1; then
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    node_version=$(node -p 'process.versions.node' 2>/dev/null || true)
    if [[ $node_version =~ ^([0-9]+)\.([0-9]+)\. ]]; then
      major=${BASH_REMATCH[1]} minor=${BASH_REMATCH[2]}
      if ((major > 22 || (major == 22 && minor >= 19))); then
        pi_available=true
      fi
    fi
  fi
  if [[ $pi_available == true ]]; then
    printf '\n%s\n' 'missing: Pi (npm package @earendil-works/pi-coding-agent; Node meets the requirement).'
  else
    printf '\n%s\n' 'missing: Pi. Install Node.js 22.19+ and npm first, then rerun setup for an opt-in Pi install.'
  fi
fi

if [[ $check_only == true ]]; then exit 0; fi

failed=()
for name in "${missing[@]}"; do
  package=$(package_for "$name")
  if ask_yes_no "Install $name (package $package) now?"; then
    if install_package "$package"; then
      hash -r
      if command -v "$name" >/dev/null 2>&1; then
        printf 'Installed: %s\n' "$name"
      else
        printf 'Package finished but %s is not on PATH; check the package output.\n' "$name" >&2
        failed+=("$name")
      fi
    else
      printf 'Could not install %s; moving to the next item.\n' "$name" >&2
      failed+=("$name")
    fi
  else
    printf 'Skipped: %s\n' "$name"
    if [[ $name == tmux ]]; then
      printf '%s\n' 'tmux is required; setup stopped before optional installs.' >&2
      exit 1
    fi
  fi
  if [[ $name == tmux ]] && ! command -v tmux >/dev/null 2>&1; then
    printf '%s\n' 'tmux is still missing; setup stopped before optional installs.' >&2
    exit 1
  fi
done

if [[ $pi_available == true ]]; then
  if ask_yes_no 'Install Pi from its official npm package now?'; then
    mkdir -p "$HOME/.local/bin"
    if npm install -g --ignore-scripts --prefix "$HOME/.local" @earendil-works/pi-coding-agent; then
      if [[ -x $HOME/.local/bin/pi ]]; then
        printf '%s\n' 'Installed Pi. Authenticate and configure your preferred model separately.'
      else
        printf '%s\n' 'npm finished but Pi was not found under ~/.local/bin.' >&2
        failed+=(pi)
      fi
    else
      printf '%s\n' 'Could not install Pi; other setup choices remain intact.' >&2
      failed+=(pi)
    fi
  else
    printf '%s\n' 'Skipped: Pi'
  fi
fi

if ! command -v tmux >/dev/null 2>&1; then
  printf '%s\n' 'tmux is required. Run 1c setup again after installing it.' >&2
  exit 1
fi
touch "$config_dir/first-run.done"
if ((${#failed[@]})); then
  printf '\nSome installs failed: %s. Run 1c setup to retry.\n' "${failed[*]}"
else
  printf '\n%s\n' 'First-run setup complete. Run 1c to choose a profile.'
fi
printf '%s\n' 'Already-open tmux sessions keep their existing panes; recreate them after changing GPU preference.'
