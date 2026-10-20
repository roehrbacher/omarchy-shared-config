# Test run – 2026-10-20 (1.5.0), a desktop (visual QA), Omarchy 4.0.6

Automated: history tests all passed (count without the pinned part);
`tst_searchfield.qml` 15 and `tst_kinetic.qml` 6 passed; `capture.test.sh` /
`flux-pause.test.sh` all ok; `omarchy plugin validate` ok.

Live on the desktop, opened over IPC: popup 5% bigger, search text at the
list's size, count "325 items", Incognito switch without On/Off, no hint
lines, gear icon; bar icon gets the stock open-panel underline while open
(none in 1.4.0); shortcuts & settings view, also with incognito on (Flux
"paused"); "Send via Flux" tooltip (shown through a temporary debug call,
not committed). Flux running again after incognito off. No synthetic keys.

# Test run – 2026-10-20 (1.4.0), a desktop (visual QA), Omarchy 4.0.6

Automated: history tests all passed (new: row action order phone, trash,
pin); `tst_searchfield.qml` 15 and `tst_kinetic.qml` 6 passed;
`capture.test.sh` / `flux-pause.test.sh` all ok; `omarchy plugin validate` ok.

Live on the desktop, opened over IPC (the same call the Alt+V binding makes):
popup opens under the bar's clipboard icon in the Wi-Fi popup style, half the
old width, no preview pane, compact rows (12 visible instead of 9); footer
wraps to two lines and stays readable; selected row shows phone, trash, pin
with pin in the same slot as on an unselected pinned row; keyboard action
focus on trash (temporary debug call, not committed). Incognito on, then off
right away: Flux is running again (fixed: a quick on/off could leave it
paused). No synthetic input.

# Test run – 2026-10-20 (1.3.2), a desktop (visual QA), Omarchy 4.0.6

Automated: history tests all passed (Alt+N top-to-bottom slots, row-action
keyboard focus); `tst_searchfield.qml`, `tst_kinetic.qml` passed;
`capture.test.sh` / `flux-pause.test.sh` all ok; `omarchy plugin validate` ok.

Live on the desktop, opened over IPC: footer Incognito switch (off and on),
"Phone connected via Flux", key hints line, Alt+N hints top to bottom, and a
keyboard-focused row action (set through a temporary debug call that was not
committed). Keys were not pressed live (no synthetic input).

# Test run – 2026-10-20 (1.3.1), a laptop and a desktop, Omarchy 4.0.6

Automated: history tests all passed; `tst_searchfield.qml` and the new
`tst_kinetic.qml` (wheel notch step, touchpad 1:1, flick continues after
lift-off and stops, no flick when the fingers stopped) all passed;
`capture.test.sh` / `flux-pause.test.sh` all ok; `omarchy plugin validate` ok.

Live (opened over IPC, no synthetic input): laptop popup 15% smaller, desktop
unchanged; hints and footer at the count's size. Real touchpad flicks were
not performed by the test (no synthetic input); the momentum logic is covered
by the offscreen tests.

# Test run – 2026-10-20 (1.3.0), a laptop and a desktop, Omarchy 4.0.6

Automated: `node tests/history.test.js` all passed; `qmltestrunner
tests/tst_searchfield.qml` 15 passed; `capture.test.sh` and
`flux-pause.test.sh` all ok; `omarchy plugin validate` ok.

Live, opened over IPC (no synthetic keys): desktop (1920x1080) popup keeps
its full size, laptop (1200x750 logical) popup is 20% smaller; top right shows
`N items · 1 pinned`; footer shows the key hints and "Phone connected" while
Flux has the phone online; the bar icon has no tooltip. A pinned row armed
for deletion turns red with "Press Del again to delete" and goes back to
normal after 3 s. Ctrl/Alt+N paste-on-release and the pinned double Del are
covered by the key tests; not pressed live.

# Test run – 2026-10-17, a laptop, Omarchy 4.0.4

Automated (both pass):

```
$ node tests/history.test.js
history tests: all passed
$ bash tests/capture.test.sh
ok   text captured
ok   data dir is 0700
ok   password manager copy skipped
ok   sensitive clipboard state skipped
ok   private mode skips text
ok   private mode skips images
ok   no image written in private mode
ok   image captured
ok   image file is 0600
ok   huge text (>4 MiB) skipped
ok   stock history imported
ok   history file is 0600
ok   prune removes orphan images
```

Live, in the running shell (driven over IPC, test strings only):

