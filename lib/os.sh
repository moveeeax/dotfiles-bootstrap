# shellcheck shell=bash
# OS / distro detection. Sets DOT_OS (linux|macos) and DOT_DISTRO (debian|rhel|arch|alpine|macos|unknown).

detect_os() {
  case "$(uname -s)" in
    Linux)  DOT_OS=linux ;;
    Darwin) DOT_OS=macos ;;
    *)      DOT_OS=unknown ;;
  esac
  export DOT_OS
}

detect_distro() {
  detect_os
  if [ "$DOT_OS" = macos ]; then
    DOT_DISTRO=macos
  elif [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case " ${ID:-} ${ID_LIKE:-} " in
      *" debian "*|*" ubuntu "*) DOT_DISTRO=debian ;;
      *" rhel "*|*" fedora "*|*" centos "*) DOT_DISTRO=rhel ;;
      *" arch "*)   DOT_DISTRO=arch ;;
      *" alpine "*) DOT_DISTRO=alpine ;;
      *)            DOT_DISTRO=unknown ;;
    esac
  else
    DOT_DISTRO=unknown
  fi
  export DOT_DISTRO
}

# Map the distro to its package-install command; empty when unknown.
pkg_install_cmd() {
  detect_distro
  case "$DOT_DISTRO" in
    debian) echo "sudo apt-get install -y" ;;
    rhel)   echo "sudo dnf install -y" ;;
    arch)   echo "sudo pacman -S --noconfirm" ;;
    alpine) echo "sudo apk add" ;;
    macos)  echo "brew install" ;;
    *)      echo "" ;;
  esac
}
