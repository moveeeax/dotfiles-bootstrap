# shellcheck shell=bash
# Minimal logging helpers. Colours only when stdout is a TTY and NO_COLOR is unset.

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  _c_reset=$'\033[0m'; _c_blue=$'\033[34m'; _c_green=$'\033[32m'
  _c_yellow=$'\033[33m'; _c_red=$'\033[31m'; _c_dim=$'\033[2m'
else
  _c_reset=; _c_blue=; _c_green=; _c_yellow=; _c_red=; _c_dim=
fi

log_info()  { printf '%s==>%s %s\n'  "$_c_blue"   "$_c_reset" "$*"; }
log_ok()    { printf '%s ok %s %s\n' "$_c_green"  "$_c_reset" "$*"; }
log_skip()  { printf '%sskip%s %s\n' "$_c_dim"    "$_c_reset" "$*"; }
log_warn()  { printf '%swarn%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }
log_error() { printf '%serr %s %s\n' "$_c_red"    "$_c_reset" "$*" >&2; }
