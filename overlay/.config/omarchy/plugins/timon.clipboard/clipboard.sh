#!/bin/bash
# timon.clipboard helper. Entries are always read from the history file by
# index, so clipboard text never shows up in a process list or a log.
#
#   clipboard.sh init                     create the data dir (user-only), import stock history once
#   clipboard.sh paste <index>            copy entry <index> and paste it (Shift+Insert)
#   clipboard.sh copy <index>             copy entry <index> only
#   clipboard.sh copy-pinned <n>          copy the n-th pinned entry (1-based, popup order);
#                                         used by the global Alt+Shift+N bind, which then
#                                         sends Shift+Insert itself with explicit modifiers
#   clipboard.sh send <index>             copy text entry <index> and send it to the phone (flux-cli clip)
#   clipboard.sh open <index>             open a URL in the browser, text in the editor, an image in the editor
#   clipboard.sh clear                    empty the live clipboard
#   clipboard.sh prune                    delete stored images no entry points to
#   clipboard.sh wipe                     resume Flux if we paused it, delete all stored history (used by uninstall)

set -uo pipefail
umask 077

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/timon.clipboard"
HISTORY="$DATA_DIR/history.json"
IMAGE_DIR="$DATA_DIR/images"
STOCK_HISTORY="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/clipboard-history.json"

field() { jq -er --argjson i "$1" ".[\$i].$2" "$HISTORY" 2>/dev/null; }

valid_index() { [[ ${1:-} =~ ^[0-9]+$ ]] && [[ -r $HISTORY ]]; }

copy_entry() {
  local i=$1 type mime path
  type=$(field "$i" type) || return 1
  case $type in
  text)
    jq -j --argjson i "$i" '.[$i].text' "$HISTORY" | wl-copy
    ;;
  image)
    mime=$(field "$i" mime) || mime=image/png
    path=$(field "$i" path) || return 1
    [[ -r $path ]] || return 1
    wl-copy --type "$mime" <"$path"
    ;;
  *) return 1 ;;
  esac
}

case "${1:-}" in
init)
  mkdir -p "$IMAGE_DIR"
  chmod 700 "$DATA_DIR" "$IMAGE_DIR"
  if [[ ! -e $HISTORY ]]; then
    # One-time import of the stock Omarchy history so nothing is lost.
    if [[ -r $STOCK_HISTORY ]] && jq -e 'type == "array"' "$STOCK_HISTORY" >/dev/null 2>&1; then
      jq '.' "$STOCK_HISTORY" >"$HISTORY.tmp" && mv "$HISTORY.tmp" "$HISTORY"
    else
      echo '[]' >"$HISTORY"
    fi
  fi
  [[ -e $DATA_DIR/state.json ]] || echo '{"private": false}' >"$DATA_DIR/state.json"
  chmod 600 "$HISTORY" "$DATA_DIR/state.json"
  ;;
paste | copy)
  valid_index "${2:-}" || exit 1
  copy_entry "$2" || exit 1
  [[ $1 == copy ]] && exit 0
  sleep 0.15
  wtype -M shift -k Insert -m shift 2>/dev/null || true
  ;;
copy-pinned)
  [[ ${2:-} =~ ^[1-9]$ && -r $HISTORY ]] || exit 1
  i=$(jq -r --argjson n "$2" '[to_entries[] | select(.value.pinned == true) | .key][$n - 1] // empty' "$HISTORY") || exit 1
  [[ -n $i ]] || exit 1
  copy_entry "$i" || exit 1
  ;;
send)
  valid_index "${2:-}" || exit 1
  [[ $(field "$2" type) == text ]] || exit 1
  command -v flux-cli >/dev/null || exit 1
  copy_entry "$2" || exit 1
  sleep 0.15
  # No TEXT argument: flux-cli reads the clipboard, so the text never shows up in argv.
  flux-cli clip >/dev/null 2>&1 || exit 1
  ;;
open)
  valid_index "${2:-}" || exit 1
  type=$(field "$2" type) || exit 1
  if [[ $type == image ]]; then
    path=$(field "$2" path) || exit 1
    [[ -r $path ]] && exec tensaku-edit "$path"
    exit 1
  fi
  text=$(jq -j --argjson i "$2" '.[$i].text' "$HISTORY") || exit 1
  url=$(grep -Eom1 'https?://[^[:space:]"'\''<>]+' <<<"$text" || true)
  if [[ -z $url && $text =~ ^[[:space:]]*([[:alnum:]][[:alnum:].-]+\.[[:alpha:]]{2,})(/[^[:space:]]*)?[[:space:]]*$ ]]; then
    url="https://${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
  fi
  [[ -n $url ]] && exec omarchy-launch-browser "$url"
  mkdir -p "$DATA_DIR/open"
  find "$DATA_DIR/open" -type f -mmin +60 -delete 2>/dev/null
  file=$(mktemp --tmpdir="$DATA_DIR/open" clip.XXXXXX.txt) || exit 1
  printf '%s' "$text" >"$file"
  exec omarchy-launch-editor "$file"
  ;;
clear)
  wl-copy --clear
  ;;
prune)
  [[ -r $HISTORY && -d $IMAGE_DIR ]] || exit 0
  keep=$(jq -r '.[] | select(.type == "image") | .path' "$HISTORY" 2>/dev/null) || exit 0
  for f in "$IMAGE_DIR"/*; do
    [[ -f $f ]] || continue
    grep -qxF "$f" <<<"$keep" || rm -f "$f"
  done
  ;;
wipe)
  # Never leave Flux paused behind when the plugin goes away.
  "$(dirname "$0")/flux-pause.sh" resume >/dev/null 2>&1
  rm -rf "$DATA_DIR" "${XDG_STATE_HOME:-$HOME/.local/state}/timon.clipboard"
  ;;
*)
  sed -n '2,12p' "$0" >&2
  exit 1
  ;;
esac
