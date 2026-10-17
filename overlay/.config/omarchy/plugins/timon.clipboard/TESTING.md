# Test run – 2026-10-17, Dell XPS 14, Omarchy 4.0.4

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
