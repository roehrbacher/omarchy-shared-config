#!/usr/bin/env bash
# Shared vocabulary matches Voxtype, keeps calculator words, and merges without touching local settings.
set -u
here=$(cd "$(dirname "$0")/.." && pwd)
apply=$here/overlay/.local/bin/omarchy-dictation-vocabulary-apply
shared=$here/overlay/.config/omarchy/dictation-shared.json
toml=$here/overlay/.config/voxtype/config.toml
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail=0
python3 - "$shared" "$toml" <<'PY'
import json, re, sys
shared, toml_path = sys.argv[1:]
doc = json.load(open(shared))
toml = open(toml_path).read()
fail = 0
def check(cond, msg):
    global fail
    print(("ok  " if cond else "FAIL ") + msg)
    if not cond: fail = 1
reps = {p["from"]: p["to"] for p in doc["replacements"]}
toml_reps = dict(re.findall(r'^"(.+)" = "(.+)"$', toml, re.M))
check(reps == toml_reps, "voxtype replacements match the shared seed")
check("OmaCast" in doc["vocabulary"] and "OmaCalc" not in doc["vocabulary"], "OmaCast hinted, OmaCalc is not")
check(reps.get("oma calc") == "OmaCast" and reps.get("omer calc") == "OmaCast", "oma/omer calc -> OmaCast")
check(reps.get("omacalc") == "OmaCast" and reps.get("oma cast") == "OmaCast", "omacalc and oma cast -> OmaCast")
for bare in ("calc", "calculator", "oma"):
    check(bare not in reps and bare not in doc["vocabulary"], f"bare {bare!r} is not a rule")
protected = {p.casefold() for p in doc["protectedFrom"]}
check(protected == {"calc", "calculator", "oma"}, "protected phrases")
# Whole-word, longer phrases first, case-insensitive. Mirrors the Voxtype note.
def apply(text):
    for key in sorted(reps, key=len, reverse=True):
        text = re.sub(r"(?i)(?<!\w)" + re.escape(key) + r"(?!\w)", lambda _m, dest=reps[key]: dest, text)
    return text
check(apply("use the calculator") == "use the calculator", "calculator sentence stays")
check(apply("calc") == "calc" and apply("oma") == "oma", "bare calc and oma stay")
check(apply("OmaCalc") == "OmaCast", "dictated OmaCalc is the OmaCast mishearing")
check(apply("oma calc please") == "OmaCast please", "oma calc phrase")
sys.exit(fail)
PY
fail=$?
# Desktop launcher name is not rewritten by this file.
grep -q 'Name=Calc (OmaCalc)' "$here/overlay/.local/share/applications/omacalc.desktop" \
  && echo "ok   calculator launcher name unchanged" || { echo "FAIL omacalc.desktop"; fail=1; }

cat >"$tmp/settings.json" <<'EOF'
{
  "license": "local-license-keep",
  "history": [{"text": "yesterday"}],
  "mode": {"model": "parakeet", "language": "auto", "gpu": "local"},
  "modelCache": "/home/example/.cache/superwhisper/models",
  "vocabulary": ["CustomWord", "OmaCalc"],
  "replacements": [
    {"original": "my email", "with": "me@example.com"},
    {"original": "oma calc", "with": "OmaCalc"}
  ]
}
EOF
"$apply" --shared "$shared" --settings "$tmp/settings.json" >/dev/null || { echo "FAIL apply"; exit 1; }
python3 - "$tmp/settings.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
fail = 0
def check(cond, msg):
    global fail
    print(("ok  " if cond else "FAIL ") + msg)
    if not cond: fail = 1
check(doc["license"] == "local-license-keep", "license untouched")
check(doc["history"] == [{"text": "yesterday"}], "history untouched")
check(doc["mode"]["language"] == "auto" and doc["mode"]["gpu"] == "local", "mode untouched")
check(doc["modelCache"].endswith("/models"), "model cache path untouched")
check("CustomWord" in doc["vocabulary"] and "OmaCast" in doc["vocabulary"], "custom and OmaCast vocab")
check("OmaCalc" not in doc["vocabulary"], "OmaCalc vocab term removed")
by = {r["original"]: r["with"] for r in doc["replacements"]}
check(by.get("my email") == "me@example.com", "user replacement kept")
check(by.get("oma calc") == "OmaCast", "shared phrase updated to OmaCast")
check("calc" not in by and "calculator" not in by, "bare calc not inserted")
sys.exit(fail)
PY
fail=$((fail + $?))
before=$(cat "$tmp/settings.json")
"$apply" --shared "$shared" --settings "$tmp/settings.json" | grep -q 'already matches' \
  && echo "ok   second merge is a no-op" || { echo "FAIL second merge"; fail=1; }
[[ $(cat "$tmp/settings.json") == "$before" ]] && echo "ok   second merge does not rewrite" || { echo "FAIL rewrite"; fail=1; }
"$apply" --shared "$shared" --settings "$tmp/settings.json" --remove-shared >/dev/null
python3 - "$tmp/settings.json" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
by = {r["original"]: r["with"] for r in doc["replacements"]}
fail = 0
def check(cond, msg):
    global fail
    print(("ok  " if cond else "FAIL ") + msg)
    if not cond: fail = 1
