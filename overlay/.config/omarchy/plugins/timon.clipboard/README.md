# timon.clipboard

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
| ↑ ↓ / Ctrl+K Ctrl+J, PgUp PgDn, Home End | move |
| Enter / click | paste into the window you came from |
| Shift+Enter | copy only |
| Alt+Enter | open (URL in browser, text in editor, image in editor) |
| Ctrl+1…9 | paste the Nth history item |
| Alt+1…9 | paste the Nth pinned item |
| Ctrl+F (or the pin icon) | pin / unpin |
| Delete (or the trash icon) | delete the item |
| Shift+Delete | clear history (asks first; pinned items stay) |
| Ctrl+P (or the footer switch) | private mode on/off |
| Backspace, Ctrl+Backspace, Ctrl+U | edit the search |
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
- **Deleting the item that is on the clipboard right now** puts the next newest
  item back on the clipboard (or empties it), like GNOME.
- **Skipped automatically:** copies from password managers
  (`x-kde-passwordManagerHint`, `CLIPBOARD_STATE=sensitive`), text over 4 MiB,
  images over 25 MiB.
- **Storage:** only `~/.local/share/timon.clipboard/` (folder `0700`, files
  `0600`): `history.json`, `state.json`, `images/`. Nothing is logged, synced
  or sent anywhere. Unreferenced images are deleted automatically.
- Clipboard text is read by index from that file, never passed on a command
  line, so it does not show up in process lists.

Optional bar icon (not on the bar by default): add `{ "id": "timon.clipboard" }`
to a bar section. Left click opens the history, right click toggles private
mode, and it turns into the incognito icon while private mode is on.

IPC (for scripts): `omarchy-shell shell call timon.clipboard togglePrivate x`,
`setPrivateMode on|off`, `status x`.

## Install

In [omarchy-shared-config](https://github.com/roehrbacher/omarchy-shared-config)
this plugin is vendored and installed by `./install.sh` (bindings in
`hypr/shared-bindings.lua`, enabled in `shell.d/00-shared.json`). On its own:

```bash
gh repo clone roehrbacher/omarchy-clipboard ~/.config/omarchy/plugins/timon.clipboard
```

then add to `~/.config/omarchy/shell.json` (or a `shell.d` fragment):
`"plugins": [{ "id": "timon.clipboard" }]`, `"omarchy.clipboard"` in
`"disabledPlugins"` and `"timon.clipboard"` in `"cloneSourceRestores"`, the
two bindings from above to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + V", "Clipboard history", "omarchy-shell shell toggle timon.clipboard")
o.bind("SUPER + SHIFT + CTRL + V", "Clipboard private mode", "omarchy-shell shell call timon.clipboard togglePrivate x")
```

and run `omarchy restart shell`.

## Update

```bash
git -C ~/.config/omarchy/plugins/timon.clipboard pull && omarchy restart shell
```

(In the shared config: copy the new files into
`overlay/.config/omarchy/plugins/timon.clipboard/`, then `./install.sh`.) The
plugin is `keepLoaded`, so code changes need a shell restart.

## Uninstall

```bash
omarchy plugin disable timon.clipboard      # switches back to stock omarchy.clipboard
rm -rf ~/.config/omarchy/plugins/timon.clipboard
rm -rf ~/.local/share/timon.clipboard       # optional: deletes the saved history
omarchy restart shell
```

Remove the two bindings too. Super+Ctrl+V then opens the stock manager again.
With omarchy-shared-config, see "Undo" in its README instead (a `shell.d`
rebuild would otherwise turn it back on).

## Tests

```bash
node tests/history.test.js     # history model: limit, pins, search, clear
bash tests/capture.test.sh     # capture: private mode, password hint, size caps, 0600/0700, import, prune
```

See `TESTING.md` for the last manual run.

## Credit

Built on Omarchy's stock clipboard manager (`shell/plugins/clipboard`, MIT,
David Heinemeier Hansson). UX modelled on GNOME Clipboard History by Alex
Saveau (MIT); no code from it is used.
