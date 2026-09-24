#!/usr/bin/env bash
# Shared by install.sh and first-run.sh. Only the platforms named here are supported.

supported_platforms() {
  printf '%s\n' 'Supported: Ubuntu, Debian, Fedora, Arch Linux, openSUSE Leap/Tumbleweed, Alpine Linux, and Termux on Android.'
}

detect_platform() {
  PLATFORM=''
  PLATFORM_LABEL=''
  if [[ ${PREFIX:-} == */com.termux/files/usr || ${PREFIX:-} == */com.termux/*/files/usr ]]; then
    command -v pkg >/dev/null 2>&1 || return 1
    PLATFORM=termux
    PLATFORM_LABEL='Termux (Android)'
    return 0
  fi
  [[ $(uname -s) == Linux && -r /etc/os-release ]] || return 1
  local ID=''
  # Distro-provided release metadata; derivatives are intentionally not guessed.
  . /etc/os-release
  case "$ID" in
    ubuntu|debian)
      command -v apt-get >/dev/null 2>&1 || return 1
      PLATFORM=apt
      PLATFORM_LABEL=${NAME:-$ID}
      ;;
    fedora)
      command -v dnf >/dev/null 2>&1 || return 1
      PLATFORM=dnf
      PLATFORM_LABEL=Fedora
      ;;
    arch)
      command -v pacman >/dev/null 2>&1 || return 1
      PLATFORM=pacman
      PLATFORM_LABEL='Arch Linux'
      ;;
    opensuse|opensuse-leap|opensuse-tumbleweed)
      command -v zypper >/dev/null 2>&1 || return 1
      PLATFORM=zypper
      PLATFORM_LABEL=${PRETTY_NAME:-openSUSE}
      ;;
    alpine)
      command -v apk >/dev/null 2>&1 || return 1
      PLATFORM=apk
      PLATFORM_LABEL='Alpine Linux'
      ;;
    *) return 1 ;;
  esac
}

package_for() {
  case "$PLATFORM:$1" in
    pacman:gh) printf '%s\n' github-cli ;;
    *) printf '%s\n' "$1" ;;
  esac
}

install_package() {
  local package=$1
  local -a elevate=()
  if [[ $PLATFORM != termux && $(id -u) -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      elevate=(sudo)
    else
      printf '%s\n' 'Cannot install: root access or sudo is required on this distro.' >&2
      return 1
    fi
  fi
  case "$PLATFORM" in
    apt)
      if ! "${elevate[@]}" apt-get install -y "$package"; then
        # A fresh OS image may not have populated package indexes yet.
        if [[ ${APT_REFRESHED:-no} == no ]]; then
          APT_REFRESHED=yes
          "${elevate[@]}" apt-get update || return 1
          "${elevate[@]}" apt-get install -y "$package"
        else
          return 1
        fi
      fi
      ;;
    dnf) "${elevate[@]}" dnf install -y "$package" ;;
    pacman) "${elevate[@]}" pacman -S --needed --noconfirm "$package" ;;
    zypper) "${elevate[@]}" zypper --non-interactive install "$package" ;;
    apk) "${elevate[@]}" apk add "$package" ;;
    termux) pkg install -y "$package" ;;
    *) return 1 ;;
  esac
}
