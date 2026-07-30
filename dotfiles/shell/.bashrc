# .bashrc — managed by dotfiles-bootstrap. Do not edit directly.
# Machine-specific tweaks go in ~/.config/dotfiles/local.sh (git-ignored).

# Only run for interactive shells.
case $- in *i*) ;; *) return ;; esac

# History: large, de-duplicated, appended (not clobbered) across sessions.
HISTSIZE=100000
HISTFILESIZE=200000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize

# A readable prompt: user@host:cwd $
PS1='\[\033[32m\]\u@\h\[\033[0m\]:\[\033[34m\]\w\[\033[0m\]\$ '

# Sensible defaults.
export EDITOR=${EDITOR:-vim}
export PAGER=${PAGER:-less}
export LESS='-R'

# Load shared aliases.
[ -f "$HOME/.aliases" ] && . "$HOME/.aliases"

# Load per-machine extras and secrets kept out of git.
for extra in "$HOME/.config/dotfiles/local.sh" "$HOME/.config/dotfiles/secrets.env"; do
  [ -f "$extra" ] && . "$extra"
done
