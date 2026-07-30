# dotfiles-bootstrap

[![ci](https://github.com/moveeeax/dotfiles-bootstrap/actions/workflows/ci.yml/badge.svg)](https://github.com/moveeeax/dotfiles-bootstrap/actions/workflows/ci.yml)
[![shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](bootstrap.sh)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> Rebuild my entire dev environment on a fresh machine with one command.

Version-controlled dotfiles plus an **idempotent** bootstrap: symlink the configs
into place, install the toolset with Ansible, and keep per-host tweaks and secrets
out of git. Safe to run on day one and every day after.

```bash
git clone https://github.com/moveeeax/dotfiles-bootstrap ~/.dotfiles
cd ~/.dotfiles && ./bootstrap.sh
```

## What it does

- **Symlinks dotfiles** (`shell`, `git`, `editor`, `tmux`) into `$HOME`, GNU-stow style —
  the repo layout mirrors your home directory, so `dotfiles/git/.gitconfig` → `~/.gitconfig`.
- **Never clobbers.** A real file already in the way is moved to `<file>.dotbak` before linking.
- **Is idempotent.** Re-running leaves correct links untouched and creates no new backups.
- **Installs the toolset** via an Ansible playbook (`--packages`) that is itself idempotent.
- **Keeps secrets out of git.** `~/.config/dotfiles/` is git-ignored and sourced by the shell rc;
  per-host overrides live under `hosts/<hostname>/` and win over the base config.

## How it works

The engine is a small stow-style linker in [`lib/link.sh`](lib/link.sh). For each file in a
"package" directory it computes the path relative to the package root and creates the matching
symlink under the target (`$HOME` by default):

```
dotfiles/shell/.bashrc   ->   ~/.bashrc
dotfiles/git/.gitconfig  ->   ~/.gitconfig
```

The one detail that makes re-runs safe: before linking, `link_file` checks whether the target is
**already the symlink we want** (skip), a **stale symlink** (repoint, no backup), or a **real file**
(back up to `.dotbak`, then link). That three-way check is what the test suite pins down.

Layout:

```
bootstrap.sh          # entry point — parses flags, links packages, runs Ansible
lib/{log,os,link}.sh  # logging, OS detection, the symlink engine
dotfiles/<pkg>/…      # tracked configs, one package per tool
hosts/<hostname>/…    # per-host overrides, linked after (and thus over) the base
ansible/              # playbook + toolset list (group_vars/all.yml)
tests/*.bats          # Bats unit + end-to-end tests
```

## Usage

```console
$ ./bootstrap.sh --dry-run
==> dotfiles: /home/me/.dotfiles
==> target:   /home/me
==> os:       linux (debian)
warn dry-run: no changes will be made
==> [dry-run] ln -sfn …/dotfiles/git/.gitconfig /home/me/.gitconfig
==> package git: 1 file(s)
…
==> done.

$ ./bootstrap.sh                 # link everything for real
$ ./bootstrap.sh --packages      # also run the Ansible playbook
$ ./bootstrap.sh --target /tmp/x # link into a sandbox instead of $HOME
```

Flags: `--dry-run`, `--packages`, `--target DIR`, `--help`. Honors `DOTFILES_DIR`,
`TARGET_DIR`, and `NO_COLOR`.

### Per-host overrides & secrets

- Copy `hosts/example-host/` to `hosts/$(hostname -s)/` and drop machine-specific config there.
- Put identity, tokens, and PATH tweaks in `~/.config/dotfiles/` (git-ignored). See
  [`examples/`](examples) for `local.sh` and `gitconfig.local` templates.

## Development

```bash
bats tests/                       # run the suite (17 tests)
shellcheck bootstrap.sh lib/*.sh  # lint
```

CI runs shellcheck, the Bats suite, a twice-through idempotency check, and an Ansible
syntax-check on every push.

## License

MIT — see [LICENSE](LICENSE).
