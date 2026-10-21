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

- **History:** newest first, a re-copied item moves to the top. Keeps the last
  500 unpinned items (`historyLimit` at the top of `Clipboard.qml`); pinned
  items never count against the limit. Text and images (PNG, JPEG, WebP, GIF,
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
- **Header:** search field ("Search clipboard…") and the count.
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
