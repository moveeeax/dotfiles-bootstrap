# shellcheck shell=bash
# Stow-style symlink engine.
#
# A "package" is a directory whose internal layout mirrors the target tree
# (usually $HOME). link_package walks every regular file in the package and
# creates a symlink at the matching path under the target directory:
#
#   dotfiles/git/.gitconfig   ->   $HOME/.gitconfig
#   dotfiles/shell/.config/x  ->   $HOME/.config/x
#
# Design goals:
#   * Idempotent   — re-running never changes an already-correct link.
#   * Non-destructive — a real file in the way is backed up, never clobbered.
#   * Dry-run aware — DOT_DRY_RUN=1 prints actions without touching the disk.
#
# Requires lib/log.sh to be sourced first.

# Resolve the absolute path a symlink points at (portable; no readlink -f).
_link_target() {
  local link=$1 dest
  dest=$(readlink "$link") || return 1
  case "$dest" in
    /*) printf '%s\n' "$dest" ;;
    *)  printf '%s/%s\n' "$(cd "$(dirname "$link")" && pwd)" "$dest" ;;
  esac
}

# link_file SRC DEST
#   SRC must be absolute. Creates DEST as a symlink to SRC.
link_file() {
  local src=$1 dest=$2 cur
  local dry=${DOT_DRY_RUN:-0}

  if [ ! -e "$src" ]; then
    log_error "source missing: $src"
    return 1
  fi

  # Already linked correctly -> nothing to do.
  if [ -L "$dest" ]; then
    cur=$(_link_target "$dest" 2>/dev/null || true)
    if [ "$cur" = "$src" ]; then
      log_skip "${dest/#$HOME/~} already linked"
      return 0
    fi
  fi

  local parent
  parent=$(dirname "$dest")
  if [ ! -d "$parent" ]; then
    if [ "$dry" = 1 ]; then log_info "[dry-run] mkdir -p $parent"
    else mkdir -p "$parent"; fi
  fi

  # A real file/dir (not our symlink) is in the way -> back it up.
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    local backup="${dest}.dotbak"
    if [ "$dry" = 1 ]; then
      log_warn "[dry-run] would back up ${dest/#$HOME/~} -> ${backup##*/}"
    else
      mv "$dest" "$backup"
      log_warn "backed up existing ${dest/#$HOME/~} -> ${backup##*/}"
    fi
  fi

  if [ "$dry" = 1 ]; then
    log_info "[dry-run] ln -sfn $src $dest"
  else
    ln -sfn "$src" "$dest"
    log_ok "${dest/#$HOME/~} -> ${src/#$HOME/~}"
  fi
}

# link_package PKG_DIR TARGET_DIR
#   Links every regular file inside PKG_DIR into TARGET_DIR, preserving the
#   relative layout. Files named .gitkeep are ignored.
link_package() {
  local pkg=$1 target=$2 rel src dest count=0
  if [ ! -d "$pkg" ]; then
    log_error "not a package directory: $pkg"
    return 1
  fi
  pkg=$(cd "$pkg" && pwd)

  # -L so we also follow files that are themselves symlinks in the repo.
  while IFS= read -r -d '' src; do
    rel=${src#"$pkg"/}
    [ "$(basename "$rel")" = .gitkeep ] && continue
    dest="$target/$rel"
    link_file "$src" "$dest" || return 1
    count=$((count + 1))
  done < <(find "$pkg" -type f -print0 | sort -z)

  log_info "package $(basename "$pkg"): $count file(s)"
}
