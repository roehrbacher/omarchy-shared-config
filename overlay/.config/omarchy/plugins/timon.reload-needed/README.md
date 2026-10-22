# Reload needed

An Omarchy bar widget (`timon.reload-needed`) that works like the stock
**Omarchy update** icon: same size and padding, hidden while nothing is
pending. The icon is the Quickshell logo in the theme colour. It appears when `~/.local/state/omarchy-reload-needed` exists (the
first line is the tooltip) and a left click deletes the flag and runs
`omarchy restart shell`.

Installers call the helper instead of restarting the shell:

```bash
omarchy-mark-reload-needed "timon.clipboard 1.10.2"
omarchy-mark-reload-needed --clear
```

## Install

Copy this folder to `~/.config/omarchy/plugins/timon.reload-needed/` and
`bin/omarchy-mark-reload-needed` to `~/.local/bin/`. The plugin is not added
to the bar: place it yourself in the bar settings.

## License

MIT (see `LICENSE`), except `quickshell-logo.svg`: the Quickshell logo (gear
shaped like a Q) from quickshell.org, by the Quickshell project, which ships
it in its repo (`assets/quickshell.svg`) under the GNU LGPL 3 with no separate
logo terms. Only the white gear shape is used (green tile removed), recoloured
at runtime. Its licence text is in `LICENSE-quickshell-logo`.
