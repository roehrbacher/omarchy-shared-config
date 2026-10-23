# Nice Clipboard History

<!-- Preview image goes here once it exists, e.g. ![Nice Clipboard History](preview.png) -->


Clipboard history for [Omarchy](https://omarchy.org) with the feel of
[GNOME Clipboard History](https://github.com/SUPERCILEX/gnome-clipboard-history):
pinned items, incognito mode, instant regex search and Alt+1…9 quick picks.

It is built on Omarchy's own clipboard manager (`omarchy.clipboard`) and
**replaces** it as a clone (`"clonedFrom": "omarchy.clipboard"`), so there is
only ever one clipboard watcher running. Your existing stock history is
imported once on first start. Uses the current theme's menu colors.

## Shortcuts

| Key | What it does |
|---|---|
| **Alt+V** | open / close clipboard history |
| Super+Shift+V | the same (GNOME default key, optional binding) |
| Super+Ctrl+V | the same (stock Omarchy key, routed to this plugin) |
| **Super+Shift+Ctrl+V** | incognito on/off from anywhere (with a notification) |

In the popup:

| Key | What it does |
|---|---|
| type | search (case-insensitive regex; invalid regex = plain text) |
| ↑ ↓ / Ctrl+K Ctrl+J, PgUp PgDn, Home End | move through the list |
| Enter / click | paste into the window you came from |
| Shift+Enter | copy only (select it without pasting) |
| Alt+Enter | open (URL in browser, text in editor, image in editor) |
| Ctrl+click / Ctrl+Space | add the row to the paste queue (numbered 1, 2, 3 …); again takes it out |
| Ctrl+click / Ctrl+Space 2+ items, then close the popup (Enter, click, Esc twice or click outside) | start the paste queue: every Ctrl+V pastes the next item, Esc cancels |
| Alt+1…9 | paste the Nth item from the top, pinned items first (pastes when you let go of Alt) |
| → / ← (search cursor at the end) | move between the selected row's actions (phone, trash, pin); Enter presses the focused one; Esc, ↑ or ↓ go back to the row |
| Ctrl+P (or the pin icon) | pin / unpin (Ctrl+F works too) |
| Delete (or the trash icon) | delete the item (with search text selected: delete that text). A pinned item turns red first: press Del again within 3 s to delete it; any other key cancels |
| Ctrl+S (or the phone icon) | send a text item to the phone (Flux, when a phone is connected); in the settings view: send the current clipboard |
| Shift+Delete | clear history (asks first; pinned items stay) |
| Ctrl+I (or the Incognito switch in the footer, or right-click the bar icon) | incognito on/off |
| Backspace, Ctrl+Backspace, ← →, Ctrl+Z | edit the search |
| Ctrl+U | clear the search |
| Shift+← → / Shift+Home End, Ctrl+A, mouse drag | select search text |
| Ctrl+C / Ctrl+X (with search text selected) | copy / cut it to the clipboard (becomes a new history item) |
| Ctrl+V | paste into the search |
| the gear icon in the footer | settings view: ↑ ↓ pick a setting, Enter toggles it, Esc goes back to the list |
| Esc | clear the search, then close |

## Behaviour

- **History:** newest first, a re-copied item moves to the top. Unpinned items
  are deleted 1, 2, 5 (default), 10 or 20 days after they were copied (pick it
  in settings); pinned items are never deleted. Day headings: History (today),
  Yesterday, then the date. Text and images (PNG, JPEG, WebP, GIF,
  …); copied files show their file name and an image preview.
- **Pinned:** shown in their own section at the top, survive "clear history"
  and the limit.
- **Popup:** opens right under the clipboard icon in the bar, like the stock
  Wi-Fi popup (same look, the bar's open-panel underline under the icon,
  click outside or open another bar popup to close),
  also when opened with Alt+V. Without the bar icon (bar widget not in the
  layout) it opens at the top-left corner. A compact list, no preview pane;
  hover or select a row for its actions: phone (send), trash, pin.
- **Size:** the popup scales with the screen: full size from 1080 px logical
  height up, down to 85% on small laptop screens.
- **Touchpad momentum:** a quick two-finger flick keeps the list scrolling
  after the fingers lift and slows down, like GTK apps and browsers. Mouse
  wheel notches scroll a fixed step.
- **Count:** top right shows e.g. `119 items` (`4 of 119 items` while
  searching).
- **Header:** search field ("Search clipboard…"); the item count is on the Clear history button.
- **Footer (one row):** Clear history on the left; the Incognito switch, a
  phone button (only when Flux is installed) and a gear icon on the right.
  The phone button's icon and tooltip show the Flux state ("<phone> connected
  via Flux", "No phone connected", "Flux paused (incognito)", "Flux not
  running"); clicking it closes the popup and opens Flux (`flux-cli open`). The gear opens the settings
  view: incognito, clear history, Flux (phone, last sync, "Send current
  clipboard" with Ctrl+S), history limit, all keys. Hovering the phone action
  of a row shows "Send via Flux".
- **Incognito:** nothing new is saved (text or images) until you turn it
  off; a small "Incognito" badge in the popup shows it. Survives a restart.
- **Incognito pauses Flux too:** if [Flux](https://github.com/bjarneo/flux)
  (`fluxd.service`) runs, incognito stops it, so copies are not synced to
  the phone or saved in Flux's history; turning incognito off starts it
  again. The footer phone button then shows a crossed-out phone, and the notification says "Flux sync paused". See "Flux" below.
- **Deleting an item** only removes it from the history; the current
  clipboard stays as it is, even when it holds the same text. ("Clear history"
  still empties the clipboard if it held an unpinned item.)
- **Skipped automatically:** copies from password managers
  (`x-kde-passwordManagerHint`, `CLIPBOARD_STATE=sensitive`), text over 4 MiB,
  images over 25 MiB.
- **Storage:** only `~/.local/share/timon.clipboard/` (folder `0700`, files
  `0600`): `history.json`, `state.json`, `images/`, plus the marker
  `~/.local/state/timon.clipboard/flux-paused` while this plugin has Flux
  paused. Nothing is logged, synced or sent anywhere. Unreferenced images are deleted automatically.
- Clipboard text is read by index from that file, never passed on a command
  line, so it does not show up in process lists. Search text copied with
  Ctrl+C goes to `wl-copy` over stdin for the same reason, and stays on the
  clipboard after the popup closes.

- **From phone:** with Flux, text that came from the phone gets a small
  "From phone" label, and the footer phone button shows a phone while a paired
  phone is online.

Bar icon: add `{ "id": "timon.clipboard" }` to a bar section (for example the
right section, before the audio icon). It uses the standard
fixed-width bar icon slot, so switching icons never shifts its neighbours.
Left click opens / closes the history, right click toggles incognito, and it
turns into the incognito icon (󰗹) while incognito is on. It has no hover tooltip.

## 1.19.0 notes

- Paste queue starts by itself: select 2+ items with Ctrl+click or Ctrl+Space and close the popup. Notification: "Queue ready: N items. Ctrl+V pastes 1 of N. Esc cancels." One Ctrl+clicked item is a normal pick. Reopening during a queue shows progress, badges and Cancel. A new 2+ selection replaces a running queue.
- The item currently on the clipboard has an accent bar on the left (updates live).
- Images with a QR code and text show both buttons. Wi-Fi QR uses a lock icon.
- Paste as Markdown (M glyph) always comes with Paste as plain text.
- Dragging a pinned item into History unpins it and puts it at the top of History.
- OCR languages: all installed tesseract packs are used (eng first, at most 3), or `OMARCHY_OCR_LANGS` (e.g. `eng+deu`, filtered to installed packs). Settings lists installed languages and shows a copyable install command such as `sudo pacman -S tesseract-data-deu`. Nothing is downloaded or installed automatically.

## Flux

`fluxd` watches the clipboard itself (its own `wl-paste --watch`) and has no
pause switch of its own that fits: its `autoClipboard` setting would still keep
the last incognito copy in memory and hand it to the phone when it reconnects,
and it would change Flux's config file. So `flux-pause.sh` simply stops and
starts Flux's systemd user unit (`systemctl --user stop|start fluxd.service`).
Nothing of Flux (binary, unit, config) is touched, so a Flux update cannot undo
this. When fluxd starts again it records the current clipboard without sending
it, so nothing copied during incognito reaches the phone.

- Flux is only started again if this plugin stopped it (marker file in
  `~/.local/state/timon.clipboard/`). If Flux was off already, or you ran
  `flux-cli off` meanwhile, it stays off.
- Every shell start runs the same sync: if incognito ended while the shell
  was down (crash, reboot), Flux is started; if incognito is still on after
  a reboot, the fluxd that systemd started at login is stopped again.
- Uninstalling (`clipboard.sh wipe`) starts Flux first if we paused it.
- No Flux installed: nothing happens, nothing is logged.
- While paused, the whole phone link is down (notifications, SMS, calls, file
  transfer, phone approval of sudo), and Flux's own bar icon says "fluxd is not
  running". That is the price of a clean pause; it comes back with incognito
  off. Starting Flux from its own panel during incognito is allowed and
  sticks until the next incognito toggle or shell start.

By hand: `flux-pause.sh status` (`paused`, `running`, `off`, `absent`),
`flux-pause.sh resume` (start Flux if we stopped it).

IPC (for scripts): `omarchy-shell shell call timon.clipboard toggleIncognito x`,
`setIncognito on|off`, `status x` (includes `incognito` and `fluxPaused`). The
older names `togglePrivate` and `setPrivateMode` still work.

## Install

```bash
omarchy plugin add https://github.com/roehrbacher/omarchy-clipboard --enable
```

The plugin ID is `timon.clipboard`. Enabling it switches off the stock
`omarchy.clipboard` (it is a clone of it), so only one clipboard watcher runs.
Then add the shortcuts to `~/.config/hypr/bindings.lua`:

```lua
o.bind("ALT + V", "Clipboard history", "omarchy-shell shell toggle timon.clipboard")
o.bind("SUPER + SHIFT + V", "Clipboard history", "omarchy-shell shell toggle timon.clipboard")  # optional, GNOME key
o.bind("SUPER + SHIFT + CTRL + V", "Clipboard incognito", "omarchy-shell shell call timon.clipboard toggleIncognito x")
```

and run `omarchy restart shell`.

## Update

```bash
omarchy plugin update timon.clipboard && omarchy restart shell
```

The plugin is `keepLoaded`, so code changes need a shell restart.

## Uninstall

```bash
~/.config/omarchy/plugins/timon.clipboard/flux-pause.sh resume   # start Flux again if incognito had paused it
omarchy plugin remove timon.clipboard      # brings back the stock omarchy.clipboard
rm -rf ~/.local/share/timon.clipboard      # optional: deletes the saved history
omarchy restart shell
```

Remove the bindings too. Super+Ctrl+V then opens the stock manager again.
To only switch it off and keep it installed: `omarchy plugin disable timon.clipboard`.

## Tests

```bash
node tests/history.test.js     # history model: limit, pins, search, clear, key routing, count label, delete confirm, Ctrl/Alt+N, popup size, Flux origin, phone name, last sync, phone button state and tooltip
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_searchfield.qml  # search field keys, Ctrl/Alt+N paste on release, pinned Del twice (real Qt)
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_kinetic.qml      # wheel step, touchpad 1:1, momentum after lift-off
bash tests/capture.test.sh     # capture: incognito, password hint, size caps, 0600/0700, import, prune
bash tests/flux-pause.test.sh  # Flux pause/resume with a stub systemctl (never touches the real fluxd)
```

See `TESTING.md` for the last manual run.

## Credit

Built on Omarchy's stock clipboard manager (`shell/plugins/clipboard`, MIT,
David Heinemeier Hansson). UX modelled on GNOME Clipboard History by Alex
Saveau (MIT); no code from it is used.

## Text in images, QR codes and search filters (1.16.0)

- Images are read in the background (niced): text with `tesseract`
  (English, plus German when `tesseract-data-deu` is installed) and QR codes
  with `zbarimg`. The text is searchable. Hovering an image row shows
  **Copy text**; a QR link or e-mail gets the open button, a Wi-Fi QR code
  copies the password, any other QR code copies its text. Without the tools
  the buttons simply don't appear: `sudo pacman -S tesseract tesseract-data-eng tesseract-data-deu zbar`.
- Search filters, combinable with normal search text: `type:image|screenshot|text|link|color|file`,
  `app:<window class>` (recorded from 1.16.0 on), `is:pinned`, `today`, `yesterday`, `<30m`, `<2h`, `<3d`.

## Paste as Markdown, paste queue, password managers (1.17.0)

- **Paste as Markdown:** a copy from a browser or office app also carries
  HTML. When it has formatting (headings, links, lists, bold/italic, code,
  quotes, tables) the HTML is kept with the entry (up to 256 KiB) and the row
  shows a Markdown button (󰍔, "Paste as Markdown"). It converts with
  `pandoc -t gfm` when pandoc is installed, else with the bundled
  `html2md.py` (Python standard library, handles Google Docs' styled
  spans); if neither works it pastes the plain text.
- **Paste queue:** Ctrl+click rows (or Ctrl+Space on the selected one); each
  gets a numbered badge in click order. The footer's Clear history button
  shows "Paste queue: N items in order"; closing the popup starts the queue. Esc clears the selection first.
  Starting closes the popup and shows a notification "N items. Ctrl+V pastes
  1 of N. Esc cancels.". Every Ctrl+V then pastes the next item and updates
  the same notification ("Pasted 2 of 5 …"); after the last one it says
  "Done". Esc cancels (and still reaches the window), so does the footer
  button "Pasting k of N · Cancel" when you open the popup again, and a
  queue ends by itself after 15 minutes without a paste.
  How it works: while a queue runs, `queue.sh` binds Ctrl+V and Esc at
  runtime (`hyprctl eval 'hl.bind(...)'`, removed with `hl.unbind` when it
  ends). Ctrl+V puts the next item on the clipboard and sends Shift+Insert,
  the same way Alt+Shift+N and Omarchy's universal paste do. Only Ctrl+V
  advances the queue (Ctrl+Shift+V in a terminal pastes the current item
  without advancing). Detecting pastes from the clipboard itself
  (`wl-copy --paste-once`) does not work here: every clipboard watcher
  (this plugin, Flux) reads each copy and would use the paste up.
- **Password managers:** copies marked `x-kde-passwordManagerHint` are never
  stored. Bitwarden desktop sets it on Linux for copied passwords (since
  2025, through arboard's `exclude_from_history`), as do KeePassXC and
  `wl-copy --sensitive`; wl-paste 2.3.0 then reports `CLIPBOARD_STATE=sensitive`,
  which Flux also honours, so these copies are not sent to the phone either.
  No guessing from window titles or browser fields.

## 1.18.0

- **Click action** (settings): "Select, paste & close" (default) or
  "Select (copy only)": a click only puts the item on the clipboard and the
  popup stays open.
- **QR codes:** read with ZXing (`ZXingReader` from zxing-cpp) when it is
  installed, else zbar (also retried with a white border for tightly
  cropped screenshots). zbar alone missed light-on-dark, small/blurred and
  styled codes. Images scanned by older versions are scanned once more.
- **QR previews:** a QR image row shows what is in it instead of
  "Image": `Wi-Fi name: <network>` (button: Copy Wi-Fi password),
  `QR link: example.com/…` (Open link), `QR e-mail: …` (Send email),
  `QR phone: …`, `QR contact: …`, or `QR: <text>` (Copy QR code text).
- **OCR button:** "Copy text from screenshot" / "Copy text from image".
- **Drag between sections:** drag any row into Pinned to pin it at that
  spot; drag a pinned row below Pinned to unpin it (it then goes back to its
  place by copy time).
- **Paste as Markdown** no longer adds the Markdown as a new history item,
  and the original entry is put back on the clipboard afterwards.
- **Paste queue fix:** the 2nd Ctrl+V pasted nothing (wl-copy's background
  process held the queue's lock); fixed.
- Settings list every search filter with an example.