check("CustomWord" in doc["vocabulary"] and "OmaCast" not in doc["vocabulary"], "undo keeps custom vocab")
check(by.get("my email") == "me@example.com" and "oma calc" not in by, "undo keeps user phrase only")
check(doc["license"] == "local-license-keep", "undo leaves license")
sys.exit(fail)
PY
fail=$((fail + $?))
missing=$tmp/missing.json
"$apply" --shared "$shared" --settings "$missing" && [[ ! -e $missing ]] \
  && echo "ok   missing settings file is not created" || { echo "FAIL created settings"; fail=1; }

# Path discovery. HOME is a fixture, not this machine.
home=$tmp/machine
export HOME=$home XDG_CONFIG_HOME=$home/.config
unset SUPERWHISPER_SETTINGS
mkdir -p "$home"
seed_settings() {
  mkdir -p "$(dirname "$1")"
  cat >"$1" <<'EOF'
{
  "license": "local-license-keep",
  "history": [{"text": "yesterday"}],
  "mode": {"model": "parakeet", "language": "auto", "gpu": "local"},
  "modelCache": "/home/example/.cache/superwhisper/models",
  "vocabulary": ["CustomWord", "OmaCalc"],
  "replacements": [{"original": "my email", "with": "me@example.com"}]
}
EOF
}
unchanged_private() {
  python3 - "$1" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
ok = (
    doc["license"] == "local-license-keep"
    and doc["history"] == [{"text": "yesterday"}]
    and doc["mode"] == {"model": "parakeet", "language": "auto", "gpu": "local"}
    and doc["modelCache"].endswith("/models")
    and any(r.get("original") == "my email" and r.get("with") == "me@example.com" for r in doc["replacements"])
)
print(("ok  " if ok else "FAIL ") + "private fields stay in " + sys.argv[1])
sys.exit(0 if ok else 1)
PY
}

flat=$home/.config/superwhisper/settings.json
nested=$home/.config/superwhisper/settings/settings.json

# No Superwhisper install: create nothing.
"$apply" --shared "$shared" && echo "ok   absent Superwhisper exits 0" || { echo "FAIL absent superwhisper"; fail=1; }
[[ -z $(find "$home" -name 'settings.json' -o -name 'settings.json.bak-omarchy-vocab' 2>/dev/null) ]] \
  && echo "ok   absent Superwhisper creates no settings" || { echo "FAIL created a settings file"; fail=1; }

# Live nested path only (the PC layout).
seed_settings "$nested"
"$apply" --shared "$shared" >/dev/null || { echo "FAIL nested merge"; fail=1; }
python3 - "$nested" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
ok = "OmaCast" in doc["vocabulary"] and "OmaCalc" not in doc["vocabulary"] and "CustomWord" in doc["vocabulary"]
print(("ok  " if ok else "FAIL ") + "nested path received the shared vocabulary")
sys.exit(0 if ok else 1)
PY
fail=$((fail + $?))
unchanged_private "$nested" || fail=1
[[ ! -e $flat ]] && echo "ok   flat path was not created beside the nested file" || { echo "FAIL flat file created"; fail=1; }
nested_once=$(cat "$nested")
second=$("$apply" --shared "$shared")
printf '%s\n' "$second" | grep -q 'already matches' && echo "ok   nested merge is idempotent" || { echo "FAIL nested second run: $second"; fail=1; }
[[ $(cat "$nested") == "$nested_once" ]] && echo "ok   second nested merge does not rewrite" || { echo "FAIL nested rewrite"; fail=1; }

# Older flat path still works when it is the only file.
rm -rf "$home/.config/superwhisper"
seed_settings "$flat"
"$apply" --shared "$shared" >/dev/null || { echo "FAIL flat merge"; fail=1; }
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if "OmaCast" in d["vocabulary"] else 1)' "$flat" \
  && echo "ok   flat path still receives the vocabulary" || { echo "FAIL flat vocabulary"; fail=1; }
unchanged_private "$flat" || fail=1
[[ ! -e $nested ]] && echo "ok   nested path was not created beside the flat file" || { echo "FAIL nested file created"; fail=1; }

# Both files: only the newer one changes.
rm -rf "$home/.config/superwhisper"
seed_settings "$flat"
seed_settings "$nested"
cp "$flat" "$tmp/flat-before"
cp "$nested" "$tmp/nested-before"
touch -d '2020-01-01 00:00:00' "$flat"
touch -d '2024-06-01 00:00:00' "$nested"
"$apply" --shared "$shared" >/dev/null || { echo "FAIL newest merge"; fail=1; }
cmp -s "$flat" "$tmp/flat-before" && echo "ok   older flat file was not modified" || { echo "FAIL stale flat file changed"; fail=1; }
! cmp -s "$nested" "$tmp/nested-before" && echo "ok   newer nested file was merged" || { echo "FAIL live nested file unchanged"; fail=1; }
unchanged_private "$nested" || fail=1

# Equal mtimes: modify neither.
rm -rf "$home/.config/superwhisper"
seed_settings "$flat"
seed_settings "$nested"
touch -d '2024-06-01 00:00:00' "$flat" "$nested"
cp "$flat" "$tmp/tie-flat"
cp "$nested" "$tmp/tie-nested"
tie=$("$apply" --shared "$shared" 2>&1) || { echo "FAIL tie merge exited nonzero"; fail=1; }
printf '%s\n' "$tie" | grep -q 'none were changed' && echo "ok   equal mtimes change nothing" || { echo "FAIL tie message: $tie"; fail=1; }
cmp -s "$flat" "$tmp/tie-flat" && cmp -s "$nested" "$tmp/tie-nested" \
  && echo "ok   neither tied file was written" || { echo "FAIL a tied file changed"; fail=1; }
exit $fail
