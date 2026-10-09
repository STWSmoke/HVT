if rawget(_G, "HVTMapNameOverridesLoaded") then
    return
end

_G.HVTMapNameOverridesLoaded = true

if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/core/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if Shared and not Shared._loaded then
    Shared:Load()
end

-- Add one entry here for each job whose displayed name should be replaced.
local MAP_NAME_OVERRIDES = {
    {
        job_id = "big",
        localization_id = "hvt_big_bank_name_fun",
        owner_id = "big_bank_name_override"
    },
    {
        job_id = "chca",
        localization_id = "hvt_black_cat_name_fun",
        owner_id = "black_cat_name_override"
    },
    {
        job_id = "tag",
        localization_id = "hvt_breakin_feds_name_fun",
        owner_id = "breakin_feds_name_override"
    },
    {
        job_id = "auc",
        localization_id = "hvt_under_hammer_name_fun",
        owner_id = "under_hammer_name_override"
    },
    {
        job_id = "fish",
        localization_id = "hvt_yacht_name_fun",
        owner_id = "yacht_name_override"
    },
    {
        job_id = "cage",
        localization_id = "hvt_car_shop_name_fun",
        owner_id = "car_shop_name_override"
    }
}

local function get_rename_text(override, localization)
    if Shared and type(Shared.Text) == "function" then
        return Shared:Text(override.localization_id)
    end

    if localization and type(localization.text) == "function" then
        return localization:text(override.localization_id)
    end

    return override.localization_id
end

local function append_override(overrides, string_id, text)
    if type(string_id) == "string" and string_id ~= "" then
        overrides[string_id] = text
    end
end

local function append_level_override(overrides, level_entry, levels, text)
    if type(level_entry) == "string" then
        local level_data = levels and levels[level_entry]
        append_override(overrides, level_data and level_data.name_id, text)
    elseif type(level_entry) == "table" then
        append_override(overrides, level_entry.name_id, text)

        local nested_level_id = level_entry.level_id
        if type(nested_level_id) == "string" then
            local level_data = levels and levels[nested_level_id]
            append_override(overrides, level_data and level_data.name_id, text)
        end
    end
end

local function collect_override_entries(override, localization)
    local entries = {}
    local global_tweak_data = rawget(_G, "tweak_data")
    local narrative = global_tweak_data and global_tweak_data.narrative
    local jobs = narrative and narrative.jobs
    local levels = global_tweak_data and global_tweak_data.levels
    local job = jobs and jobs[override.job_id]

    if not job then
        return entries
    end

    local text = get_rename_text(override, localization)
    append_override(entries, job.name_id, text)

    local direct_level = levels and levels[override.job_id]
    append_override(entries, direct_level and direct_level.name_id, text)

    if type(job.chain) == "table" then
        for _, level_entry in ipairs(job.chain) do
            append_level_override(entries, level_entry, levels, text)
        end
    end

    return entries
end

local function apply_map_name_overrides(localization)
    localization = localization or (managers and managers.localization)

    if not localization then
        return
    end

    for _, override in ipairs(MAP_NAME_OVERRIDES) do
        local entries = collect_override_entries(override, localization)

        if next(entries) then
            if Shared and type(Shared.ApplyCustomLocalizationEntries) == "function" then
                Shared:ApplyCustomLocalizationEntries(
                    override.owner_id,
                    entries,
                    Shared:AreFunMapNamesEnabled(),
                    localization
                )
            elseif type(localization.add_localized_strings) == "function" then
                localization:add_localized_strings(entries)
            end
        end
    end
end

_G.HVTApplyMapNameOverrides = apply_map_name_overrides

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_HVTMapNameOverrides", function()
    if managers and managers.localization then
        apply_map_name_overrides(managers.localization)
    end
end)

if managers and managers.localization then
    apply_map_name_overrides(managers.localization)
end
