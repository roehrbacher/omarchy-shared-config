# Test run – 2026-10-23 (1.19.0). Offscreen (software backend) tests/geometry/run-v119.sh on the real Clipboard.qml: QR+OCR image row shows Copy Wi-Fi password (lock U+F033E) and Copy text from screenshot; HTML row shows Paste as Markdown (U+F48A) and Paste as plain text; on-clipboard accent mark on open (alpha) and after a live copy (moves to the new item); 1 selected: no info line, close = no queue; 2 selected: footer "Paste queue: 2 items in order · Ctrl+V pastes them one by one"; Esc clears the selection and keeps the popup open; click with 2 selected closes the popup and hands queue.sh [beta, alpha] in selection order; reopen during queue: "Pasting 2 of 2 · Cancel", badges alpha=2, beta=1 (done, dimmed); pinned row dragged into History lands at the top of History; OCR settings heading fits, install command `sudo pacman -S tesseract-data-deu`. scan.test.sh 15 (installed packs, OMARCHY_OCR_LANGS filter, osd excluded, --langs JSON), queue 27 (new "Queue ready" notification), capture 18, markdown 13, copy-pinned 6, flux-pause 23, history ok; run-queue, run-v118, run-image and qmltestrunner (4/4/4/4/6/15) all pass.

# Test run – 2026-10-23 (1.18.0). Root causes: (1) paste queue: wl-copy forks a daemon that kept fd 9 = the queue flock, so the 2nd Ctrl+V gave up on the lock (seen live on the laptop: queue stuck at 1 of 3, wl-copy holding queue.lock); children now get 9>&-, regression test with a forking wl-copy stub fails on 1.17.0 (4 FAIL) and passes now. Live on the desktop with the real wl-copy (marked sensitive so nothing was recorded): 3 Ctrl+V in a row = items 1, 2, 3 on the clipboard, ~230 ms each. (2) QR: zbar 0.23.95 could not read the laptop's real QR screenshot (also not with border/negate/threshold/resize); ZXingReader read it. Generated tests: url, e-mail, text, tight crop, light-on-dark Wi-Fi, small blurred all read (zbar alone: tight only). (3) Markdown paste was captured as a copy: capture.sh now drops exactly the one copy whose hash clipboard.sh left in skip-next, then the entry is restored. Offscreen (software backend) tests/geometry/run-v118.sh on the real Clipboard.qml: QR previews and buttons (Wi-Fi name: ExampleNet / Copy Wi-Fi password, QR link / Open link, QR e-mail / Send email, QR text / Copy QR code text), OCR tooltips, drag history row up: stays until it reaches Pinned, pinned at slot 1 on drop, same delegate (no flicker); pinned row dragged down: unpinned on drop; copy-only click keeps the popup open and calls `copy`; SEARCH FILTERS heading fits (112 of 539 px), all 11 filter rows fit. Also run-queue.sh, run-image.sh, qmltestrunner dragflicker 4, draggap 4, headerclick 4, keepscroll 4, kinetic 6, searchfield 15; history, capture 18, queue 27, markdown 13, scan 10, copy-pinned 6, flux-pause 23 all ok.

# Test run – 2026-10-23 (1.17.0): Paste as Markdown (HTML kept on capture, pandoc or bundled html2md.py, plain-text fallback), paste queue (Ctrl+click numbered rows, "Paste N in order", runtime Ctrl+V/Esc binds, "Pasted k of N" notification, 15 min watchdog), password-manager hint documented and tested (Bitwarden desktop sets x-kde-passwordManagerHint via arboard 3.6; wl-paste 2.3.0 turns it into CLIPBOARD_STATE=sensitive for Flux). Automated: history tests incl. markdown/queue ok, tests/queue.test.sh, tests/markdown.test.sh, capture.test.sh all ok; offscreen (software backend): tests/geometry/run-queue.sh on the real Clipboard.qml (Markdown button only on the HTML row, badges 1/2/3 in Ctrl+click order, re-click renumbers, Ctrl+Space adds, Esc clears selection without closing, footer "Paste 3 in order" / "Pasting 2 of 5 · Cancel", Ctrl+Enter closes the popup and hands queue.sh [beta, gamma] in order), run-image.sh unchanged, tst_dragflicker 4, draggap 4, headerclick 4, keepscroll 4, kinetic 6, searchfield 15 passed. hyprctl eval hl.bind/hl.unbind checked live with a throwaway combo (unbind is modifier-exact, SUPER+Esc untouched).

# Test run – 2026-10-23 (1.16.0): copy text from images (tesseract OCR, eng+deu when installed), QR codes (zbarimg: link/e-mail -> open button, Wi-Fi -> copy password, other -> copy QR text), image text searchable, search filters (type:, app:, is:pinned, today, yesterday, <30m/<2h/<3d), source app recorded on capture. Second pinned-drag flicker fixed: in the 4 px gap between rows indexAt() returned -1 and the row was sent to the top/bottom of Pinned for a frame; it now stays put in the gap. Also a drop no longer counts as a click (it pasted the row), and the marquee no longer resets on a plain press. Offscreen (software backend): history tests ok, scan.test.sh 4 ok, capture.test.sh ok, tst_draggap 4 passed (1.15.1 logic jumps, new logic one step at a time), dragflicker/keepscroll/headerclick/kinetic/searchfield passed, tests/geometry/run-image.sh (real Clipboard.qml: buttons per image kind, 8 filters, settings row fits).

# Test run – 2026-10-23 (1.15.1): pinned drag flicker fixed. Cause: during a drag the row highlight was bound to the row position (index === selectedIndex); displayModel.move() changed the indexes before selectedIndex caught up, so the passed row got the highlight for one binding step and the stock CursorSurface 60 ms colour fade started on it (and the Alt+N numbers only jumped on drop). Now the highlight follows the dragged entry by identity and the slots update live. New offscreen test tests/tst_dragflicker.qml (old logic flashes, new logic none, same delegate kept) 4 passed; keepscroll 4, headerclick 4, kinetic 6, searchfield 15 passed; history tests ok.

# Test run – 2026-10-21 (1.6.1): phone button moved from the header to the footer, left of the gear, same size and hover as the gear; icon + tooltip per Flux state; click opens Flux (flux-cli open). Unit tests pass.

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
