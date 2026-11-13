#!/usr/bin/env sh
# Static test for yabairc: runs it against a PATH stub, never the real yabai.

here="$(CDPATH='' cd "$(dirname "$0")" && pwd -P)" || exit 1
yabairc="$here/../yabairc"
tmp="$(mktemp -d)" || exit 1
trap 'rm -rf "$tmp"' EXIT INT TERM

mkdir -p "$tmp/bin" "$tmp/apps/Firefox.app" "$tmp/apps/Notes.app"
calls="$tmp/calls"

cat >"$tmp/bin/yabai" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$STUB_CALLS"
n="${STUB_SPACES:-5}"
case "$*" in
  "-m query --spaces")
    i=1; out=
    while [ "$i" -le "$n" ]; do out="$out{\"index\":$i},"; i=$((i + 1)); done
    printf '[%s]\n' "${out%,}"
    ;;
  "-m query --spaces --space "*)
    for x; do :; done
    case "$x" in
      ''|*[!0-9]*)
        i=0
        for l in chat terminal web notes default; do
          i=$((i + 1))
          [ "$i" -le "$n" ] && [ "$x" = "$l" ] && exit 0
        done
        exit 1 ;;
      *) [ "$x" -le "$n" ] ;;
    esac
    ;;
  "-m space --create"|"-m rule --remove "*|"-m signal --remove "*)
    echo "stub: not permitted without the scripting addition" >&2
    exit 1 ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$tmp/bin/yabai"

# Only the stub dir plus system tools: the real /opt/homebrew/bin is not on PATH.
PATH="$tmp/bin:/usr/bin:/bin"
export PATH
fails=0
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }
ok() { printf 'ok: %s\n' "$1"; }

[ "$(command -v yabai)" = "$tmp/bin/yabai" ] || { echo "FAIL: yabai is not the stub"; exit 1; }

export YABAI_APP_DIRS="$tmp/apps" YABAI_LOG="$tmp/log" STUB_CALLS="$calls"
run() { : >"$calls"; : >"$YABAI_LOG"; sh "$yabairc" "$@" >"$tmp/out" 2>&1; }
count() { grep -c -- "$1" "$calls"; }

# (1) Load
run
if grep -q 'rule --add label=space-web-Firefox app=.* space=web' "$calls" \
  && [ "$(count 'rule --apply')" -eq 1 ] \
  && grep 'signal --add label=reload-rules-display_added' "$calls" | grep -q 'display_changed'; then
  ok "load adds rules, applies once, passes display_changed"
else fail "load"; fi

# (2) display re-run
run display_changed
if [ "$(count 'rule --apply')" -eq 0 ] && grep -q 'rule --add label=space-web-Firefox' "$calls"; then
  ok "display_changed skips rule --apply"
else fail "display_changed"; fi

# (3) fewer Spaces: failures are logged and the script still runs to the end
(STUB_SPACES=3; export STUB_SPACES; run)
if grep -q 'space --create needs the scripting addition' "$YABAI_LOG" \
  && grep -q "space 'notes' missing" "$YABAI_LOG" \
  && grep -q '^[0-9-]* [0-9:]* yabairc: FAILED' "$YABAI_LOG" \
  && grep -q 'signal --add label=reload-rules-display_removed' "$calls" \
  && [ "$(tail -n 1 "$calls")" = "-m rule --apply" ]; then
  ok "missing Spaces logged, script ran to the end"
else fail "missing Spaces"; fi

# (4) expected --remove failures are not logged
if grep -q -- '--remove' "$YABAI_LOG"; then fail "--remove logged"; else ok "no --remove lines in log"; fi

# stub guard: no call went anywhere but the stub
if [ "$(command -v yabai)" = "$tmp/bin/yabai" ]; then ok "stub still first on PATH"; else fail "PATH"; fi

[ "$fails" -eq 0 ]
