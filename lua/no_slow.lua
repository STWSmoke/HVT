if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if not Shared then
    return
end

Shared:Load()

Hooks:PostHook(TimeSpeedEffectTweakData, "_init_base_effects", "DrawRework_NoSlow_InitBaseEffects", function(self)
    Shared:ApplyNoSlowMotion(self)
end)
