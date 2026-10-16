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
