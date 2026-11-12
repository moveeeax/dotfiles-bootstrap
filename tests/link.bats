#!/usr/bin/env bats
# Unit tests for the stow-style symlink engine (lib/link.sh).

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  NO_COLOR=1
  # shellcheck source=../lib/log.sh
  source "$REPO/lib/log.sh"
  # shellcheck source=../lib/link.sh
  source "$REPO/lib/link.sh"

  SRCDIR="$BATS_TEST_TMPDIR/pkg"
  TARGET="$BATS_TEST_TMPDIR/home"
  mkdir -p "$SRCDIR" "$TARGET"
}

@test "link_file creates a symlink pointing at the source" {
  echo hello > "$SRCDIR/.foo"
  run link_file "$SRCDIR/.foo" "$TARGET/.foo"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/.foo" ]
  [ "$(readlink "$TARGET/.foo")" = "$SRCDIR/.foo" ]
  [ "$(cat "$TARGET/.foo")" = "hello" ]
}

@test "link_file is idempotent — a correct link is skipped, not recreated" {
  echo hi > "$SRCDIR/.bar"
  link_file "$SRCDIR/.bar" "$TARGET/.bar"
  run link_file "$SRCDIR/.bar" "$TARGET/.bar"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already linked"* ]]
}

@test "link_file backs up a real file that is in the way" {
  echo new > "$SRCDIR/.baz"
  echo old > "$TARGET/.baz"          # pre-existing REAL file
  run link_file "$SRCDIR/.baz" "$TARGET/.baz"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/.baz" ]
  [ "$(cat "$TARGET/.baz.dotbak")" = "old" ]   # original preserved
  [ "$(cat "$TARGET/.baz")" = "new" ]          # link now serves new content
}

@test "link_file repoints a stale symlink without leaving a backup" {
  echo real > "$SRCDIR/.q"
  ln -s /nonexistent/old "$TARGET/.q"   # stale link
  run link_file "$SRCDIR/.q" "$TARGET/.q"
  [ "$status" -eq 0 ]
  [ "$(readlink "$TARGET/.q")" = "$SRCDIR/.q" ]
  [ ! -e "$TARGET/.q.dotbak" ]
}

@test "link_file creates missing parent directories" {
  mkdir -p "$SRCDIR/.config/app"
  echo cfg > "$SRCDIR/.config/app/conf"
  run link_file "$SRCDIR/.config/app/conf" "$TARGET/.config/app/conf"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/.config/app/conf" ]
}

@test "link_file dry-run touches nothing" {
  echo x > "$SRCDIR/.dry"
  DOT_DRY_RUN=1 run link_file "$SRCDIR/.dry" "$TARGET/.dry"
  [ "$status" -eq 0 ]
  [ ! -e "$TARGET/.dry" ]
  [[ "$output" == *"dry-run"* ]]
}

@test "link_package links every file preserving layout and skips .gitkeep" {
  mkdir -p "$SRCDIR/.config/nested"
  echo a > "$SRCDIR/.rc"
  echo b > "$SRCDIR/.config/nested/file"
  : > "$SRCDIR/.config/.gitkeep"
  run link_package "$SRCDIR" "$TARGET"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/.rc" ]
  [ -L "$TARGET/.config/nested/file" ]
  [ ! -e "$TARGET/.config/.gitkeep" ]
}

@test "link_package is idempotent across a second run" {
  echo a > "$SRCDIR/.one"
  echo b > "$SRCDIR/.two"
  link_package "$SRCDIR" "$TARGET"
  run link_package "$SRCDIR" "$TARGET"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already linked"* ]]
  # No .dotbak files should ever appear from linking our own links.
  run find "$TARGET" -name '*.dotbak'
  [ -z "$output" ]
}

@test "link_file reports an error for a missing source" {
  run link_file "$SRCDIR/does-not-exist" "$TARGET/x"
  [ "$status" -ne 0 ]
}

# --- prune_links ------------------------------------------------------------

@test "prune_links removes a dangling link into the dotfiles dir" {
  echo a > "$SRCDIR/.gone"
  link_file "$SRCDIR/.gone" "$TARGET/.gone"
  rm "$SRCDIR/.gone"                       # tracked file deleted from the repo
  run prune_links "$TARGET" "$SRCDIR" "$SRCDIR"
  [ "$status" -eq 0 ]
  [ ! -L "$TARGET/.gone" ]
  [[ "$output" == *"pruned $TARGET/.gone (dangling -> .gone)"* ]]
}

@test "prune_links restores the .dotbak saved when the link was made" {
  echo new > "$SRCDIR/.rc"
  echo old > "$TARGET/.rc"
  link_file "$SRCDIR/.rc" "$TARGET/.rc"
  rm "$SRCDIR/.rc"
  run prune_links "$TARGET" "$SRCDIR" "$SRCDIR"
  [ "$status" -eq 0 ]
  [ ! -L "$TARGET/.rc" ]
  [ "$(cat "$TARGET/.rc")" = "old" ]
  [ ! -e "$TARGET/.rc.dotbak" ]
  [[ "$output" == *"restored"* ]]
}

@test "prune_links leaves dangling links that point outside the dotfiles dir" {
  ln -s /nonexistent/elsewhere "$TARGET/.foreign"
  run prune_links "$TARGET" "$SRCDIR" "$SRCDIR"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/.foreign" ]
}

@test "prune_links keeps links that still resolve" {
  echo a > "$SRCDIR/.keep"
  link_file "$SRCDIR/.keep" "$TARGET/.keep"
  run prune_links "$TARGET" "$SRCDIR" "$SRCDIR"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/.keep" ]
  [[ "$output" == *"prune: 0 stale link(s)"* ]]
}

@test "prune_links dry-run reports but touches nothing" {
  echo new > "$SRCDIR/.d"
  echo old > "$TARGET/.d"
  link_file "$SRCDIR/.d" "$TARGET/.d"
  rm "$SRCDIR/.d"
  DOT_DRY_RUN=1 run prune_links "$TARGET" "$SRCDIR" "$SRCDIR"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/.d" ]
  [ "$(cat "$TARGET/.d.dotbak")" = "old" ]
  [[ "$output" == *"[dry-run] would prune"* ]]
  [[ "$output" == *"[dry-run] would restore"* ]]
}

@test "prune_links scans ~/.config/<app> and parents of tracked files" {
  mkdir -p "$SRCDIR/.config/app" "$SRCDIR/.local/share/tool"
  echo a > "$SRCDIR/.config/app/old"
  echo b > "$SRCDIR/.local/share/tool/old"
  echo c > "$SRCDIR/.local/share/tool/kept"
  link_package "$SRCDIR" "$TARGET"
  rm "$SRCDIR/.config/app/old" "$SRCDIR/.local/share/tool/old"
  run prune_links "$TARGET" "$SRCDIR" "$SRCDIR"
  [ "$status" -eq 0 ]
  [ ! -L "$TARGET/.config/app/old" ]
  [ ! -L "$TARGET/.local/share/tool/old" ]
  [ -L "$TARGET/.local/share/tool/kept" ]
  [[ "$output" == *"prune: 2 stale link(s)"* ]]
}

@test "prune_links does not walk directories outside its scan roots" {
  mkdir -p "$TARGET/projects/deep"
  ln -s "$SRCDIR/.missing" "$TARGET/projects/deep/.missing"
  run prune_links "$TARGET" "$SRCDIR" "$SRCDIR"
  [ "$status" -eq 0 ]
  [ -L "$TARGET/projects/deep/.missing" ]
}
