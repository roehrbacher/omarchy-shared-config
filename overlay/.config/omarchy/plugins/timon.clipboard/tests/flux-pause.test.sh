#!/bin/bash
# Run: bash tests/flux-pause.test.sh   (needs jq, flock; systemctl is stubbed,
# the real fluxd is never touched)
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/data/timon.clipboard"
# Fake `systemctl --user` for one unit. $FAKE/loaded and $FAKE/active hold its
# state; every call is appended to $FAKE/calls; $FAKE/fail makes start/stop fail.
cat >"$tmp/bin/systemctl" <<'STUB'
#!/bin/bash
[[ $1 == --user ]] && shift
echo "$*" >>"$FAKE/calls"
case $1 in
show) [[ -e $FAKE/loaded ]] && echo loaded || echo not-found ;;
is-active) [[ -e $FAKE/active ]] ;;
stop) [[ -e $FAKE/fail ]] && exit 1; rm -f "$FAKE/active" ;;
start) [[ -e $FAKE/fail ]] && exit 1; touch "$FAKE/active" ;;
*) exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/systemctl"
export PATH="$tmp/bin:$PATH" FAKE="$tmp/fake" XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/state" XDG_CONFIG_HOME="$tmp/config"
mkdir -p "$FAKE"
mark="$tmp/state/timon.clipboard/flux-paused"
state="$tmp/data/timon.clipboard/state.json"
fp="$here/flux-pause.sh"
fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got '$2' want '$3'"; fail=1; fi; }
running() { [[ -e $FAKE/active ]] && echo yes || echo no; }
marked() { [[ -e $mark ]] && echo yes || echo no; }
calls() { grep -cE "^(start|stop) " "$FAKE/calls" 2>/dev/null; }

# Flux not installed: silent no-op
echo '{"private": true}' >"$state"
out=$("$fp" sync 2>&1)
check "no Flux: sync prints only 'absent'" "$out" absent
check "no Flux: no start/stop" "$(calls)" 0
check "no Flux: no marker" "$(marked)" no

# Flux installed and running
touch "$FAKE/loaded" "$FAKE/active"
check "status running" "$("$fp" status)" running
check "private on -> sync pauses" "$("$fp" sync)" paused
check "fluxd stopped" "$(running)" no
check "marker written" "$(marked)" yes
check "state dir is 0700" "$(stat -c %a "$tmp/state/timon.clipboard")" 700
"$fp" sync >/dev/null
check "second sync while private: no extra stop" "$(calls)" 1
echo '{"private": false}' >"$state"
check "private off -> sync resumes" "$("$fp" sync)" running
check "fluxd running again" "$(running)" yes
check "marker removed" "$(marked)" no

# Flux was already off (not by us): never started
rm -f "$FAKE/active"
echo '{"private": true}' >"$state"
"$fp" sync >/dev/null
echo '{"private": false}' >"$state"
check "Flux off before private: stays off" "$("$fp" sync)" off
check "Flux off before private: no marker" "$(marked)" no

# Shell restart / reboot while private: private turned off in between,
# marker still there -> the startup sync starts Flux
touch "$FAKE/active"
echo '{"private": true}' >"$state"
"$fp" sync >/dev/null
echo '{"private": false}' >"$state"
check "startup after private ended: resumes" "$("$fp" sync)" running

# Reboot with private still on: fluxd starts at login, startup sync stops it again
echo '{"private": true}' >"$state"
"$fp" sync >/dev/null
touch "$FAKE/active"
check "login with private on: paused again" "$("$fp" sync)" paused

# `flux-cli off` while paused: we do not turn Flux back on
mkdir -p "$tmp/config/flux" && touch "$tmp/config/flux/off"
echo '{"private": false}' >"$state"
check "flux-cli off while paused: stays off" "$("$fp" sync)" off
check "flux-cli off: marker dropped" "$(marked)" no
rm -f "$tmp/config/flux/off"

# stop fails: no marker, so we never start it later
touch "$FAKE/active" "$FAKE/fail"
echo '{"private": true}' >"$state"
"$fp" sync >/dev/null
check "failed stop: no marker" "$(marked)" no
# start fails: marker kept so the next sync retries
rm -f "$FAKE/fail"
"$fp" sync >/dev/null
touch "$FAKE/fail"
echo '{"private": false}' >"$state"
"$fp" sync >/dev/null
check "failed start: marker kept for retry" "$(marked)" yes
rm -f "$FAKE/fail"
check "retry starts Flux" "$("$fp" sync)" running

# wipe (uninstall) resumes Flux first
echo '{"private": true}' >"$state"
"$fp" sync >/dev/null
"$here/clipboard.sh" wipe
check "wipe resumes Flux" "$(running)" yes
check "wipe removes marker" "$(marked)" no

exit $fail
