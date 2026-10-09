if rawget(_G, "HVTContractBrokerAutoBuyLoaded") then
    return
end

_G.HVTContractBrokerAutoBuyLoaded = true

if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/core/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if not Shared then
    return
end

if not Shared._loaded and type(Shared.Load) == "function" then
    Shared:Load()
end

local DIFFICULTY = "sm_wish"
local ONE_DOWN = false

local function is_auto_buy_enabled()
    Shared:EnsureSettings()

    return Shared.settings and Shared.settings.auto_buy_death_sentence == true
end

local trigger_actual = ContractBrokerHeistItem.trigger

function ContractBrokerHeistItem:trigger(...)
    local job_data = self and self._job_data

    if is_auto_buy_enabled() and job_data and job_data.enabled
        and Shared:BuyAndStartPremiumContract(job_data.job_id, DIFFICULTY, ONE_DOWN, "hvt_auto_buy_ds_not_enough_offshore") then
        return
    end

    return trigger_actual(self, ...)
end
