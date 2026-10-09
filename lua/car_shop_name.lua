if rawget(_G, "HVTCarShopNameOverrideLoaded") then
    return
end

_G.HVTCarShopNameOverrideLoaded = true

if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if Shared and not Shared._loaded then
    Shared:Load()
end

local function append_override(overrides, string_id)
    if type(string_id) == "string" and string_id ~= "" then
        overrides[string_id] = Shared:Text("hvt_car_shop_name_fun")
    end
end

local function collect_car_shop_name_ids()
    local overrides = {}
    local global_tweak_data = rawget(_G, "tweak_data")
    local narrative = global_tweak_data and global_tweak_data.narrative
    local jobs = narrative and narrative.jobs
    local levels = global_tweak_data and global_tweak_data.levels
    local car_shop_job = jobs and jobs.cage

    if not car_shop_job then
        return overrides
    end

    append_override(overrides, car_shop_job.name_id)

    local direct_level = levels and levels.cage
    append_override(overrides, direct_level and direct_level.name_id)

    local chain = car_shop_job.chain
    if type(chain) == "table" then
        for _, level_id in ipairs(chain) do
            if type(level_id) == "string" then
                local level_data = levels and levels[level_id]
                append_override(overrides, level_data and level_data.name_id)
            end
        end
    end

    return overrides
end

local function apply_car_shop_name_override(localization)
    localization = localization or (managers and managers.localization)

    if not localization then
        return
    end

    local overrides = collect_car_shop_name_ids()

    if not next(overrides) then
        return
    end

    if Shared and type(Shared.ApplyCustomLocalizationEntries) == "function" then
        Shared:ApplyCustomLocalizationEntries(
            "car_shop_name_override",
            overrides,
            Shared:AreFunMapNamesEnabled(),
            localization
        )
    elseif type(localization.add_localized_strings) == "function" then
        localization:add_localized_strings(overrides)
    end
end

_G.HVTApplyCarShopNameOverride = apply_car_shop_name_override

Hooks:Add("MenuManagerInitialize", "MenuManagerInitialize_HVTCarShopNameOverride", function()
    if managers and managers.localization then
        apply_car_shop_name_override(managers.localization)
    end
end)

if managers and managers.localization then
    apply_car_shop_name_override(managers.localization)
end
