# Running Cat

A cat that runs along the Omarchy bar at a speed set by CPU load — it strolls
when the machine is quiet, sprints when it is busy, and sleeps when it is idle.

![Running Cat animating](docs/demo.gif)

- **Speed follows load.** One full run cycle takes `busyCycleMs` at 100% CPU and
  `idleCycleMs` at 0%, easing between the two. Between readings the speed
  settles instead of snapping.
- **Sleeps when idle.** Below `idleThreshold` the running frames give way to a
  sleeping cat with Z's. `0` keeps it awake except on a true zero.
- **Follows the theme.** The frames are monochrome SVGs tinted with the bar's
  foreground color, so one set of assets works on every theme.
- **Configurable.** Every knob lives in `shell.json`, and the widget itself
  takes right-click, scroll and IPC commands.

## In the bar

![Running Cat at 32, 22 and 16 px](docs/sizes.png)

The percentage follows the sprite through `fontRatio`, so the number keeps its
proportion to the cat at any size. Scroll to resize, right click to cycle
`cat` → `cat + %` → `%`, left click to open btop.

## Install

```sh
omarchy plugin add https://github.com/kaiizu/runningcat.git --enable
```

### Remove

```sh
omarchy plugin remove io.github.kaiizu.runcat --yes
```

## Settings

```sh
omarchy bar set io.github.kaiizu.runcat display both       # cat and percentage
omarchy bar set io.github.kaiizu.runcat size 26            # bigger cat, number follows
omarchy bar set io.github.kaiizu.runcat fontRatio 0.35     # smaller number relative to the cat
omarchy bar set io.github.kaiizu.runcat idleThreshold 10   # sleep below 10% CPU
omarchy bar set io.github.kaiizu.runcat invertSpeed true   # run faster when idle
```

| key | default | what it does |
|-----|---------|--------------|
| `interval` | `2` | Seconds between CPU samples. Reads `/proc/stat` directly; no process per sample. |
| `busyCycleMs` | `250` | Time for one full run cycle at 100% CPU. Lower is faster. |
| `idleCycleMs` | `1100` | Time for one full cycle at 0% CPU. |
| `curve` | `2` | Easing exponent: `cycle = busy + (idle - busy) * (1 - cpu)^curve`. `2` matches RunCat, `1` is linear. |
| `smooth` | `true` | Ease the speed toward each new reading instead of snapping to it. |
| `smoothMs` | `500` | Time constant of that easing, in ms. |
| `idleThreshold` | `0` | CPU percentage at or below which the cat sleeps. `0` keeps it awake except on a true zero. |
| `invertSpeed` | `false` | Run faster when the CPU is idle. The cat always stays awake while inverted. |
| `display` | `cat` | `cat`, `both` or `percent` — what sits in the bar. |
| `size` | `22` | Sprite box in px (8–32). The art fills ~60% of it, so 22 draws a cat about 13px tall. |
| `fontRatio` | `0.45` | Size of the percentage as a fraction of the sprite box, so both keep their proportion. |
| `fontSize` | `0` | `0` follows the sprite through `fontRatio`; a value pins the number. |
| `spriteColor` | `""` | Empty follows the bar foreground; any `#rrggbb` fixes the tint. |
| `clickCommand` | `omarchy-launch-or-focus-tui btop` | Left-click command; empty disables it. |
| `cpuCommand` | `""` | A command that prints a CPU percentage, e.g. a GPU or remote metric. Empty reads `/proc/stat`. |
| `framesDir` | `""` | Folder of custom running frames, numbered `0.svg`, `1.svg`, … (`.png` also works). |
| `idleFramesDir` | `""` | Custom sleeping frames. One frame stays still; several cycle at the idle speed. |

The same list, with descriptions and bounds, is declared under
`barWidget.schema` in `manifest.json` for settings UIs that read it.

### Controls

| input | action |
|---|---|
| left click | run `clickCommand` (btop by default) |
| right click | cycle `cat` → `cat + %` → `%` |
| scroll | resize the cat; the percentage follows. With the cat hidden it steps the text |
| middle click | resample CPU now |
| hover | tooltip with the current CPU percentage and the controls |

