#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/fake-bin" "$test_dir/home"
cat >"$test_dir/fake-bin/curl" <<'CURL'
#!/bin/sh
set -eu
for argument do
  case $argument in
    https://raw.githubusercontent.com/Decentricity/tmux1c/6e49a9a5d4b8b3931c433eb225baf795efb5c07d/*) relative_path=${argument#https://raw.githubusercontent.com/Decentricity/tmux1c/6e49a9a5d4b8b3931c433eb225baf795efb5c07d/} ;;
  esac
done
eval "output_path=\${$#}"
cp "$TMUX1C_TEST_ASSET_DIR/$relative_path" "$output_path"
CURL
chmod +x "$test_dir/fake-bin/curl"

HOME="$test_dir/home" TMUX1C_TEST_ASSET_DIR="$project_dir" \
  PATH="$test_dir/fake-bin:$PATH" sh "$project_dir/tmux1c.sh" >"$test_dir/out"
test -x "$test_dir/home/.local/bin/1c"
rg -q 'Supported: Ubuntu, Debian' "$test_dir/out"
rg -q 'First-run setup needs a terminal' "$test_dir/out"

cat >"$test_dir/fake-bin/curl" <<'CURL'
#!/bin/sh
set -eu
for argument do
  case $argument in
    https://raw.githubusercontent.com/Decentricity/tmux1c/6e49a9a5d4b8b3931c433eb225baf795efb5c07d/*) relative_path=${argument#https://raw.githubusercontent.com/Decentricity/tmux1c/6e49a9a5d4b8b3931c433eb225baf795efb5c07d/} ;;
  esac
done
eval "output_path=\${$#}"
printf 'tampered\n' >"$output_path"
CURL
if HOME="$test_dir/home" TMUX1C_TEST_ASSET_DIR="$project_dir" \
  PATH="$test_dir/fake-bin:$PATH" sh "$project_dir/tmux1c.sh" >"$test_dir/out" 2>&1; then
  printf '%s\n' 'Tampered download was accepted' >&2
  exit 1
fi
rg -q 'checksum mismatch' "$test_dir/out"
printf '%s\n' 'bootstrap checks passed'
