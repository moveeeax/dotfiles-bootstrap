#!/usr/bin/env bats
# End-to-end tests for bootstrap.sh against a throwaway $HOME.

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  FAKE_HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$FAKE_HOME"
  export NO_COLOR=1
}

run_bootstrap() {
  HOME="$FAKE_HOME" TARGET_DIR="$FAKE_HOME" bash "$REPO/bootstrap.sh" "$@"
}

@test "bootstrap links the base dotfiles into the target" {
  run run_bootstrap
  [ "$status" -eq 0 ]
  [ -L "$FAKE_HOME/.bashrc" ]
  [ -L "$FAKE_HOME/.gitconfig" ]
  [ -L "$FAKE_HOME/.vimrc" ]
  [ -L "$FAKE_HOME/.tmux.conf" ]
  [ -L "$FAKE_HOME/.aliases" ]
}

@test "bootstrap is safe to re-run (idempotent)" {
  run_bootstrap
  run run_bootstrap
  [ "$status" -eq 0 ]
  [[ "$output" == *"already linked"* ]]
  run find "$FAKE_HOME" -name '*.dotbak'
  [ -z "$output" ]
}

@test "bootstrap backs up a pre-existing real dotfile" {
  printf 'my old bashrc\n' > "$FAKE_HOME/.bashrc"
  run run_bootstrap
  [ "$status" -eq 0 ]
  [ -L "$FAKE_HOME/.bashrc" ]
  [ "$(cat "$FAKE_HOME/.bashrc.dotbak")" = "my old bashrc" ]
}

@test "bootstrap creates the git-ignored local override dir" {
  run run_bootstrap
  [ "$status" -eq 0 ]
  [ -d "$FAKE_HOME/.config/dotfiles" ]
  [ -f "$FAKE_HOME/.config/dotfiles/secrets.env" ]
}

@test "dry-run makes no changes" {
  run run_bootstrap --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$FAKE_HOME/.bashrc" ]
  [[ "$output" == *"dry-run"* ]]
}

@test "per-host override is linked when hosts/<hostname> matches" {
  host="$(hostname -s 2>/dev/null || hostname)"
  mkdir -p "$REPO/hosts/$host/shell"
  # Reuse the shipped example content for a real fixture.
  cp "$REPO/hosts/example-host/shell/.bashrc.local" "$REPO/hosts/$host/shell/.bashrc.local"
  run run_bootstrap
  [ "$status" -eq 0 ]
  [ -L "$FAKE_HOME/.bashrc.local" ]
  rm -rf "$REPO/hosts/$host"
}

@test "the linked bashrc is valid bash syntax" {
  run_bootstrap
  run bash -n "$FAKE_HOME/.bashrc"
  [ "$status" -eq 0 ]
}

@test "help exits cleanly" {
  run run_bootstrap --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}
