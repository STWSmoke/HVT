if rawget(_G, "HVTBigBankNameOverrideLoaded") then
    return
end

_G.HVTBigBankNameOverrideLoaded = true

if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if Shared and not Shared._loaded then
    Shared:Load()
end

local function append_override(overrides, string_id)
    if type(string_id) == "string" and string_id ~= "" then
        overrides[string_id] = Shared:Text("hvt_big_bank_name_fun")
    end
end

local function collect_big_bank_name_ids()
    local overrides = {}
    local global_tweak_data = rawget(_G, "tweak_data")
    local narrative = global_tweak_data and global_tweak_data.narrative
    local jobs = narrative and narrative.jobs
    local levels = global_tweak_data and global_tweak_data.levels
    local big_bank_job = jobs and jobs.big

    if not big_bank_job then
        return overrides
    end

    append_override(overrides, big_bank_job.name_id)

    local direct_level = levels and levels.big
    append_override(overrides, direct_level and direct_level.name_id)

    local chain = big_bank_job.chain
    if type(chain) == "table" then
        for _, level_id in ipairs(chain) do
            if type(level_id) == "string" then
                local level_data = levels and levels[level_id]
                append_override(overrides, level_data and level_data.name_id)
            elseif type(level_id) == "table" then
                append_override(overrides, level_id.name_id)

                local nested_level_id = level_id.level_id
                if type(nested_level_id) == "string" then
                    local nested_level_data = levels and levels[nested_level_id]
                    append_override(overrides, nested_level_data and nested_level_data.name_id)
                end
            end
        end
    end

    return overrides
end

local function apply_big_bank_name_override(localization)
    localization = localization or (managers and managers.localization)

    if not localization then
        return
    end

    local overrides = collect_big_bank_name_ids()

    if not next(overrides) then
        return
    end

    if Shared and type(Shared.ApplyCustomLocalizationEntries) == "function" then
        Shared:ApplyCustomLocalizationEntries(
            "big_bank_name_override",
            overrides,
            Shared:AreFunMapNamesEnabled(),
            localization
        )
    elseif type(localization.add_localized_strings) == "function" then
        localization:add_localized_strings(overrides)
    end
end

_G.HVTApplyBigBankNameOverride = apply_big_bank_name_override

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_HVTBigBankNameOverride", function()
    if managers and managers.localization then
        apply_big_bank_name_override(managers.localization)
    end
end)

if managers and managers.localization then
    apply_big_bank_name_override(managers.localization)
end
