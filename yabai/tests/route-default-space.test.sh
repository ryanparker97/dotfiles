#!/usr/bin/env sh
# Stub test for route-default-space.sh. yabai is a PATH stub; the real
# /opt/homebrew/bin/yabai is unreachable (PATH is restricted and asserted).

here="$(CDPATH='' cd "$(dirname "$0")" && pwd -P)"
router="$here/../route-default-space.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
stub="$tmp/bin"
mkdir -p "$stub"

cat >"$stub/yabai" <<'STUB'
#!/bin/sh
echo "$*" >>"$STUB_DIR/calls"
mode="$(cat "$STUB_DIR/mode")"
case "$2 $3 $4" in
  "query --windows --window") cat "$STUB_DIR/window.json" ;;
  "query --spaces --space")
    awk -v l="$5" '$1==l{print "{\"index\":" $2 "}"; f=1} END{exit !f}' "$STUB_DIR/spaces" || exit 1 ;;
  window*)
    if [ "$4" = "--toggle" ]; then
      sed 's/"is-floating":true/"is-floating":false/' "$STUB_DIR/window.json" >"$STUB_DIR/w.new"
      mv "$STUB_DIR/w.new" "$STUB_DIR/window.json"
      exit 0
    fi
    [ "$mode" != fail ] || { echo "could not move window" >&2; exit 1; }
    [ "$mode" != stay ] || exit 0
    n="$(awk -v l="$5" '$1==l{print $2}' "$STUB_DIR/spaces")"
    sed "s/\"space\":[0-9]*/\"space\":$n/" "$STUB_DIR/window.json" >"$STUB_DIR/w.new"
    mv "$STUB_DIR/w.new" "$STUB_DIR/window.json"
    if [ "$mode" = float ]; then
      sed 's/"is-floating":false/"is-floating":true/' "$STUB_DIR/window.json" >"$STUB_DIR/w.new"
      mv "$STUB_DIR/w.new" "$STUB_DIR/window.json"
    fi ;;
esac
exit 0
STUB
chmod +x "$stub/yabai"

PATH="$stub:/usr/bin:/bin"
export PATH
STUB_DIR="$tmp/state"
YABAI_ROUTE_DELAY=0
YABAI_LOG="$tmp/log"
export STUB_DIR YABAI_ROUTE_DELAY YABAI_LOG
mkdir -p "$STUB_DIR"

if [ "$(command -v yabai)" != "$stub/yabai" ]; then
  echo "FAIL: yabai on PATH is not the stub ($(command -v yabai))"
  exit 1
fi
echo "ok   stub asserted: yabai -> $stub/yabai"

failures=0
check() { # NAME EXIT-STATUS
  if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1"; failures=$((failures + 1)); fi
}
has() { grep -q -- "$1" "$2"; }
no_move() { ! grep -q 'window 42 --space' "$STUB_DIR/calls"; }

# setup APP ROLE SPACE [noax]: fresh state, mode ok.
setup() {
  : >"$STUB_DIR/calls"
  : >"$YABAI_LOG"
  printf 'chat 1\nterminal 2\nweb 3\nnotes 4\ndefault 5\n' >"$STUB_DIR/spaces"
  echo ok >"$STUB_DIR/mode"
  ax='"has-ax-reference":true,'
  [ "${4:-}" != noax ] || ax=""
  printf '{"id":42,"app":"%s","title":"Doc","role":"%s","subrole":"AXStandardWindow","can-move":true,"can-resize":true,%s"is-floating":false,"space":%s}\n' \
    "$1" "$2" "$ax" "$3" >"$STUB_DIR/window.json"
}
run() { sh "$router" 42; }

# (a) uncategorised app on space 3 goes to default
setup Preview AXWindow 3; run; check "a: exit 0" $?
has "window 42 --space default" "$STUB_DIR/calls"; check "a: moved to default" $?
has "routed Preview wid=42 3 -> default(5)" "$YABAI_LOG"; check "a: log routed" $?

# (b) failed move: logged, no re-tile
setup Preview AXWindow 3; echo fail >"$STUB_DIR/mode"; run; check "b: exit 0" $?
has "move failed Preview wid=42 3 -> default(5): could not move window" "$YABAI_LOG"; check "b: log move failed" $?
! has "toggle float" "$STUB_DIR/calls"; check "b: no toggle float" $?

# (c) move leaves the window floating: re-tiled
setup Preview AXWindow 3; echo float >"$STUB_DIR/mode"; run; check "c: exit 0" $?
has "window 42 --toggle float" "$STUB_DIR/calls"; check "c: toggle float called" $?
has "re-tiled Preview wid=42" "$YABAI_LOG"; check "c: log re-tiled" $?

# (d) no default label: no move, one log line
setup Preview AXWindow 3
grep -v '^default ' "$STUB_DIR/spaces" >"$STUB_DIR/s2"; mv "$STUB_DIR/s2" "$STUB_DIR/spaces"
run; check "d: exit 0" $?
no_move; check "d: no --space call" $?
has "no Space labelled default" "$YABAI_LOG"; check "d: log no Space" $?

# (e) Firefox already on web: no move
setup Firefox AXWindow 3; run; check "e: exit 0" $?
no_move; check "e: no --space call" $?

# (f) missing has-ax-reference does not block routing
setup Preview AXWindow 3 noax; run
has "window 42 --space default" "$STUB_DIR/calls"; check "f: routed without has-ax-reference" $?

# (g) sheet: nothing but the query
setup Preview AXSheet 3; run; check "g: exit 0" $?
[ "$(wc -l <"$STUB_DIR/calls" | tr -d ' ')" = 1 ] && has "query --windows --window 42" "$STUB_DIR/calls"
check "g: only the query" $?

# (h) category app whose rule missed: moved to its label
setup Firefox AXWindow 5; run
has "window 42 --space web" "$STUB_DIR/calls"; check "h: moved to web" $?
has "rule missed: routed Firefox wid=42 5 -> web(3)" "$YABAI_LOG"; check "h: log rule missed" $?

if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
