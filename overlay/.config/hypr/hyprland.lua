-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/
--
-- Managed by omarchy-shared-config. Same file on every machine.
-- Shared settings live in hypr/shared-*.lua (omarchy-shared-config).
-- Machine settings live in hypr/machine-*.lua (omarchy-xps-config /
-- omarchy-pc-config). Each pair is loaded from the matching stock file
-- (input.lua, bindings.lua, ...), so neither repo overwrites the other.

-- Omarchy's bootstrap keeps path setup out of this user config.
dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Load Omarchy defaults.
require("default.hypr.omarchy")

-- Personal overrides, loaded after Omarchy's defaults.
-- monitors.lua is per machine (stock on the XPS, 180 Hz on the PC).
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")

-- Machine window rules (XPS: tiling + Moonlight, PC: Steam/Overwatch).
require("default.hypr.require_optional").module("hypr.machine-windows")

-- Toggle config flags dynamically.
require("default.hypr.toggles")
