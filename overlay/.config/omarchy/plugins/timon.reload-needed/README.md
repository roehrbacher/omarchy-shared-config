# Reload needed

An Omarchy bar widget (`timon.reload-needed`) that works like the stock
**Omarchy update** icon: same size and padding, hidden while nothing is
pending. It appears when `~/.local/state/omarchy-reload-needed` exists (the
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

MIT
