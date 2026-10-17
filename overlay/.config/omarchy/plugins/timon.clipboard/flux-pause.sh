#!/bin/bash
# timon.clipboard: pause Flux's clipboard syncing while private mode is on.
#
#   flux-pause.sh sync     match private mode: Flux paused while it is on, running while it is off
#   flux-pause.sh pause    stop fluxd.service if it runs, and remember that we stopped it
#   flux-pause.sh resume   start fluxd.service again, but only if we stopped it
#   flux-pause.sh status   print paused | running | off | absent
#
# fluxd (Flux) reads the clipboard with its own `wl-paste --watch` and sends
# every copy to the phone. Pausing means stopping its systemd user unit;
# nothing of Flux itself (binary, unit file, config) is changed, so a Flux
# update cannot undo this. The marker file in ~/.local/state/timon.clipboard
# records that we stopped it; without the marker we never start Flux. If
# fluxd.service does not exist, every command is a silent no-op.

set -uo pipefail
umask 077

UNIT=${TIMON_CLIPBOARD_FLUX_UNIT:-fluxd.service}
STATE_FILE="${XDG_DATA_HOME:-$HOME/.local/share}/timon.clipboard/state.json"
MARK_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/timon.clipboard"
MARK="$MARK_DIR/flux-paused"
# `flux-cli off` leaves this marker; then Flux stays off whatever we did.
FLUX_OFF="${XDG_CONFIG_HOME:-$HOME/.config}/flux/off"

sc() { systemctl --user "$@" 2>/dev/null; }
installed() { [[ $(sc show -p LoadState --value "$UNIT") == loaded ]]; }
active() { sc is-active --quiet "$UNIT"; }
private_on() { [[ -r $STATE_FILE ]] && jq -e '.private == true' "$STATE_FILE" >/dev/null 2>&1; }

pause() {
  installed || return 0
  active || return 0
  mkdir -p "$MARK_DIR" && chmod 700 "$MARK_DIR"
  date +%s >"$MARK"
  if ! sc stop "$UNIT"; then
    rm -f "$MARK"
    return 1
  fi
}

resume() {
  [[ -e $MARK ]] || return 0
  if ! installed || [[ -e $FLUX_OFF ]]; then
    rm -f "$MARK"
    return 0
  fi
  # On failure the marker stays, so the next sync (toggle or shell start) retries.
  sc start "$UNIT" && rm -f "$MARK"
}

status() {
  if ! installed; then
    echo absent
  elif active; then
    echo running
  elif [[ -e $MARK ]]; then
    echo paused
  else
    echo off
  fi
}

cmd=${1:-}
case $cmd in
sync | pause | resume)
  mkdir -p "$MARK_DIR" && chmod 700 "$MARK_DIR"
  exec 9>"$MARK_DIR/.flux.lock"
  flock -w 30 9 || exit 1
  rc=0
  if [[ $cmd == sync ]]; then
    if private_on; then pause || rc=1; else resume || rc=1; fi
  else
    $cmd || rc=1
  fi
  status
  exit $rc
  ;;
status) status ;;
*)
  sed -n '2,8p' "$0" >&2
  exit 1
  ;;
esac
