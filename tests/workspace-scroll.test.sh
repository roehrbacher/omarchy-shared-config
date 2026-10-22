#!/bin/bash
# Run: bash tests/workspace-scroll.test.sh   (pure planning, no dispatch)
P="$(dirname "$0")/../overlay/.local/bin/omarchy-workspace-scroll"; fail=0
check() { local want=$1; shift; local got; got=$("$P" --plan "$@")
  if [[ $got == "$want" ]]; then echo "ok   $* -> $got"; else echo "FAIL $* -> $got (want $want)"; fail=1; fi; }
# occupied 1,2,4: range 1..5
check 3 next 2 1 2 4; check 5 next 4 1 2 4; check 5 next 5 1 2 4
check 4 prev 5 1 2 4; check 1 prev 1 1 2 4
# occupied 2,4: range 1..5
check 2 next 1 2 4; check 1 prev 1 2 4; check 5 next 5 2 4; check 3 next 2 2 4
# ends clamp (no wrap); max 10, min 1; outside the range jumps back into it
check 10 next 9 9 10; check 10 next 10 9 10; check 8 next 8 1 2; check 3 prev 8 1 2
# nothing occupied: stay
check 4 next 4
exit $fail
