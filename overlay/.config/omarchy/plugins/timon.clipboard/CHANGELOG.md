# Changelog

Newest first. Older history is in the git log.

## 1.23.0

- Renamed to Nice Clipboard (repo roehrbacher/Nice-Clipboard, display name). Plugin id stays timon.clipboard, so history, settings and key bindings keep working.
- README: short "TL;DR for humans" first, "Details for Agents" after it; Shortcuts moved after Flux.

## 1.22.0

- Paste queue works with Super+V (Omarchy's universal paste) as well as Ctrl+V. While a queue runs, the stock Super+V bind is swapped for "paste next"; when the queue ends (done, Esc, a new pick, the watchdog) Super+V gets Omarchy's universal paste back (same behaviour: Shift+Insert in terminals, Ctrl+V elsewhere). A Hyprland config reload also restores it.
- Notifications say Super+V: "Pasted 1 of 4. Super+V pastes 2 next. Esc cancels.", and "Paste it with Super+V." after copying a QR / Wi-Fi / screenshot text.

## 1.21.0

- The "Paste queue: N items in order" line sits on a pill in the same accent colour as the numbered queue circles (text in the circles' number colour).
- Queue notification: title "Paste queue ready:", body "Paste 1 of N. Esc cancels."
- A paste queue is forgotten silently as soon as you do anything else in the popup: a normal pick (click, Enter, Alt+N, Shift/Alt+Enter) or a row button (text from screenshot, QR text / Wi-Fi password, open link, Markdown / plain text, send). Ctrl-selected rows are dropped too, so a button never starts a queue. Selecting 2+ rows and closing still starts a new queue.
- OCR settings help is two lines: what a click does, and why there is no install button.
- "Copied text from screenshot" uses the copy icon (󰆏).
- No incognito on/off notifications any more: the popup and the bar icon show it.

## 1.20.0

- Paste queue info line is now just "Paste queue: N items in order" (the old "· Ctrl+V pastes them one by one" got cut off; the "Queue ready" notification still says it).
- OCR on screenshots: the QR code area (corners from ZXing) is painted over before tesseract runs, and tesseract's word confidences drop junk: symbols read from icons next to labels, low-confidence non-words and symbol-only lines (`ocr-clean.awk`). Older image scans are redone once.
- Notifications use `omarchy-notification-send` with a glyph and a body line, so they get the same large icon as Omarchy's own: Wi-Fi password (lock), QR code text (QR), text from screenshot/image (text recognition), incognito on/off, install command (terminal), paste queue (numbered list).
- Opening the popup while the clipboard is empty puts the top pinned item on the clipboard (copy only, never pasted; nothing happens without a pinned item; a password-manager copy doesn't count as empty).
- Settings: "Languages for text recognition (OCR)" lists 16 popular languages; installed ones are marked, a click copies `sudo pacman -S tesseract-data-<code>`. No install button on purpose: installing system packages needs your sudo password, and the plugin never runs root commands or downloads anything itself.

## 1.19.0

- Paste queue starts by itself: select 2+ items with Ctrl+click or Ctrl+Space and close the popup. Notification: "Queue ready: N items. Ctrl+V pastes 1 of N. Esc cancels." One Ctrl+clicked item is a normal pick. Reopening during a queue shows progress, badges and Cancel. A new 2+ selection replaces a running queue.
- The item currently on the clipboard has an accent bar on the left (updates live).
- Images with a QR code and text show both buttons. Wi-Fi QR uses a lock icon.
- Paste as Markdown (M glyph) always comes with Paste as plain text.
- Dragging a pinned item into History unpins it and puts it at the top of History.
- OCR languages: all installed tesseract packs are used (eng first, at most 3), or `OMARCHY_OCR_LANGS` (e.g. `eng+deu`, filtered to installed packs). Settings lists installed languages and shows a copyable install command such as `sudo pacman -S tesseract-data-deu`. Nothing is downloaded or installed automatically.

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

