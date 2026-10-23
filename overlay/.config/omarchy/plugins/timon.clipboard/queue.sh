#!/bin/bash
# timon.clipboard paste queue (1.17.0). Ctrl+click rows in the popup, then
# "Paste N in order": every Ctrl+V pastes the next item.
#
#   queue.sh start     items as a JSON array on stdin ({type:text,text} or
#                      {type:image,path,mime}); arms the queue
#   queue.sh next      Ctrl+V while armed: paste item k, then k+1 is next
#   queue.sh cancel    stop (popup button, watchdog); "cancel esc" also passes Esc on
#   queue.sh status    print {"pos","count"} or nothing
#
# How: while a queue is armed, Ctrl+V and Esc are bound at runtime with
# `hyprctl eval hl.bind(...)` (removed again with hl.unbind when the queue
# ends). Ctrl+V runs `next` detached: it puts item k on the clipboard
# (wl-copy) and sends Shift+Insert with explicit mods, like paste-pinned.sh /
# Omarchy's universal paste, so the held Ctrl doesn't merge in. Watching the
# clipboard for "was pasted" (wl-copy --paste-once) is not used: every
# clipboard watcher (this plugin, fluxd) reads each new copy and would use
# up the paste. Esc unbinds first, then sends Esc on to the window.
# A watchdog ends a queue after 15 min without a paste, and a Hyprland
# config reload (which drops runtime binds) leaves nothing stuck behind.
# Item contents live only in the user-only queue file, never in argv.
# QUEUE_DRY=1: print the hyprctl calls instead of running them (tests).
set -uo pipefail
umask 077
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/timon.clipboard"
Q="$DATA_DIR/queue.json"
LOCK="$DATA_DIR/queue.lock"
IDLE=${QUEUE_IDLE:-900}
me=$(readlink -f "$0")
mkdir -p "$DATA_DIR"

hypr() {
  if [[ ${QUEUE_DRY:-0} == 1 ]]; then echo "hyprctl $*"; else timeout 3 hyprctl "$@" >/dev/null 2>&1; fi
}
key() { hypr dispatch "hl.dsp.send_key_state({ mods = \"$1\", key = \"$2\", state = \"$3\" })"; }
notify() {
  # One notification, replaced in place for every step.
  local id
  [[ ${QUEUE_DRY:-0} == 1 ]] && { echo "notify $*"; return; }
  id=$(jq -r '.notify // 0' "$Q" 2>/dev/null || echo 0)
  id=$(notify-send -a Clipboard -p -r "${id:-0}" -t "${2:-6000}" "Paste queue" "$1" 2>/dev/null) || return 0
  [[ -s $Q && $id =~ ^[0-9]+$ ]] && jq --argjson id "$id" '.notify = $id' "$Q" >"$Q.tmp" && mv "$Q.tmp" "$Q"
}
bind_keys() {
  hypr eval "hl.bind(\"CTRL + V\", hl.dsp.exec_cmd(\"setsid -f $me next\"), { description = \"Clipboard paste queue: next\" })"
  hypr eval "hl.bind(\"Escape\", hl.dsp.exec_cmd(\"setsid -f $me cancel esc\"), { description = \"Clipboard paste queue: cancel\" })"
}
unbind_keys() {
  hypr eval 'hl.unbind("CTRL + V")'
  hypr eval 'hl.unbind("Escape")'
}
count() { jq -r '.items | length' "$Q" 2>/dev/null || echo 0; }
pos() { jq -r '.pos // 0' "$Q" 2>/dev/null || echo 0; }

copy_item() {
  local k=$1 type
  type=$(jq -r --argjson k "$k" '.items[$k].type' "$Q") || return 1
  if [[ $type == image ]]; then
    local path mime
    path=$(jq -r --argjson k "$k" '.items[$k].path' "$Q"); mime=$(jq -r --argjson k "$k" '.items[$k].mime // "image/png"' "$Q")
    [[ $path == "$DATA_DIR"/images/* && -r $path ]] || return 1
    timeout -s KILL 5 wl-copy --type "$mime" <"$path"
  else
    jq -j --argjson k "$k" '.items[$k].text' "$Q" | timeout -s KILL 5 wl-copy
  fi
}

finish() {
  unbind_keys
  rm -f "$Q" "$Q.tmp"
}

exec 9>"$LOCK"
case "${1:-}" in
start)
  flock -w 5 9 || exit 1
  [[ -s $Q ]] && unbind_keys
  items=$(jq -c '[.[] | select(type == "object" and ((.type == "text" and (.text | type == "string") and (.text | length > 0)) or (.type == "image" and (.path | type == "string"))))]' 2>/dev/null) || exit 1
  n=$(jq 'length' <<<"$items")
  [[ $n -gt 0 ]] || { rm -f "$Q"; exit 1; }
  jq -n --argjson items "$items" '{items: $items, pos: 0}' >"$Q" || exit 1
  bind_keys
  notify "$n items. Ctrl+V pastes 1 of $n. Esc cancels." 10000
  [[ ${QUEUE_DRY:-0} == 1 ]] || setsid -f "$me" watchdog </dev/null >/dev/null 2>&1
  ;;
next)
  flock -w 5 9 || exit 1
  [[ -s $Q ]] || { unbind_keys; exit 0; }
  n=$(count); k=$(pos)
  if (( k >= n )); then finish; exit 0; fi
  copy_item "$k" || true
  sleep 0.15
  key SHIFT Insert down; sleep 0.05; key SHIFT Insert up
  k=$((k + 1))
  if (( k >= n )); then
    notify "Pasted $k of $n. Done." 3000
    finish
  else
    jq --argjson k "$k" '.pos = $k' "$Q" >"$Q.tmp" && mv "$Q.tmp" "$Q"
    notify "Pasted $k of $n. Ctrl+V pastes $((k + 1)) next. Esc cancels."
  fi
  ;;
cancel)
  flock -w 5 9 || exit 1
  if [[ -s $Q ]]; then notify "Cancelled after $(pos) of $(count)." 3000; fi
  finish
  # Esc was ours only while the queue ran: hand this press on to the window.
  [[ ${2:-} == esc ]] && { key "" Escape down; key "" Escape up; }
  ;;
status)
  [[ -s $Q ]] && jq -c '{pos: (.pos // 0), count: (.items | length)}' "$Q"
  ;;
watchdog)
  exec 9>&-
  while sleep 30; do
    [[ -s $Q ]] || exit 0
    if (( $(date +%s) - $(stat -c %Y "$Q") > IDLE )); then "$me" cancel; exit 0; fi
  done
  ;;
*)
  sed -n '2,10p' "$0" >&2
  exit 1
  ;;
esac
