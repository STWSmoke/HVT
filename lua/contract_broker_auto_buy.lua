if rawget(_G, "HVTContractBrokerAutoBuyLoaded") then
    return
end

_G.HVTContractBrokerAutoBuyLoaded = true

if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if not Shared then
    return
end

if not Shared._loaded and type(Shared.Load) == "function" then
    Shared:Load()
end

local AUTO_BUY_DIFFICULTY = "sm_wish"
local AUTO_BUY_ONE_DOWN = false

local function is_auto_buy_enabled()
    if type(Shared.EnsureSettings) == "function" then
        Shared:EnsureSettings()
    end

    return Shared.settings and Shared.settings.auto_buy_death_sentence == true
end

local function get_auto_buy_difficulty_id()
    if tweak_data and type(tweak_data.difficulty_to_index) == "function" then
        return tweak_data:difficulty_to_index(AUTO_BUY_DIFFICULTY)
    end

    return nil
end

local function show_not_enough_offshore_dialog(job_id, difficulty_id)
    local money = managers and managers.money
    local experience = managers and managers.experience
    local localization = managers and managers.localization
    local system_menu = managers and managers.system_menu

    if not money or not experience or not localization or not system_menu then
        return
    end

    local contract_fee = experience:cash_string(money:get_cost_of_premium_contract(job_id, difficulty_id))
    local offshore = experience:cash_string(money:offshore())

    system_menu:show({
        title = localization:text("dialog_error_title"),
        text = localization:text("hvt_auto_buy_ds_not_enough_offshore", {
            COST = contract_fee,
            OFFSHORE = offshore
        }),
        button_list = {
            {
                text = localization:text("dialog_ok")
            }
        }
    })
end

local function is_supported_auto_buy_job(job_tweak)
    return job_tweak
        and job_tweak.contact ~= "skirmish"
        and not job_tweak.competitive
end

local function auto_buy_job(job_id, job_tweak)
    local difficulty_id = get_auto_buy_difficulty_id()
    local money = managers and managers.money
    local job_manager = managers and managers.job

    if not difficulty_id or not money or not job_manager then
        return false
    end

    if not money:can_afford_buy_premium_contract(job_id, difficulty_id) then
        show_not_enough_offshore_dialog(job_id, difficulty_id)

        return true
    end

    local broker_gui_getter = managers and managers.menu_component and managers.menu_component.contract_broker_gui
    local broker_gui = type(broker_gui_getter) == "function" and managers.menu_component:contract_broker_gui() or nil

    if broker_gui and type(broker_gui.save_temporary_data) == "function" then
        broker_gui:save_temporary_data(job_id)
    end

    money:on_buy_premium_contract(job_id, difficulty_id)
    job_manager:on_buy_job(job_id, difficulty_id)

    local start_job_data = {
        job_id = job_id,
        difficulty = AUTO_BUY_DIFFICULTY,
        one_down = AUTO_BUY_ONE_DOWN,
        professional = job_tweak.professional or false,
        competitive = job_tweak.competitive or false
    }

    managers.menu:post_event("menu_enter")

    if Global.game_settings and Global.game_settings.single_player then
        MenuCallbackHandler:start_single_player_job(start_job_data)
    else
        MenuCallbackHandler:start_job(start_job_data)
    end

    return true
end

local trigger_actual = ContractBrokerHeistItem.trigger

function ContractBrokerHeistItem:trigger(...)
    local job_data = self and self._job_data
    local job_id = job_data and job_data.job_id
    local job_tweak = job_id and tweak_data and tweak_data.narrative and tweak_data.narrative:job_data(job_id)

    if is_auto_buy_enabled()
        and job_data
        and job_data.enabled
        and is_supported_auto_buy_job(job_tweak) then
        local handled = auto_buy_job(job_id, job_tweak)

        if handled then
            return
        end
    end

    return trigger_actual(self, ...)
end