| Check | Result |
|---|---|
| `hyprctl configerrors` after adding the bindings | empty |
| shell journal: QML errors from timon.clipboard | none (one binding-loop warning fixed) |
| stock watchers gone, only `timon.clipboard/capture.sh` watchers running | yes (2) |
| first start imports the stock history | yes |
| `wl-copy` three texts → newest first in `history.json` | yes |
| Super+Ctrl+V route (`omarchy.clipboard`) opens this popup | yes |
| `omarchy-shell shell toggle timon.clipboard` (Super+Shift+V) | opens/closes |
| search "GCH" → 3 of N rows, theme colors, pin/delete icons, Ctrl+N hints | yes (screenshot checked) |
| pin → `"pinned": true`, own section at the top | yes |
| delete one item | removed |
| delete the current clipboard item → previous one back on the clipboard | yes |
| Shift+Enter path (copy by index) → `wl-paste` matches | yes |
| clear history → only pinned left, then history restored from backup | yes |
| private mode on → `wl-copy` not saved; off → saved again | yes |
| shell restart → history and pin still there | yes |
| `history.json` / `state.json` 0600, folder 0700 | yes |

Not tested live: Enter/click paste (Shift+Insert into the focused window) and
the bar icon, to avoid typing into windows that were in use during the test.
The paste path is the stock Omarchy one (`wl-copy` + `wtype` Shift+Insert).

# Test run – 2026-10-17 (1.1.0: search field + bar icon), a laptop and a desktop

Automated (all pass):

```
$ node tests/history.test.js
history tests: all passed            # now includes the search-field key routing
$ bash tests/capture.test.sh         # unchanged, all ok
$ QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_searchfield.qml
Totals: 10 passed, 0 failed          # real Qt TextInput, offscreen, no real clipboard
```

`tst_searchfield.qml` drives a text field set up like the popup's search line
with real key events: type "not found" → Ctrl+A selects all → Ctrl+C hands
exactly that text to the copy function, search unchanged; Ctrl+X cuts; Ctrl+C
without a selection copies nothing; Shift+←/Shift+Home select; Ctrl+Backspace
deletes a word; Ctrl+U clears without copying; ↑ ↓ Enter Ctrl+N still reach the
list; Del with selected search text edits the text, without a selection it
deletes the entry.

The copy path (Quickshell `Process`, text over stdin, then stdin closed) was
checked in a separate throwaway quickshell instance with `cat` in place of
`wl-copy`: bytes (incl. UTF-8 and newlines) arrive exactly, EOF arrives, the
process exits. `wl-copy` forks its own server after EOF, so the copy stays on
the clipboard after the popup closes or the shell restarts.

Live:

| Check | Result |
|---|---|
| `hyprctl configerrors` | empty (both machines) |
| shell log after restart | no QML errors from timon.clipboard |
| bar icon (`timon.clipboard` in `shell.json` right section, before audio) | present, same slot size/spacing as its neighbours (checked on a screenshot) |

Not tested live: the real Ctrl+A / Ctrl+C keystrokes in the popup and the new
history entry, because the laptop was in use and the desktop was locked (no
synthetic keys sent). To try: Super+Shift+V, type something, Ctrl+A, Ctrl+C,
Esc → the text is on the clipboard and at the top of the history.

# Test run – 2026-10-17 (1.2.0: private mode pauses Flux), a laptop and a desktop

Automated (all pass):

```
$ bash tests/flux-pause.test.sh      # stub systemctl, the real fluxd is never touched
ok   no Flux: sync prints only 'absent'      ok   no Flux: no start/stop
ok   no Flux: no marker                      ok   status running
ok   private on -> sync pauses               ok   fluxd stopped
ok   marker written                          ok   state dir is 0700
ok   second sync while private: no extra stop
ok   private off -> sync resumes             ok   fluxd running again
ok   marker removed
ok   Flux off before private: stays off      ok   Flux off before private: no marker
ok   startup after private ended: resumes    ok   login with private on: paused again
ok   flux-cli off while paused: stays off    ok   flux-cli off: marker dropped
ok   failed stop: no marker                  ok   failed start: marker kept for retry
ok   retry starts Flux                       ok   wipe resumes Flux
ok   wipe removes marker
$ node tests/history.test.js && bash tests/capture.test.sh   # unchanged, all ok
```

Live on the laptop, toggled over the same IPC the key and the bar icon use
(`omarchy-shell shell call timon.clipboard togglePrivate x` / `setPrivateMode`):

| Step | fluxd.service | `flux-pause.sh status` | plugin `status` |
|---|---|---|---|
| before | active (old PID) | running | private false, fluxPaused false |
| togglePrivate → private | inactive, fluxd and its `wl-paste --watch` gone | paused (marker present) | private true, fluxPaused true |
| togglePrivate → recording | active (new PID) | running (marker gone) | private false, fluxPaused false |
| setPrivateMode on, then shell restart | inactive, stays inactive after restart | paused | private true, fluxPaused true |
| setPrivateMode off | active | running | private false, fluxPaused false |

Shell log after restart: no QML errors from timon.clipboard. Not done live: a
real copy during private mode (kept off the user's clipboard); fluxd's own
code records the current clipboard at start without sending it
(`internal/desktop/clipboard.go`, `observe(..., initial)`).
