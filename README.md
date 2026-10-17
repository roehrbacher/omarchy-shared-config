# Timon's Omarchy – shared config

> **Heads-up:** these are my (Timon's) personal Omarchy configs and plugins, shared as-is.
> Use them at your own risk. Before installing, read the code yourself or have your
> favorite AI review it first.

## How this setup works

I run [Omarchy](https://omarchy.org) on two machines:

- **Gaming PC** – Ryzen 7 7700, Radeon RX 9060 XT
- **Laptop** – Dell XPS 14

My config is split into three repos so nothing is duplicated:

| Repo | Used on | What it holds |
|---|---|---|
| [omarchy-shared-config](https://github.com/roehrbacher/omarchy-shared-config) | both | theme, top bar layout, my plugins, keybindings, menu, night light, auto timezone, audio passthrough, Insomnia (stay awake) |
| [omarchy-pc-config](https://github.com/roehrbacher/omarchy-pc-config) | gaming PC | monitor, mouse pointer speed, headphones/speakers switching, passthrough headphones, game and streaming tweaks |
| [omarchy-xps-config](https://github.com/roehrbacher/omarchy-xps-config) | laptop | touchpad, battery and charge limit, speaker tuning, passthrough headphones, local AI model |

```
omarchy-shared-config   (install first)
        ├── omarchy-pc-config    (then this on the PC)
        └── omarchy-xps-config   (or this on the laptop)
```

**Install order:** shared first, then the machine repo. Each `install.sh` backs up
whatever it replaces, `./install.sh --dry-run` shows what would change, and
`./uninstall.sh` restores the last backup.

## What's in this repo

- **Look:** themes installed but never applied (switching is manual), one top bar layout for both machines
- **Clipboard history:** `timon.clipboard`, GNOME Clipboard History style (Super+Shift+V)
- **Bar plugins:** audio panel, audio passthrough, now playing, Insomnia eye,
  hover-reveal, local AI toggle, idle and lock tweaks; plus two third-party
  plugins (notification center, Grokbar usage)
- **Keys and input:** shared Hyprland bindings and input settings
- **Menu:** extra rows for the Omarchy menu (Super+Space), built automatically
- **Automation:** night light by sunrise/sunset, automatic timezone, one media
  player at a time, low-battery and lid helpers (only active on a laptop)
- **Apps:** Proton Mail/Calendar/Drive web apps, LocalSend autostart, calculator

## Install

```bash
gh repo clone roehrbacher/omarchy-shared-config ~/Work/omarchy-shared-config
gh repo clone roehrbacher/omarchy-xps-config ~/Work/omarchy-xps-config   # or omarchy-pc-config
~/Work/omarchy-shared-config/install.sh
~/Work/omarchy-xps-config/install.sh                                      # or omarchy-pc-config
```

Backups go to `~/.local/share/omarchy-config-backups/<repo>/<date-time>/`;
`./uninstall.sh` puts the latest one back.

---

# Details

## How the files fit together

Nothing in one repo overwrites a file of the other:

| File | Owner | What it does |
|---|---|---|
| `hypr/hyprland.lua`, `input.lua`, `bindings.lua`, `looknfeel.lua`, `autostart.lua` | shared | thin loaders: load `shared-*.lua`, then `machine-*.lua` if it exists |
| `hypr/shared-input.lua`, `hypr/shared-bindings.lua` | shared | settings for both machines |
| `hypr/machine-*.lua` | machine repo | that machine only |
| `hypr/monitors.lua` | machine (PC) / stock (XPS) | screen setup |
| `omarchy/shell.d/00-shared.json` | shared | the one top bar, same on both |
| `omarchy/shell.d/50-<machine>.json` | machine repo | small additions (e.g. XPS battery service) |
| `voxtype/config.toml` | shared | dictation: Whisper large-v3-turbo q5_0, en+de, vocabulary hint, VAD, word replacements |
| `systemd/user/voxtype.service.d/*.conf` | machine repo | which Voxtype build/GPU runs it (PC: Radeon, XPS: Arc + flash attention) |
| `brave-flags.d/00-shared.conf` | shared | Brave flags for both machines (Wayland, keyring, extensions) |
| `brave-flags.d/50-<machine>.conf` | machine repo (optional) | that machine's Brave flags (PC: scale 1.1) |
| `brave-flags.conf` | generated | built from `brave-flags.d/` by `omarchy-brave-flags-build`; own flags go in `brave-flags.d/90-local.conf` |
| `omarchy/shell.json` | generated | built from `shell.d/` by `omarchy-shell-json-build` |
| `omarchy/menu.d/00-shared.jsonc` | shared | menu tweaks for both machines |
| `omarchy/menu.d/50-<machine>.jsonc` | machine repo (optional) | that machine's menu rows |
| `omarchy/extensions/omarchy-menu.jsonc` | generated | built from `menu.d/` + your folders by `omarchy-menu-build` |

After changing a `shell.d` file run `omarchy-shell-json-build`. A widget or plugin that
is only in the live `shell.json` (added in the UI or by an app like Flux) is kept in
place and listed as "not in repo yet"; add it to a fragment, or drop it with
`--drop-live`. The old file is saved in `~/.local/state/omarchy-config/shell-json-backups/`. Changing the bar
in the Omarchy UI edits `shell.json` directly; a new widget survives rebuilds,
but copy it into a `shell.d` fragment so the other machine and a reinstall get it too.
Reordering or setting changes made only in the UI are not kept by a rebuild.

## What is in here

**Themes** – [Liftoff](https://github.com/tcballard/omarchy-theme-liftoff) and
[Tokyo Roadster](https://github.com/tcballard/omarchy-theme-tokyo-roadster) by tcballard.
`install.sh` clones each into `~/.config/omarchy/themes/` if it is missing, at the
code-reviewed commit (list: `THEMES` in `repo.conf`), and **never applies a theme**:
switching is always manual from the theme menu. Pick the wallpaper
(launchpad, engine cluster, sunset) in Omarchy's wallpaper picker.

**Brave + summarize extensions** – Brave reads one file,
`~/.config/brave-flags.conf`; `omarchy-brave-flags-build` writes it from
`brave-flags.d/*.conf` (replaces `@HOME@`, merges every `--load-extension=` and
`--enable-features=` into one line, since Brave only honours the last). The shared
flags load Omarchy's bundled extensions plus my
[Lumo](https://github.com/roehrbacher/lumo-summarize-extension) and
[Grok](https://github.com/roehrbacher/grok-summarize-extension) summarize
extensions unpacked from `~/Work/<name>` (private repos, their code is
maintained there, not here). `install.sh` clones them if missing and
fast-forwards them when the clone is clean and on its default branch (list:
`SUMMARIZE_EXTENSIONS` in `repo.conf`). Brave picks up changed flags on its next
start; an updated extension needs a reload in `brave://extensions` or a Brave restart.

**Bar (same on both machines)** – left: menu, workspaces. Center: status
indicators (stock group + the Insomnia eye; stock behaviour: inactive ones only fade in on hover), clock
(life expectancy 100, week starts Monday, your date formats; your birth year goes in a
local, untracked `~/.config/omarchy/shell.d/90-local.json`:
`{"barSettings": {"omarchy.clock": {"birthYear": 1990}}}`),
keyboard layout, now playing, updates. Right: tray,
Tailscale, agents, Grokbar, local AI, audio (`timon.audio`), Bluetooth, network, monitor,
battery with percentage, notification center. Now playing (`<title> |
<artist>`) keeps its place but stays invisible until the pointer is over the
bar (`"revealOnHover": true`, see `timon.hover-reveal`). Grokbar shows only the
Grok Bot logo; click it for the usage panel.

**Plugins**
External plugins below are reviewed copies pinned in `plugins.lock` (id, upstream
repo, reviewed commit, date); update one only after reviewing the upstream diff. The weekly plugin round also checks `omarchy-xps-config/plugins.lock` (XPS-only plugins).

- `jankeesvw.notification-center` 1.2.0 – bell with your notification history
  (upstream: github.com/jankeesvw/omarchy-notification-center, copy from 1784e19)
- `timon.clipboard` 1.2.0 – **my own plugin** (private repo
  github.com/roehrbacher/omarchy-clipboard, copy of 7ef4489; details, keys and
  tests in its `README.md`). Clipboard history with the UX of GNOME Clipboard
  History, built on and replacing Omarchy's stock clipboard manager as a clone
  (`omarchy.clipboard` is in `disabledPlugins`, so only one watcher runs and
  stock Super+Ctrl+V opens this one). Pinned items (own section, survive
  clear and the limit), private mode (nothing saved; Super+Shift+Ctrl+V or
  Ctrl+P), case-insensitive regex search, Ctrl+1…9 / Alt+1…9 quick paste,
  Enter paste, Shift+Enter copy, Delete / Shift+Delete, 500 unpinned items,
  text and images. Password-manager copies are skipped. History stays local in
  `~/.local/share/timon.clipboard/` (0700/0600); the stock history is imported
  once. The search line is a real text field: Ctrl+A then Ctrl+C copies what
  you typed (it becomes a new history item), plus Ctrl+X/V, Shift+arrows,
  Ctrl+Backspace. **Bar icon** in the right section before the audio icon
  (fixed-width slot): left click opens/closes, right click private mode,
  incognito icon while private. **Private mode also pauses Flux** (stops
  `fluxd.service`, so nothing is synced to the phone, and starts it again when
  private mode ends, only if the plugin stopped it; Flux's own files are never
  touched). The phone link is down while private mode is on; banner, tooltip
  and notification say "Flux sync paused". Undo just this: `git revert` the
  1.2.0 commit here (turn private mode off first, or run
  `systemctl --user start fluxd`). Bar icon alone off: remove the
  `{ "id": "timon.clipboard" }` line from `bar.layout.right` in
  `shell.d/00-shared.json` and run `./install.sh`.
  **Undo** (both machines): delete `overlay/.config/omarchy/plugins/timon.clipboard`,
  its four entries in `shell.d/00-shared.json` (plugins, disabledPlugins,
  cloneSourceRestores, bar) and its block in
  `shared-bindings.lua`, add `.config/omarchy/plugins/timon.clipboard` to
  `REMOVE_PATHS`, run `./install.sh`; stock Super+Ctrl+V comes back. Before
  that, turn private mode off (or run `systemctl --user start fluxd`) so Flux
  is not left paused. Saved history:
  `rm -rf ~/.local/share/timon.clipboard ~/.local/state/timon.clipboard`.
- `timon.grok-usage` 1.7.0 – **my own plugin** (private repo
  github.com/roehrbacher/omarchy-grok-usage, based on pixbroker/grokbar-omarchy
  fdc88ed, MIT). Shows the X Premium **shared weekly pool** (panel title "Shared
  weekly pool", per-product split below; separate Cursor/Grok Bot sections are off
  via `showCursorUsage`/`showGrokBotUsage: false` in `00-shared.json`). Own
  additions: `"iconOnly": true` (logo only on the bar), tighter spacing, safer
  panel close. No longer tracked in `plugins.lock`.
- `timon.hover-reveal` 1.1.0 – invisible helper in the left section. Any bar
  entry with `"revealOnHover": true` stays invisible in its normal place
  (space kept, nothing moves) and fades in exactly like the stock indicators
  next to the clock: it follows the stock bar's own peek state (opens when the
  pointer enters the bar outside the left/right widget groups, holds while it is
  anywhere on the bar, closes 120 ms after it leaves) with the stock 140 ms
  OutCubic fade. It stays visible while its own popup is open, so popups opened
  from a key or IPC work as before. Add `"revealCollapse": true` to an entry to
  fold it to zero width instead and let it slide in. Tunable: `revealMs`,
  `hideMs` on the helper entry. Works with stock and third-party widgets alike
  without changing them; if Omarchy ever renames the bar internals it relies
  on, everything simply stays visible.
- `timon.local-ai` 0.2.0 – skull-and-crossbones icon (filled = a local model is
  running, outline = none, pulsing = loading). Click opens a popup with one
  switch per model that starts/stops its systemd user unit (never enables it);
  with `"exclusive": true` turning one on stops the others. Models come from
  `~/.config/omarchy/local-ai.json` (machine repo, optional) plus every
  `llama-*.service` user unit (`"autoDiscover": true`). Without that file or any
  units it just says no local model is running. Format:
  `plugins/timon.local-ai/local-ai.example.json`; per model `name`, `unit`,
  optional `healthUrl` (ON only once it answers 200, loading before) and `detail`.
  It also lists downloaded `.gguf` files that no model unit uses yet (section
  "Downloaded · not set up to run", read only, never started) from `modelDirs`
  (default `~/Models`, `~/models`, `~/.cache/llama.cpp`,
  `~/.cache/huggingface/hub`, `~/.lmstudio/models`; `mmproj*` and split parts
  after the first are skipped). Turn off with `"listFiles": false`. The list
  refreshes on popup open, every few seconds, and on middle click.
- `timon.idle` – stock idle plugin, but moving or clicking the mouse also closes
  the screensaver (stock only reacts to keys). Retired automatically by the hook
  below once stock can do it.
- `timon.audio` – clone of the stock audio panel (volume, output picker,
  per-app mixer) that replaces `omarchy.audio` on the bar. Differences: the
  speaker-tuning sink (`omarchy_speaker_tuning`, stock tuning or a speaker
  calibration) is hidden and the real speakers row stands for it: picking
  Speakers routes to the tuning sink when the machine has one, and that row is
  marked active while the tuning sink is the default. Outputs are set through
  `~/.local/bin/omarchy-audio-output-pick sink <name>` when a machine repo ships
  it (the PC's sticky-sink picker), otherwise Omarchy's own
  `omarchy-audio-output-set-default`. The default sink is always tracked so a
  Bluetooth default never looks muted. The tunings themselves are per machine
  and never live in this repo.
- `timon.network` – clone of the stock Network panel (Omarchy 4.0.x) plus a
  **LAN** on/off switch next to the Wi-Fi switch, shown only when the machine
  has an Ethernet device (`nmcli device disconnect|connect <iface>`; off also
  stops autoconnect until switched on). Re-copy `Panel.qml`/`Model.js` from
  `$OMARCHY_PATH/shell/plugins/panels/network/` and re-apply the `timon:` blocks
  if the stock panel changes a lot; undo = put `omarchy.network` back in `00-shared.json`.
- `timon.lock` – stock lock screen that pauses all playing media when it locks.
- `timon.indicators` – Omarchy's stock indicators group plus the Insomnia eye
  (see *Insomnia* below). Not stored here: `omarchy-indicators-build` clones it
  from the installed stock `omarchy.indicators` (same steps as
  `omarchy plugin clone`) on every install and after every Omarchy update
  (`hooks/post-update.d/rebuild-indicators`), then adds
  `.local/share/omarchy-config/indicators/Insomnia.qml` to its list just before
  StayAwake. So the group stays stock code; if a stock change breaks the build,
  the previous build is kept and you get a notification.
- `timon.media` – now-playing widget, `<title> | <artist>` (just the title when
  there is no artist); long text is cut at 15 characters and scrolls on hover.

**Omarchy menu (Super+Space)** – Omarchy reads one menu file,
`~/.config/omarchy/extensions/omarchy-menu.jsonc`; `omarchy-menu-build` writes
it from `menu.d/*.jsonc` plus a row for every folder you made, so don't edit it
by hand (put own rows in `menu.d/90-local.jsonc`). A `menu.d` row that reuses a
stock id only needs the fields it changes; the rest is copied from Omarchy's
default menu (the menu would otherwise blank them).
- **Folders** – all non-hidden folders in `~`, one level inside Desktop,
  Documents, Downloads, Music, Pictures, Videos, Projects, Work, src and
  Wallpapers, and a second level inside Desktop, Documents, Music, Pictures and
  Videos. Type a name ("down", "pic", "portraits") to open it in Nautilus. Top
  folders are listed under *Folders*; deeper ones show up in search as
  "Folders › Pictures". Skipped: hidden folders, the inside of git repos,
  node_modules/cache/build/game folders, Grok Bot's `terminals`/`agent-tools`,
  and the subfolders of any folder with more than 50 (e.g. Ente's synced
  albums). More skips: one name or `~`-relative path per line in
  `~/.config/omarchy/menu.d/folders-ignore`. Kept up to date by
  `omarchy-menu-build.path` (changes in `~` and those folders) and
  `omarchy-menu-build.timer` (login + every 15 min).
- **Power Off replaces Shutdown** – menu search matches inside words, so "down"
  found "Shutdown". The row is now *Power Off* (same command); "shut",
  "shutdown" and "power" still find it.
- **"ca"/"cal"/"calc" open OmaCalc first** – its launcher is overridden as
  "Calc (OmaCalc)" (`.local/share/applications/omacalc.desktop`; delete it if
  the omacalc package ever changes its launcher), and the Apps menu lost its
  "applications" alias, which made "ca" show Apps first. LibreOffice Calc is
  still found by "libre", "office", "spreadsheet".

**Keys**
- Alt+Space play/pause; Alt+←/→ and AltGr+←/→ previous/next track
- Ctrl+^ switch audio output (Omarchy's stock switcher)
- Super+Ctrl+Return agent picker (Grok Build); Herdr moves to Super+Shift+Ctrl+H
- Super+Shift+B Grok Bot (focus or start); the browser stays on Super+Shift+Return
- Super+Shift+C Calendar Proton, Super+Shift+E Mail Proton (no HEY keys)
- Super+Shift+W WhatsApp, Super+Shift+S Signal (replace stock Omawrite and
  Google Maps; the stock Super+Shift+Alt+G / Super+Shift+G still work)
- Super+Shift+V clipboard history (`timon.clipboard`; stock Super+Ctrl+V opens
  it too), Super+Shift+Ctrl+V clipboard private mode on/off. New keys, nothing replaced
- Super+Shift+Y (YouTube) unbound
- Print is Omarchy's stock screenshot again (omasnap is gone)
- Insert is unbound again (it used to run the screen-off script; Insomnia
  replaces it)

**Insomnia** – one more indicator in the bar's indicators group
(`timon.indicators`, see above; script `.local/bin/omarchy-insomnia`). Being a
real member, the group handles it exactly like the coffee: while off it only
appears on hover, in its slot directly left of the coffee; while a session runs
it moves into the active block next to the clock, lit, with the countdown.
Click it and pick 30 min, 1 h, 2 h, 4 h or *Until turned off*; click again to
stop or extend, right click stops. A session is the transient user unit
`omarchy-insomnia.service` holding a `systemd-inhibit` block lock; state lives
in `$XDG_RUNTIME_DIR`, so nothing survives a reboot, and it works regardless of
the coffee toggle. CLI: `omarchy-insomnia start 2h|on`, `extend 1h`, `stop`,
`status [--json]`.

What a session does depends on the machine, detected by
`.local/bin/omarchy-machine-kind` (`--why` shows the reason): **laptop** = a
system battery (peripheral batteries are skipped) **and** a lid
(`/proc/acpi/button/lid/*`), everything else is a **desktop**. Nothing is
configured per machine; an optional, unshipped `~/.config/omarchy/insomnia.conf`
can force `INSOMNIA_MODE=laptop|desktop` or override any `INSOMNIA_*` value.

- **Desktop** (the PC): inhibits `sleep`, so nothing suspends or
  hibernates; starting a session locks and turns the displays off
  (`.local/bin/omarchy-screen-off`, Omarchy's lock + DPMS off; any key or mouse
  move wakes them at the lock screen, they blank again 5 s after the last
  input); unlocking during the session ends it (you're back; checked every 5 s
  via `omarchy-shell lock isLocked`). Tooltip "Lock Omarchy and turn off
  screen".
- **Laptop** (the XPS): inhibits `sleep` and `handle-lid-switch` (polkit allows
  that for the active session, no sudo), so nothing suspends and closing the lid
  keeps it running **also on battery**. No lock on start (keep working, close the lid when done), unlocking
  doesn't end it (one session spans several close/open cycles), and it ends on
  battery at **20 %**; if the lid is closed on battery then, it suspends.
  Tooltip "Stay awake with lid closed". The laptop parts, all no-ops on a
  desktop:
  - **Lid** – `hypr/shared-bindings.lua` binds the lid switch to
    `.local/bin/omarchy-lid` (a desktop has no lid switch, so it never fires
    there). It runs Omarchy's own lid commands first (lock unless an external
    monitor is in use, clamshell); then, if the laptop keeps running closed,
    turns the display fully off and starts quiet mode. It keeps running closed
    during an Insomnia session, or on AC if logind is set to ignore the lid on
    AC (`HandleLidSwitchExternalPower=ignore`; not used on the XPS, which
    suspends on AC by choice); otherwise logind suspends and nothing is fought. Opening lights the
    lock screen, which goes dark again after 30 s without input. With an
    external monitor it's stock clamshell. `omarchy-lid why` explains the
    current decision.
  - **Quiet mode** – `.local/bin/omarchy-lid-quiet` (transient unit
    `omarchy-lid-quiet.service`) while closed: power-saver (re-asserted every
    15 s), and the apps in `omarchy/lid-freeze-apps` (Signal, Telegram, Spotify,
    Discord, Slack, Ente, …) frozen with SIGSTOP. On open they continue and the
    previous profile comes back (Omarchy's remembered AC/battery profile if
    the charger changed meanwhile; power-saver if the low-battery saver is in
    charge). Terminals, Brave, Grok Bot, Voxtype, Sunshine, Tailscale, ssh and
    local AI servers are never frozen. Safety nets: thaw on stop or crash,
    after a resume, on a missed lid-open, and at login
    (`omarchy-lid-quiet-thaw.service`). `omarchy-lid-quiet list` shows what
    would be frozen.
  - **Low-battery power saver** – `omarchy-lowbat-saver.service`: on battery at
    **20 %** it switches to power-saver once (with a notification); a manual
    change afterwards stays, plugging in resets it, Omarchy's remembered
    profiles are untouched. On a desktop the service exits at once.
  - **Power saver that sticks** – `.local/bin/omarchy-power-saver`, used by both.
    Normally just `powerprofilesctl set power-saver`. When
    `/sys/firmware/acpi/platform_profile_choices` has no low-power/quiet/cool
    choice (the XPS: Intel *SoC Power Slider* + *dell-pc* handlers only share
    `balanced performance`), power-profiles-daemon 0.30 emulates power-saver as
    platform *balanced* + EPP *power*; coming from *performance* that platform
    change is read back as an outside switch to balanced and power-saver is
    lost. Only then it steps through balanced first. `--why` shows the path.

Idle never suspends either machine anyway: stock idle only starts the
screensaver (150 s, skipped while locked) and locks (300 s), and logind's
`IdleAction` is `ignore`; the inhibitor also blocks a suspend from the menu
while a session runs. Insomnia never inhibits `idle`: the screen still blanks
and locks on the normal timers. The coffee icon (Omarchy's stay awake) is the
separate "never blank or lock" switch.
The eye is the mark of Krish Garg's macOS app
[Insomnia](https://github.com/krishhgg/Insomnia) (`docs/assets/eye-open.svg`,
MIT, copy and license in `.local/share/omarchy-config/indicators/assets/`), drawn natively in the bar's
theme colour.

**Input** – Caps Lock is a normal Caps Lock (no Compose key, no both-Shifts
Caps Lock). ProtoArc (−0.40) and Logitech G305 (−0.45) mice get their own flat
speed whenever they are plugged in.

**Night light by location** – `hyprsunset` starts at login. The
`nightlight-sun-schedule` timer rewrites `~/.config/hypr/hyprsunset.conf` every
day at 00:10 and 20 s after login: normal colours at sunrise, 4000 K at sunset.
Location comes from Omarchy's weather location; if none is saved it is looked
up from your IP over HTTPS (ipwho.is) once and saved; Vienna if offline.

**Automatic timezone** – checks your IP location (HTTPS: ipwho.is, then
ipapi.co) 45 s after boot, every 20 minutes and after network changes. If the
timezone differs it asks with a notification; clicking it switches the clock,
the weather location and the night light. Uses Omarchy's stock sudo rule for
`timedatectl set-timezone`.

**Other**
- `mpris-exclusive` – starting one player pauses the others (calls/Discord excluded)
- LocalSend starts hidden at login
- Proton web apps included: Mail, Calendar and Drive, named app-first
  ("Mail Proton", "Calendar Proton", "Drive Proton") so typing the app name
  finds them; "proton" still finds all of them. Email links open Mail Proton.
- Hook `post-update.d/remove-hey-basecamp` – removes HEY/Basecamp launchers again
  if an Omarchy refresh brings them back, and keeps mailto on Proton Mail
- Hook `post-update.d/restore-idle-when-upstream-dismisses` – after each Omarchy
  update, checks what stock idle *does*: if it now runs a second idle monitor
  while the screensaver is up **and** closes the screensaver itself, it retires
  `timon.idle`, turns stock idle back on and notifies you. If only one of the two
  shows up it just notifies once. Retired clones are listed in
  `~/.local/state/omarchy-config/retired-plugins` so installs don't bring them back.

**install.sh also removes** (after backup): `timon.power`, the old
stand-alone `timon.insomnia`, `timon.bar`, and the old post-boot timezone/night-light hooks.

## Not in any repo (on purpose)

Default agent (set by hand), stock Omarchy hooks/branding/menu, monitor scale on
the XPS, idle timings (stock 150 s / 300 s), passwords and app sessions.

## Audio passthrough

`audio-passthrough.service` (`audio-passthrough-watch`) plays your mic into the
headphones with a `pw-loopback` (two plain streams, mixer name "Audio
passthrough"), only while the headphone sink is the default output. The
headphones come from `~/.config/omarchy/audio-passthrough.machine.conf`
(`SINK=`, set by a machine repo); without it, or with them missing, it stays
idle. The mic is always the system default input and follows it live. On/off and level: the `timon.audio-passthrough` bar
widget or `omarchy-audio-passthrough on|off|volume N`, saved to
`~/.config/omarchy/audio-passthrough.conf`. The widget's INPUT list (or
`omarchy-audio-passthrough sources` / `source <node-name>`) sets the system
default mic, exactly like the stock audio panel.

## License

0BSD (see `LICENSE`), © 2026 Timon Röhrbacher. Third-party plugins and assets in `overlay/` (e.g. folders not named `timon.*`) keep their own licenses, see the `LICENSE` file inside each.
