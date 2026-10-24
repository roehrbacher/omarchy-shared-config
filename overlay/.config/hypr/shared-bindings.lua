-- Managed by omarchy-shared-config. Key bindings for every machine.
-- Unbind a default before replacing it.

-- Media: play/pause and skip (same as XF86AudioPlay/Prev/Next).
-- Left Alt is ALT; right Alt on a German layout is AltGr (MOD5).
o.bind("ALT + SPACE", "Play/Pause", "omarchy-shell media playPause", { locked = true })
o.bind("ALT + LEFT", "Previous track", "omarchy-shell media previous", { locked = true })
o.bind("ALT + RIGHT", "Next track", "omarchy-shell media next", { locked = true })
o.bind("MOD5 + LEFT", "Previous track", "omarchy-shell media previous", { locked = true })
o.bind("MOD5 + RIGHT", "Next track", "omarchy-shell media next", { locked = true })

-- Lid (laptops; a desktop has no lid switch, so these never fire there):
-- omarchy-lid runs the stock lid commands first (omarchy-system-lid-close /
-- omarchy-hyprland-monitor-clamshell), then, if the laptop keeps running
-- closed (Insomnia session, or AC with logind ignoring the lid on AC), turns
-- the display fully off and starts quiet mode.
hl.unbind("switch:on:Lid Switch")
hl.unbind("switch:off:Lid Switch")
o.bind("switch:on:Lid Switch", nil, "omarchy-lid close", { locked = true })
o.bind("switch:off:Lid Switch", nil, "omarchy-lid open", { locked = true })

-- Switch audio output on Ctrl+^ (German dead circumflex / US caret /
-- physical key left of 1 = code:49) with Omarchy's stock switcher.
-- Replaces the default SHIFT + XF86AudioMute.
hl.unbind("SHIFT + XF86AudioMute")
o.bind("CTRL + dead_circumflex", "Switch audio output", "omarchy-audio-output-next", { locked = true })
o.bind("CTRL + asciicircum", "Switch audio output", "omarchy-audio-output-next", { locked = true })
o.bind("CTRL + code:49", "Switch audio output", "omarchy-audio-output-next", { locked = true })

-- Agent (Grok Build / whatever agent is picked) on SUPER + CTRL + RETURN.
-- Herdr moves from there to SUPER + SHIFT + CTRL + H; the old Agent key goes.
hl.unbind("SUPER + SHIFT + CTRL + A")
hl.unbind("SUPER + CTRL + RETURN")
o.bind("SUPER + CTRL + RETURN", "Agent", "omarchy-agent --pick")
o.bind("SUPER + SHIFT + CTRL + H", "Herdr", { omarchy = "terminal-herdr" })

-- Proton instead of HEY for calendar and email. No HEY "new email" key.
hl.unbind("SUPER + SHIFT + C")
hl.unbind("SUPER + SHIFT + E")
hl.unbind("SUPER + SHIFT + ALT + E")
o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://calendar.proton.me" })
o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://mail.proton.me" })

-- YouTube web app is not used.
hl.unbind("SUPER + SHIFT + Y")

-- Grok Bot desktop app on SUPER + SHIFT + B: focuses the open window, or starts
-- it. Window class is "grok-bot" on both machines. Replaces stock Browser on
-- this key; the browser stays on stock SUPER + SHIFT + RETURN.
hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "Grok Bot", { launch = "grok-bot", focus = "^grok-bot$" })

-- Telegram on SUPER + SHIFT + T: focuses the open window, or starts it.
o.bind("SUPER + SHIFT + T", "Telegram", { launch = "Telegram", focus = "^org.telegram.desktop$" })

-- Messengers on easy keys (Super+Shift+Alt+G still opens WhatsApp too).
-- Replaces stock SUPER+SHIFT+W (was: Omawrite) and SUPER+SHIFT+S (was: Google Maps).
hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "WhatsApp", { webapp = "https://web.whatsapp.com/", focus = true })
hl.unbind("SUPER + SHIFT + S")
o.bind("SUPER + SHIFT + S", "Signal", { omarchy = "signal" })

-- Steam on SUPER + SHIFT + G ("G" for gaming): focuses the open Steam window,
-- or starts it. Replaces stock Signal on this key (Signal is on SUPER + SHIFT + S).
hl.unbind("SUPER + SHIFT + G")
o.bind("SUPER + SHIFT + G", "Steam", { launch = "steam", focus = "^steam$" })

-- Clipboard history (timon.clipboard, GNOME Clipboard History style).
-- Open it with Alt+V or the stock SUPER + CTRL + V ("Clipboard manager"),
-- which calls omarchy.clipboard; the shell routes that to this clone.
o.bind("ALT + V", "Clipboard history", "omarchy-shell shell toggle timon.clipboard")

-- Alt+Shift+1..9: paste the Nth pinned item anywhere, popup closed.
-- Runs paste-pinned.sh detached (exec), so Hyprland never waits on it:
-- waiting on wl-copy deadlocks the compositor (it froze the PC once).
-- The script copies the pin (nothing if there is no Nth pin), then sends
-- Shift+Insert with explicit mods. Keys by keycode (German layout safe).
-- Undo: delete this block.
local paste_pinned = (os.getenv("HOME") or "") .. "/.config/omarchy/plugins/timon.clipboard/paste-pinned.sh"
for n = 1, 9 do
  o.bind("ALT + SHIFT + code:" .. tostring(n + 9), "Paste pinned clipboard item " .. n, "setsid -f " .. paste_pinned .. " " .. n)
end
o.bind("SUPER + SHIFT + CTRL + V", "Clipboard incognito", "omarchy-shell shell call timon.clipboard toggleIncognito x")

-- Super+F: browsers keep their tabs visible in full screen (omarchy-fullscreen-smart);
-- other windows get the normal full screen. Undo: delete these two lines.
hl.unbind("SUPER + F")
o.bind("SUPER + F", "Full screen", "omarchy-fullscreen-smart")

-- Super+wheel: workspaces from lowest occupied - 1 to highest occupied + 1
-- (1..10), empty ones in between included; stops at the ends (no wrap).
-- Runs detached (setsid -f), so Hyprland never waits on it.
-- Undo: delete this block (stock e+1/e-1 binds come back).
hl.unbind("SUPER + mouse_down")
hl.unbind("SUPER + mouse_up")
o.bind("SUPER + mouse_down", "Scroll active workspace forward", "setsid -f omarchy-workspace-scroll next")
o.bind("SUPER + mouse_up", "Scroll active workspace backward", "setsid -f omarchy-workspace-scroll prev")
