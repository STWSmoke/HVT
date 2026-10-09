if rawget(_G, "HVTLocalizationLoaderLoaded") then
    return
end

_G.HVTLocalizationLoaderLoaded = true

if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if Shared and type(Shared.Load) == "function" then
    pcall(function()
        Shared:Load()
    end)
end

local function detect_language()
    local system_info = rawget(_G, "SystemInfo")
    local language = nil

    if system_info and type(system_info.language) == "function" then
        local ok, value = pcall(system_info.language, system_info)

        if ok then
            language = value
        end
    end

    local normalized = tostring(language or ""):lower()

    if type(language) == "table" or type(language) == "userdata" then
        if type(language.key) == "function" and type(Idstring) == "function" then
            local ok_language, language_key = pcall(language.key, language)
            local ok_french, french_key = pcall(function()
                return Idstring("french"):key()
            end)

            if ok_language and ok_french and language_key == french_key then
                return "french"
            end
        end

        normalized = tostring(language):lower()
    end

    if normalized == "fr"
        or normalized:find("fr_", 1, true)
        or normalized:find("fr-", 1, true)
        or normalized:find("french", 1, true)
    then
        return "french"
    end

    return "english"
end

local function resolve_language()
    local choice = Shared and type(Shared.GetLocalizationLanguageChoice) == "function"
        and Shared:GetLocalizationLanguageChoice()
        or nil

    if choice == 2 then
        return "english"
    end

    if choice == 3 then
        return "french"
    end

    return detect_language()
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
