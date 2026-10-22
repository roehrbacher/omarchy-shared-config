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

## Glance looks (local patch, trial)

With "Icon only" on, the bar setting `"glanceVariants": "4,5,6,7,8,9"` adds Grok Bot
weekly-usage looks right of the icon (`GlanceVariant.qml`): 1 ring + day dots,
2 ring + "Nd", 3 two bars (usage, time left in the week), 4 ring that turns
`bar.active` when usage runs ahead of the week. Hugging looks (all with 4's
pace colour): 5 thin ring touching the logo disc, 6 ring centred on the disc
edge, 7 logo scaled up into look 4's ring, 8 the logo disc itself is the
gauge, 9 thick 3 px ring touching the disc. Drop numbers to remove looks;
`""` turns it off. Offscreen render: `bash tests/glance/run.sh /tmp/glance`
(software renderer; the icon's MultiEffect tint isn't drawn there).