### IPC

```sh
omarchy-shell io.github.kaiizu.runcat status        # cpu%, display mode, frame count, sizes
omarchy-shell io.github.kaiizu.runcat refresh       # resample every instance now
omarchy-shell io.github.kaiizu.runcat cycleDisplay  # same as right click
omarchy-shell io.github.kaiizu.runcat sizeUp
omarchy-shell io.github.kaiizu.runcat sizeDown
```

## Custom sprites

Any numbered image sequence works as a sprite set. Point `framesDir` at a
folder of `0.svg`, `1.svg`, … (or `.png`); `idleFramesDir` does the same for
the sleeping pose. Monochrome art looks best, since it is tinted with a single
color — the bundled cat is white-on-transparent so the tint is exact.

Try a different animal, a slower gait, or your own drawing:

```sh
omarchy bar set io.github.kaiizu.runcat framesDir ~/Pictures/cats
omarchy bar set io.github.kaiizu.runcat idleFramesDir ~/Pictures/cats/sleeping
```

## How it works

- **CPU** is read from `/proc/stat` through a `FileView`, so a sample costs one
  small read and no process. Usage is the ratio of jiffie deltas between two
  samples — what `top` and `btop` report. `cpuCommand` replaces the source
  entirely when set.
- **Speed** is RunCat's curve `f(x) = 250 + 850 * (1 - x)^2` ms per full cycle,
  generalized by `busyCycleMs`, `idleCycleMs` and `curve`. A frame timer re-arms
  itself to the next frame boundary, so frames stay even at any speed, and an
  exponential moving average (`smooth`, `smoothMs`) absorbs spikes. Long gaps —
  suspend, sleep — are treated as stalls rather than jumping the animation.
- **Color** comes from a `MultiEffect` that colorizes the white SVG frames with
  the bar foreground, the same trick the bar's tray uses for symbolic icons.
- **Writes** go through the shell's in-process `updateEntryInline`, the same
  path the netspeed widget uses, so a scroll writes one atomic settings update
  and nothing can land out of order.

![The five running frames and the sleeping pose](preview.png)

## Development

`Model.js` holds the parsing, speed curve and frame ticker with no QML imports;
`npm test` runs its Node tests. To hack on the widget against a live bar:

```sh
ln -s ~/Projects/runningcat ~/.config/omarchy/plugins/io.github.kaiizu.runcat
omarchy plugin enable io.github.kaiizu.runcat
```

Edits made through the symlink are invisible to the shell's file watcher —
`inotifywait -r` does not descend into symlinked directories, and
`omarchy-shell shell rescanPlugins` re-reads manifests but not widget code.
Reload with `omarchy restart shell` after changing `BarWidget.qml`. To get
automatic reloads while developing, keep the working copy in the plugins
directory instead and symlink it back into your projects folder.

`tools/build-preview.sh` regenerates `preview.png` and `docs/demo.gif` from the
sprite assets (needs `rsvg-convert` and ImageMagick). `docs/sizes.png` is a
screenshot of the running widget.

## Credits and license

**The idea and the cat** are from [RunCat for macOS](https://github.com/Kyome22/menubar_runcat)
by Takuto Nakamura — a cat that runs in the menu bar at a speed set by CPU
load. The same idea was brought to other desktops by
[gnome-runcat](https://github.com/win0err/gnome-runcat) by Sergei Kolesnikov
for GNOME, and [CatWalk](https://store.kde.org/p/2137844/) by Yuri Saurov for
KDE Plasma.

**The sprite frames** in `assets/` are gnome-runcat's symbolic SVG set
(including the sleeping pose), used under the GPL-3.0. gnome-runcat credits
the cat images to RunCat for macOS, which is Apache-2.0.

**The animation** — the speed curve `f(x) = 250 + 850 * (1 - x)^2`, the
frame-boundary ticker and the smoothed speed changes — follows gnome-runcat's
port of RunCat's animation. The widget code here is written for the Omarchy
shell.

Because the frames are GPL-3.0, this plugin is GPL-3.0 as well. See `LICENSE`
and `NOTICE.md` for the full attribution.
