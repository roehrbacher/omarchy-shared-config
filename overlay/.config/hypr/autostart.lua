-- Managed by omarchy-shared-config.
-- Extra autostart processes. Machine-only ones go in hypr/machine-autostart.lua.

-- Night light. The schedule (hyprsunset.conf) is rewritten every day for your
-- location by omarchy-nightlight-sun-schedule (systemd user timer).
o.launch_on_start("hyprsunset")

require("default.hypr.require_optional").module("hypr.machine-autostart")
