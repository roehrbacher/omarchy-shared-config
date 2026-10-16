-- Managed by omarchy-shared-config. Input settings for every machine.

hl.config({
  input = {
    -- Caps Lock is a normal Caps Lock, not Omarchy's Compose key, and
    -- both Shifts together no longer toggle Caps Lock.
    kb_options = "",
  },
})

-- Per-mouse flat pointer speed. These only apply while that mouse is plugged
-- in, so they are harmless on machines that never see it.
-- `omarchy-pointer set <id> <speed>` (gaming PC repo) rewrites this block.
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
