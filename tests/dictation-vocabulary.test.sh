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
exit $fail
