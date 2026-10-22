#!/bin/bash
# Global Alt+Shift+N (hypr/shared-bindings.lua): paste the Nth pinned entry.
# Started detached by the bind, so Hyprland never waits on it: wl-copy needs
# the compositor to answer, and a compositor blocked on its child deadlocks.
# Copies the entry (nothing happens if there is no Nth pin), then sends
# Shift+Insert with explicit mods, like the stock universal paste, so the
# held Alt+Shift don't merge in.
#   paste-pinned.sh <1-9>
# PASTE_PINNED_DRY=1: copy only, print the dispatches instead of sending (tests).
set -u
# Children of Hyprland inherit a blocked SIGTERM, so the copy is capped with
# SIGKILL after 5 s instead of relying on a plain kill.
n=${1:-}
[[ $n =~ ^[1-9]$ ]] || exit 1
dir=$(dirname "$(readlink -f "$0")")
timeout -s KILL 5 "$dir/clipboard.sh" copy-pinned "$n" || exit 1
send() {
  local d="hl.dsp.send_key_state({ mods = \"SHIFT\", key = \"Insert\", state = \"$1\" })"
  if [[ ${PASTE_PINNED_DRY:-0} == 1 ]]; then echo "dispatch $d"; else timeout 3 hyprctl dispatch "$d" >/dev/null; fi
}
sleep 0.15
send down
sleep 0.05
send up
