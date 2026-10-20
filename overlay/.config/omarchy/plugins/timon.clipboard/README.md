# Nice Clipboard History

<!-- Preview image goes here once it exists, e.g. ![Nice Clipboard History](preview.png) -->


Clipboard history for [Omarchy](https://omarchy.org) with the feel of
[GNOME Clipboard History](https://github.com/SUPERCILEX/gnome-clipboard-history):
pinned items, private mode, instant regex search and Ctrl+1…9 quick picks.

It is built on Omarchy's own clipboard manager (`omarchy.clipboard`) and
**replaces** it as a clone (`"clonedFrom": "omarchy.clipboard"`), so there is
only ever one clipboard watcher running. Your existing stock history is
imported once on first start. Uses the current theme's menu colors.

## Shortcuts

| Key | What it does |
|---|---|
| **Super+Shift+V** | open / close clipboard history (GNOME default key) |
| Super+Ctrl+V | the same (stock Omarchy key, routed to this plugin) |
| **Super+Shift+Ctrl+V** | private mode on/off from anywhere (with a notification) |

In the popup:

| Key | What it does |
|---|---|
| type | search (case-insensitive regex; invalid regex = plain text) |
| ↑ ↓ / Ctrl+K Ctrl+J, PgUp PgDn, Home End | move through the list |
| Enter / click | paste into the window you came from |
| Shift+Enter | copy only |
| Alt+Enter | open (URL in browser, text in editor, image in editor) |
| Ctrl+1…9 | paste the Nth history item |
| Alt+1…9 | paste the Nth pinned item |
| Ctrl+F (or the pin icon) | pin / unpin |
| Delete (or the trash icon) | delete the item (with search text selected: delete that text) |
| Shift+Delete | clear history (asks first; pinned items stay) |
| Ctrl+P (or the footer switch) | private mode on/off |
| Backspace, Ctrl+Backspace, ← →, Ctrl+Z | edit the search |
| Ctrl+U | clear the search |
| Shift+← → / Shift+Home End, Ctrl+A, mouse drag | select search text |
| Ctrl+C / Ctrl+X (with search text selected) | copy / cut it to the clipboard (becomes a new history item) |
| Ctrl+V | paste into the search |
| Esc | clear the search, then close |

## Behaviour

- **History:** newest first, a re-copied item moves to the top. Keeps the last
  500 unpinned items (`historyLimit` at the top of `Clipboard.qml`); pinned
  items never count against the limit. Text and images (PNG, JPEG, WebP, GIF,
  …); copied files show their file name and an image preview.
- **Pinned:** shown in their own section at the top, survive "clear history"
  and the limit.
- **Private mode:** nothing new is saved (text or images) until you turn it
  off; a banner in the popup shows it. Survives a restart.
- **Private mode pauses Flux too:** if [Flux](https://github.com/bjarneo/flux)
  (`fluxd.service`) runs, private mode stops it, so copies are not synced to
  the phone or saved in Flux's history; turning private mode off starts it
  again. The popup banner, the bar tooltip and the notification say
  "Flux sync paused". See "Flux" below.
- **Deleting the item that is on the clipboard right now** puts the next newest
  item back on the clipboard (or empties it), like GNOME.
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

Bar icon: add `{ "id": "timon.clipboard" }` to a bar section (for example the
right section, before the audio icon). It uses the standard
fixed-width bar icon slot, so switching icons never shifts its neighbours.
Left click opens / closes the history, right click toggles private mode, and it
turns into the incognito icon (󰗹) while private mode is on.

## Flux

`fluxd` watches the clipboard itself (its own `wl-paste --watch`) and has no
pause switch of its own that fits: its `autoClipboard` setting would still keep
the last private copy in memory and hand it to the phone when it reconnects,
and it would change Flux's config file. So `flux-pause.sh` simply stops and
starts Flux's systemd user unit (`systemctl --user stop|start fluxd.service`).
Nothing of Flux (binary, unit, config) is touched, so a Flux update cannot undo
this. When fluxd starts again it records the current clipboard without sending
it, so nothing copied during private mode reaches the phone.

- Flux is only started again if this plugin stopped it (marker file in
  `~/.local/state/timon.clipboard/`). If Flux was off already, or you ran
  `flux-cli off` meanwhile, it stays off.
- Every shell start runs the same sync: if private mode ended while the shell
  was down (crash, reboot), Flux is started; if private mode is still on after
  a reboot, the fluxd that systemd started at login is stopped again.
- Uninstalling (`clipboard.sh wipe`) starts Flux first if we paused it.
- No Flux installed: nothing happens, nothing is logged.
- While paused, the whole phone link is down (notifications, SMS, calls, file
  transfer, phone approval of sudo), and Flux's own bar icon says "fluxd is not
  running". That is the price of a clean pause; it comes back with private mode
  off. Starting Flux from its own panel during private mode is allowed and
  sticks until the next private-mode toggle or shell start.

By hand: `flux-pause.sh status` (`paused`, `running`, `off`, `absent`),
`flux-pause.sh resume` (start Flux if we stopped it).

IPC (for scripts): `omarchy-shell shell call timon.clipboard togglePrivate x`,
`setPrivateMode on|off`, `status x` (includes `fluxPaused`).

## Install

```bash
omarchy plugin add https://github.com/roehrbacher/omarchy-clipboard --enable
```

The plugin ID is `timon.clipboard`. Enabling it switches off the stock
`omarchy.clipboard` (it is a clone of it), so only one clipboard watcher runs.
Then add the two shortcuts to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + V", "Clipboard history", "omarchy-shell shell toggle timon.clipboard")
o.bind("SUPER + SHIFT + CTRL + V", "Clipboard private mode", "omarchy-shell shell call timon.clipboard togglePrivate x")
```

and run `omarchy restart shell`.

## Update

```bash
omarchy plugin update timon.clipboard && omarchy restart shell
```

The plugin is `keepLoaded`, so code changes need a shell restart.

## Uninstall

```bash
~/.config/omarchy/plugins/timon.clipboard/flux-pause.sh resume   # start Flux again if private mode had paused it
omarchy plugin remove timon.clipboard      # brings back the stock omarchy.clipboard
rm -rf ~/.local/share/timon.clipboard      # optional: deletes the saved history
omarchy restart shell
```

Remove the two bindings too. Super+Ctrl+V then opens the stock manager again.
To only switch it off and keep it installed: `omarchy plugin disable timon.clipboard`.

## Tests

```bash
node tests/history.test.js     # history model: limit, pins, search, clear; search-field key routing
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_searchfield.qml  # search field keys (real Qt)
bash tests/capture.test.sh     # capture: private mode, password hint, size caps, 0600/0700, import, prune
bash tests/flux-pause.test.sh  # Flux pause/resume with a stub systemctl (never touches the real fluxd)
```

See `TESTING.md` for the last manual run.

## Credit

Built on Omarchy's stock clipboard manager (`shell/plugins/clipboard`, MIT,
David Heinemeier Hansson). UX modelled on GNOME Clipboard History by Alex
Saveau (MIT); no code from it is used.
