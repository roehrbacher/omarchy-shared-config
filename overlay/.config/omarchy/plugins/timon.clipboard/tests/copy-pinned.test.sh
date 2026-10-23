#!/bin/bash
# Run: bash tests/copy-pinned.test.sh  (fake wl-copy, temp data dir; never touches the real clipboard)
set -u
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/data/timon.clipboard"
printf '#!/bin/bash\ncat > "%s/copied"\n' "$T" > "$T/bin/wl-copy"; chmod +x "$T/bin/wl-copy"
cat > "$T/data/timon.clipboard/history.json" <<'J'
[{"type":"text","text":"c","pinned":true},{"type":"text","text":"x"},{"type":"text","text":"a","pinned":true},{"type":"text","text":"b","pinned":true}]
J
run() { PATH="$T/bin:$PATH" XDG_DATA_HOME="$T/data" bash "$(dirname "$0")/../clipboard.sh" copy-pinned "$1"; }
fail=0
check() { rm -f "$T/copied"; run "$1"; rc=$?; got=$(cat "$T/copied" 2>/dev/null)
  if [[ $rc == "$2" && $got == "$3" ]]; then echo "ok   copy-pinned $1 -> rc=$rc '${got}'"; else echo "FAIL copy-pinned $1 -> rc=$rc '${got}' (want rc=$2 '$3')"; fail=1; fi; }
check 1 0 c
check 2 0 a
check 3 0 b
check 4 1 ""
check 0 1 ""
check x 1 ""
exit $fail
