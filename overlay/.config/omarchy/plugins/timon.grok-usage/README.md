# timon.grok-usage

Omarchy bar widget that shows your X Premium **shared weekly pool** (Grok, Grok Bot
and Cursor draw from one pool). The panel title reads "Shared weekly pool" with the
per-product split below; optional Cursor, Grok Bot and GPT (Codex) sections.

Local options on top of the original:
- `iconOnly` – only the Grok Bot logo on the bar, no numbers (panel unchanged)
- tighter spacing and a safer panel close

Credentials are read from local files only (`~/.grok/auth.json`, Cursor and Codex
auth files); nothing is stored in this repo.

## Install

```bash
git clone git@github.com:roehrbacher/omarchy-grok-usage.git ~/.config/omarchy/plugins/timon.grok-usage
omarchy plugin enable timon.grok-usage --section right
omarchy bar set timon.grok-usage iconOnly true --json        # optional
omarchy bar set timon.grok-usage showCursorUsage false --json # optional
omarchy restart shell
```

## Undo

```bash
omarchy plugin disable timon.grok-usage
rm -rf ~/.config/omarchy/plugins/timon.grok-usage
omarchy restart shell
```

## Credit

Based on [grokbar-omarchy](https://github.com/pixbroker/grokbar-omarchy) by pixbroker
(fork of commit fdc88ed), MIT licensed. The original `LICENSE` is kept unchanged.

## Usage ring (local patch)

With "Icon only" on, `"usageRing": true` draws the Grok Bot weekly usage as a
3 px ring hugging the logo (`UsageRing.qml`, track visible). It is the bar
foreground normally and `bar.active` when usage runs ahead of the week.
Offscreen render: `bash tests/glance/run.sh /tmp/glance` (software renderer;
the icon's MultiEffect tint isn't drawn there).
