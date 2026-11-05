-- Managed by omarchy-shared-config. Key bindings for every machine.
-- Unbind a default before replacing it.

-- Media: play/pause and skip (same as XF86AudioPlay/Prev/Next).
-- Left Alt is ALT; right Alt on a German layout is AltGr (MOD5).
-- Omarchy 4.5 puts dictation on Alt+Space; keep it for Play/Pause (Voxtype PTT is Shift+Left Alt).
hl.unbind("ALT + SPACE")
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

-- Grok Bot desktop app on SUPER + B: focuses the open window, or starts it.
-- Window class is "grok-bot" on both machines. Bitwarden on SUPER + SHIFT + B
-- (replaces stock Browser there; the browser stays on SUPER + SHIFT + RETURN).
hl.unbind("SUPER + B")
o.bind("SUPER + B", "Grok Bot", { launch = "grok-bot", focus = "^grok-bot$" })
hl.unbind("SUPER + SHIFT + B")
o.bind("SUPER + SHIFT + B", "Bitwarden", { launch = "bitwarden-desktop", focus = "^Bitwarden$" })

-- Bitwarden Brave extension as its own tiled window on Left Alt + B.
-- ALT is Left Alt only; Right Alt on the German layout is AltGr (MOD5) and
-- stays untouched. This takes Alt+B from apps (readline backward-word in
-- terminals; Ctrl+Left still does that). omarchy-launch-webapp opens it with brave --app=... in the
-- default profile. Brave names the class brave-<id>__popup_index.html-Default;
-- stock apps/bitwarden.lua tags chrome-<id>-Default floating, so drop that
-- tag and tile for every browser variant (the native Bitwarden app rule is
-- separate and unchanged).
hl.unbind("SUPER + ALT + B")
o.bind("ALT + B", "Bitwarden (browser extension)", { webapp = "chrome-extension://nngceckbapebfimnlniiiahkandclblb/popup/index.html?uilocation=popout" })
o.window("^(brave|chrome|chromium)-nngceckbapebfimnlniiiahkandclblb[-_].*$", { tag = "-floating-window", tile = true })

-- Telegram on SUPER + SHIFT + T: focuses the open window, or starts it.
hl.unbind("SUPER + SHIFT + T")
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

-- Downloads folder on SUPER + SHIFT + D. Replaces stock Docker on this key.
hl.unbind("SUPER + SHIFT + D")
o.bind("SUPER + SHIFT + D", "Downloads", { launch = "nautilus --new-window " .. os.getenv("HOME") .. "/Downloads" })

-- Grok usage popup (timon.grok-usage's own IPC; the bar widget must be on the bar).
-- New key, free in stock Omarchy, nothing replaced.
o.bind("SUPER + SHIFT + U", "Grok usage", "omarchy-shell -q timon.grok-usage toggle")

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
  o.bind("ALT + SHIFT + code:" .. tostring(n + 9), "Paste pinned clipboard item " .. n, "voxtype-ptt cancel; setsid -f " .. paste_pinned .. " " .. n)
end

-- Voxtype push-to-talk: hold Shift + Left Alt (either order) to talk,
-- release either key to stop and paste. Starts fire on whichever key goes
-- down second; stops fire on the release of either key with any mod state,
-- so a stop always lands. All non-consuming, so Alt/Shift still reach apps
-- and Alt+Shift+<key> shortcuts keep working (voxtype-ptt cancels taps
-- under 0.35 s and the pinned-paste binds cancel explicitly).
-- Replaces the stock F9 / Super+Ctrl+X dictation keys on both machines.
hl.unbind("F9")
hl.unbind("SUPER + CTRL + X")
for _, start in ipairs({ "SHIFT + Alt_L", "SHIFT + ALT + Alt_L", "ALT + Shift_L", "ALT + SHIFT + Shift_L" }) do
  o.bind(start, "Start dictation (push-to-talk)", "voxtype-ptt start", { repeating = false, non_consuming = true })
end
for _, key in ipairs({ "Alt_L", "Shift_L" }) do
  for _, mods in ipairs({ "", "SHIFT + ", "ALT + ", "SHIFT + ALT + " }) do
    o.bind(mods .. key, "Stop dictation (push-to-talk)", "voxtype-ptt stop", { release = true, non_consuming = true })
  end
end
o.bind("SUPER + SHIFT + CTRL + V", "Clipboard incognito", "omarchy-shell shell call timon.clipboard toggleIncognito x")

-- Super+F: browsers keep their tabs visible in full screen (omarchy-fullscreen-smart);
-- other windows get the normal full screen. Undo: delete these two lines.
hl.unbind("SUPER + F")
o.bind("SUPER + F", "Full screen", "omarchy-fullscreen-smart")

-- Super+wheel: Omarchy's stock binds (workspace e+1 / e-1, existing
-- workspaces only, empty ones skipped) are used as-is.

-- Workspace overview (timon.overview, github.com/roehrbacher/omarchy-overview)
-- on Super+A (Super+Ctrl+A audio, Super+Shift+A ChatGPT, Super+Shift+Alt+A Grok stay). Toggles.
hl.unbind("SUPER + A")
o.bind("SUPER + A", "Workspace overview", "omarchy-shell shell toggle timon.overview")
