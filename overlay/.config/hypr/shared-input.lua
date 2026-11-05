-- Managed by omarchy-shared-config. Input settings for every machine.

hl.config({
  input = {
    -- Caps Lock is a normal Caps Lock, not Omarchy's Compose key, and
    -- both Shifts together no longer toggle Caps Lock.
    kb_options = "",
  },
})

-- Install-default per-mouse flat pointer speeds (sensible middle).
-- Machine repos MAY override these in hypr/machine-input.lua (loaded after
-- this file). On the gaming PC, `omarchy-pointer set` writes machine-input.lua
-- only — never this block — so shared sync cannot reset a tuned feel.
-- pointer-profiles:begin
hl.device({
  name = "compx-2.4g-receiver-mouse",
  sensitivity = -0.40,
  accel_profile = "flat",
})

hl.device({
  name = "logitech-g305-1",
  sensitivity = -0.45,
  accel_profile = "flat",
})

-- pointer-profiles:end
