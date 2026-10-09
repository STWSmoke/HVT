_G.DrawTriggerVisualShared = _G.DrawTriggerVisualShared or {}

local Shared = _G.DrawTriggerVisualShared

if Shared._modules_loaded then
    return
end

Shared.mod_path = Shared.mod_path or ModPath
Shared.save_path = Shared.save_path or ((rawget(_G, "SavePath") or ModPath) .. "trigger_vis_settings.txt")
Shared.settings = Shared.settings or rawget(_G, "_trigger_vis_settings") or {}

local core_path = Shared.mod_path and (Shared.mod_path .. "lua/core/")

if not core_path then
    return
end

dofile(core_path .. "settings.lua")
dofile(core_path .. "localization.lua")
dofile(core_path .. "premium_contracts.lua")
dofile(core_path .. "visuals.lua")

Shared:EnsureSettings()
Shared._modules_loaded = true
