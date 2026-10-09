if rawget(_G, "HVTLocalizationLoaderLoaded") then
    return
end

_G.HVTLocalizationLoaderLoaded = true

if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/core/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if Shared and type(Shared.Load) == "function" then
    pcall(function()
        Shared:Load()
    end)
end

local function resolve_language()
    if Shared and type(Shared.GetLocalizationLanguageName) == "function" then
        return Shared:GetLocalizationLanguageName()
    end

    return "english"
end

local function load_language_file(language)
    local mod_path = ModPath or ""
    local file_name = language == "french"
        and "lua/localization/localization_french.lua"
        or "lua/localization/localization_english.lua"

    local ok = pcall(dofile, mod_path .. file_name)

    if not ok and language ~= "english" then
        pcall(dofile, mod_path .. "lua/localization/localization_english.lua")
    end
end

load_language_file(resolve_language())

local BLTModClass = rawget(_G, "BLTMod")
if Hooks and BLTModClass and type(BLTModClass.GetDescription) == "function" then
    Hooks:PostHook(BLTModClass, "GetDescription", "HVT_LocalizedModDescription", function(mod)
        if not mod or mod.desc ~= "hvt_mod_description" then
            return
        end

        local localization = managers and managers.localization
        if localization and type(localization.text) == "function" then
            return localization:text("hvt_mod_description")
        end
    end)
end
