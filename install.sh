#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$script_dir/lib/platform.sh"
install_dir=${TMUX1C_BIN_DIR:-"$HOME/.local/bin"}
data_dir=${TMUX1C_DATA_DIR:-"$HOME/.local/share/tmux1c"}
config_dir=${TMUX1C_CONFIG_DIR:-"$HOME/.config/tmux1c"}

supported_platforms
if ! detect_platform; then
  printf '%s\n' 'Unsupported environment; installation stopped before changing files.' >&2
  exit 1
fi
printf 'Detected: %s (%s)\n' "$PLATFORM_LABEL" "$PLATFORM"

mkdir -p "$install_dir" "$data_dir/lib"
install -m 0755 "$script_dir/bin/1c" "$install_dir/1c"
install -m 0755 "$script_dir/first-run.sh" "$data_dir/first-run.sh"
install -m 0644 "$script_dir/lib/platform.sh" "$data_dir/lib/platform.sh"
printf 'Installed 1c to %s/1c\n' "$install_dir"

case ":$PATH:" in
  *":$install_dir:"*) ;;
  *) printf 'Add this to your shell startup file, then open a new shell:\n  export PATH="%s:$PATH"\n' "$install_dir" ;;
esac

if [[ ! -f $config_dir/first-run.done ]]; then
  if [[ -t 0 && -t 1 ]]; then
    bash "$data_dir/first-run.sh"
  else
    printf '%s\n' 'First-run setup needs a terminal. Run 1c setup when ready.'
  fi
else
  printf '%s\n' 'Setup already completed. Run 1c setup to review dependencies again.'
fi
printf '%s\n' 'Run 1c to choose a workspace.'
