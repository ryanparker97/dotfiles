#!/usr/bin/env sh
# Guarded default Space router for yabai.
# Routes normal manageable windows to their category Space (when the yabai rule
# missed) or to the Space labeled "default", without forcing focus to another
# Space. Every outcome that matters is logged. If macOS refuses the move, the
# window stays where it opened (and is re-tiled if it became floating).
# Always exits 0: a yabai signal must never fail loudly.

set -eu

script_dir="$(CDPATH='' cd "$(dirname "$0")" && pwd -P)" || exit 0
YABAI_DIR="${YABAI_DIR:-$script_dir}"
. "$YABAI_DIR/app-categories.sh"

YABAI_LOG="${YABAI_LOG:-${HOME:-/tmp}/Library/Logs/yabai-config.log}"
delay="${YABAI_ROUTE_DELAY:-0.2}"

log() {
  printf '%s router: %s\n' "$(date '+%F %T')" "$*" >>"$YABAI_LOG"
}

wid="${1:-}"
[ -n "$wid" ] || exit 0

# Window properties, set by load_window.
app="" title="" role="" subrole="" can_move="" can_resize="" has_ax="" is_floating="" space=""

# Query one window and set the variables above. Returns 1 when the window is
# gone or the JSON does not parse. Strips U+200E/U+200F: some apps (WhatsApp)
# prefix their name with a left-to-right mark, which would otherwise defeat the
# exact-match category lookup.
load_window() {
  _json="$(yabai -m query --windows --window "$1" 2>/dev/null)" || return 1
  [ -n "$_json" ] || return 1
  _fields="$(printf '%s' "$_json" | /usr/bin/python3 -c '
import json, sys
d = json.load(sys.stdin)
def f(k):
    v = d.get(k, "")
    if v is None:
        return ""
    if isinstance(v, bool):
        return "true" if v else "false"
    v = str(v)
    for c in ("‎", "‏"):
        v = v.replace(c, "")
    return v.replace("\n", " ").replace("\r", " ").replace("\t", " ")
for k in ("app", "title", "role", "subrole", "can-move", "can-resize",
          "has-ax-reference", "is-floating", "space"):
    print(f(k))
')" || return 1
  {
    read -r app
    read -r title
    read -r role
    read -r subrole
    read -r can_move
    read -r can_resize
    read -r has_ax
    read -r is_floating
    read -r space
  } <<FIELDS
$_fields
FIELDS
}

# Print the index of Space LABEL, or return 1 when it does not exist.
space_index() {
  _sjson="$(yabai -m query --spaces --space "$1" 2>/dev/null)" || return 1
  printf '%s' "$_sjson" | /usr/bin/python3 -c '
import json, sys
print(json.load(sys.stdin)["index"])
'
}

# Print chat/terminal/web/notes for an exact match in the category lists,
# otherwise default.
category_label() {
  if printf '%s\n' "$YABAI_CHAT_APPS" | grep -Fxq "$1"; then echo chat
  elif printf '%s\n' "$YABAI_TERMINAL_APPS" | grep -Fxq "$1"; then echo terminal
  elif printf '%s\n' "$YABAI_WEB_APPS" | grep -Fxq "$1"; then echo web
  elif printf '%s\n' "$YABAI_NOTES_APPS" | grep -Fxq "$1"; then echo notes
  else echo default
  fi
}

# Put a window back into the tiling layout if it is floating now. Only called
# for windows that were tiled when they were created.
retile() {
  load_window "$wid" || return 0
  [ "$is_floating" = "true" ] || return 0
  if out="$(yabai -m window "$wid" --toggle float 2>&1)"; then
    log "re-tiled $app wid=$wid"
  else
    log "re-tile failed $app wid=$wid: $out"
  fi
}

# Give yabai a moment to finish populating properties for newly-created windows.
sleep "$delay"

load_window "$wid" || exit 0

case "$app" in
  System\ Settings|System\ Preferences) exit 0 ;;
esac

# Do not move preference/settings panels even if an app exposes them as a
# standard window.
case "$title" in
  Preferences|Settings|*\ Preferences|*\ Settings) exit 0 ;;
esac

# Only route normal, safe, manageable application windows.
[ "$role" = "AXWindow" ] || exit 0
[ "$subrole" = "AXStandardWindow" ] || exit 0
[ "$can_move" = "true" ] || exit 0
[ "$can_resize" = "true" ] || exit 0
[ "$has_ax" != "false" ] || exit 0
if [ "$is_floating" = "true" ]; then
  log "skip $app wid=$wid: floating"
  exit 0
fi

label="$(category_label "$app")"
old="$space"

if ! n="$(space_index "$label")"; then
  log "no Space labelled $label; leaving $app wid=$wid on space $old"
  exit 0
fi

[ "$old" != "$n" ] || exit 0

if ! out="$(yabai -m window "$wid" --space "$label" 2>&1)"; then
  log "move failed $app wid=$wid $old -> $label($n): $out"
  retile
  exit 0
fi

sleep "$delay"
prefix=""
[ "$label" = default ] || prefix="rule missed: "

if ! load_window "$wid"; then
  log "${prefix}$app wid=$wid vanished after move"
  exit 0
fi

if [ "$space" = "$old" ]; then
  log "${prefix}move reported ok but window still on $old ($app wid=$wid -> $label($n))"
fi
if [ "$is_floating" = "true" ]; then
  retile
elif [ "$space" != "$old" ]; then
  log "${prefix}routed $app wid=$wid $old -> $label($n)"
fi
exit 0
