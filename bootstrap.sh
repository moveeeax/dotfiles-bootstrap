#!/usr/bin/env bash
#
# bootstrap.sh — reproduce my dev environment on a fresh machine, idempotently.
#
#   git clone https://github.com/moveeeax/dotfiles-bootstrap ~/.dotfiles
#   cd ~/.dotfiles && ./bootstrap.sh
#
# It is safe to re-run: symlinks that are already correct are left untouched
# and a real file in the way is backed up to <file>.dotbak, never overwritten.
#
set -euo pipefail

DOTFILES_DIR=${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
TARGET_DIR=${TARGET_DIR:-$HOME}
export DOT_DRY_RUN=0
DO_PACKAGES=0

# shellcheck source=lib/log.sh
. "$DOTFILES_DIR/lib/log.sh"
# shellcheck source=lib/os.sh
. "$DOTFILES_DIR/lib/os.sh"
# shellcheck source=lib/link.sh
. "$DOTFILES_DIR/lib/link.sh"

usage() {
  cat <<EOF
Usage: ./bootstrap.sh [options]

  --dry-run       Show what would change without touching the filesystem.
  --packages      Also run the Ansible playbook to install the toolset.
  --target DIR    Link into DIR instead of \$HOME (used by tests).
  -h, --help      Show this help.

Environment: DOTFILES_DIR, TARGET_DIR, NO_COLOR are all honoured.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DOT_DRY_RUN=1 ;;
    --packages) DO_PACKAGES=1 ;;
    --target)   TARGET_DIR=$2; shift ;;
    --target=*) TARGET_DIR=${1#*=} ;;
    -h|--help)  usage; exit 0 ;;
    *) log_error "unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

detect_distro
log_info "dotfiles: $DOTFILES_DIR"
log_info "target:   $TARGET_DIR"
log_info "os:       $DOT_OS ($DOT_DISTRO)"
[ "$DOT_DRY_RUN" = 1 ] && log_warn "dry-run: no changes will be made"

# 1) Link the base packages, in name order.
if [ -d "$DOTFILES_DIR/dotfiles" ]; then
  for pkg in "$DOTFILES_DIR"/dotfiles/*/; do
    [ -d "$pkg" ] || continue
    link_package "$pkg" "$TARGET_DIR"
  done
else
  log_warn "no dotfiles/ directory found"
fi

# 2) Per-host overrides win over the base — linked last so they replace it.
host=$(hostname -s 2>/dev/null || hostname)
host_dir="$DOTFILES_DIR/hosts/$host"
if [ -d "$host_dir" ]; then
  log_info "applying host overrides for '$host'"
  for pkg in "$host_dir"/*/; do
    [ -d "$pkg" ] || continue
    link_package "$pkg" "$TARGET_DIR"
  done
else
  log_skip "no host overrides for '$host' (hosts/$host absent)"
fi

# 3) Local, un-tracked extras: ~/.config/dotfiles/ is git-ignored and sourced
#    by the shell rc, so secrets and machine-specific tweaks stay out of git.
localcfg="$TARGET_DIR/.config/dotfiles"
if [ "$DOT_DRY_RUN" = 1 ]; then
  log_info "[dry-run] ensure $localcfg (for local overrides / secrets)"
else
  mkdir -p "$localcfg"
  [ -f "$localcfg/secrets.env" ] || : > "$localcfg/secrets.env"
  chmod 700 "$localcfg"; chmod 600 "$localcfg/secrets.env"
  log_ok "local override dir ready: ${localcfg/#$HOME/~}"
fi

# 4) Optional: install the documented toolset with Ansible.
if [ "$DO_PACKAGES" = 1 ]; then
  if command -v ansible-playbook >/dev/null 2>&1; then
    log_info "running Ansible playbook"
    if [ "$DOT_DRY_RUN" = 1 ]; then
      ansible-playbook -i "$DOTFILES_DIR/ansible/inventory.ini" \
        "$DOTFILES_DIR/ansible/playbook.yml" --check
    else
      ansible-playbook -i "$DOTFILES_DIR/ansible/inventory.ini" \
        "$DOTFILES_DIR/ansible/playbook.yml"
    fi
  else
    log_warn "ansible-playbook not found — skipping package install."
    log_warn "install it (see ansible/README) then re-run: ./bootstrap.sh --packages"
  fi
else
  log_skip "package install (pass --packages to run Ansible)"
fi

log_info "done."
