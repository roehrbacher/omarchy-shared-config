#!/usr/bin/env bash
# Staging install skips the idle wait. Lock, game, and a requested media wait still hold.
# The default gate (shell restart) still waits for idle. Install never restarts the shell.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
GATE=$here/overlay/.local/bin/omarchy-safe-gate
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
mkdir -p "$tmp/bin"
cat >"$tmp/bin/qs" <<'EOF'
#!/bin/bash
if [[ ${1:-} == ipc ]]; then
  printf '%s\n' "${LOCK_ANSWER:-false}"
  exit 0
fi
printf 'idle\n' >> "${IDLE_LOG:?}"
if [[ ${IDLE_HANG:-0} == 1 ]]; then sleep 60; fi
exit 0
EOF
cat >"$tmp/bin/pgrep" <<'EOF'
#!/bin/bash
exit "${PGREP_CODE:-1}"
EOF
cat >"$tmp/bin/playerctl" <<'EOF'
#!/bin/bash
printf '%s\n' "${PLAYER_STATUS:-Playing}"
EOF
chmod +x "$tmp/bin/qs" "$tmp/bin/pgrep" "$tmp/bin/playerctl"
export PATH="$tmp/bin:$PATH" IDLE_LOG=$tmp/idle.log
: >"$IDLE_LOG"

check() {
  local name=$1 want=$2 maxs=$3
  shift 3
  : >"$IDLE_LOG"
  local start=$SECONDS
  set +e
  "$GATE" "$@" >/tmp/safe-gate.out 2>/tmp/safe-gate.err
  local rc=$?
  set +e
  local elapsed=$((SECONDS - start))
  if [[ $rc -eq $want && $elapsed -le $maxs ]]; then
    echo "ok   $name (${elapsed}s, exit $rc)"
  else
    echo "FAIL $name: exit $rc after ${elapsed}s, wanted $want within ${maxs}s" >&2
    echo "--- stderr ---" >&2
    cat /tmp/safe-gate.err >&2
    fail=1
  fi
}
idle_called() { grep -qx idle "$IDLE_LOG"; }

export LOCK_ANSWER=false PGREP_CODE=1 IDLE_HANG=1
check "stage: unlocked, no game, no idle wait" 0 2 --stage --max 30
idle_called && { echo "FAIL stage started the idle probe" >&2; fail=1; } || echo "ok   stage did not start the idle probe"

export LOCK_ANSWER=true
check "stage: locked still blocks" 75 3 --stage --max 1
idle_called && { echo "FAIL locked stage started the idle probe" >&2; fail=1; } || echo "ok   locked stage did not probe idle"

export LOCK_ANSWER=false PGREP_CODE=0
check "stage: game still blocks" 75 3 --stage --max 1
idle_called && { echo "FAIL game stage started the idle probe" >&2; fail=1; } || echo "ok   game stage did not probe idle"

export PGREP_CODE=1
check "stage + media: playing still blocks" 75 3 --stage --no-media --max 1
idle_called && { echo "FAIL media stage started the idle probe" >&2; fail=1; } || echo "ok   media wait did not become an idle wait"

export LOCK_ANSWER=false PGREP_CODE=0
check "lock-only still skips a game and idle" 0 2 --lock-only --max 30
idle_called && { echo "FAIL lock-only started the idle probe" >&2; fail=1; } || echo "ok   lock-only did not probe idle"

export PGREP_CODE=1 IDLE_HANG=1
check "restart gate still waits for idle" 75 3 --max 1 --idle 30
idle_called && echo "ok   restart gate ran the idle probe" || { echo "FAIL restart gate skipped idle" >&2; fail=1; }

export IDLE_HANG=0
check "restart gate passes once idle" 0 3 --max 5 --idle 1
idle_called && echo "ok   passing restart gate used the idle probe" || { echo "FAIL passing restart gate skipped idle" >&2; fail=1; }

install=$here/install.sh
uninstall=$here/uninstall.sh
mark=$here/overlay/.local/bin/omarchy-mark-reload-needed
jsonbuild=$here/overlay/.local/bin/omarchy-shell-json-build
grep -q 'gate --stage' "$install" && echo "ok   install uses --stage" || { echo "FAIL install gate mode" >&2; fail=1; }
# An echo telling the user to restart is not an automatic restart.
if grep -n 'omarchy restart shell' "$install" "$uninstall" "$mark" | grep -v 'echo '; then
  echo "FAIL a script runs omarchy restart shell" >&2
  fail=1
else
  echo "ok   install does not restart the shell"
fi
grep -q 'omarchy-mark-reload-needed' "$install" && echo "ok   install arms the reload icon" || { echo "FAIL install does not arm the icon" >&2; fail=1; }
grep -q '"--lock-only"' "$jsonbuild" && echo "ok   shell.json fill still uses lock-only" || { echo "FAIL shell-json-build gate changed" >&2; fail=1; }
exit $fail
