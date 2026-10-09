local Shared = rawget(_G, "DrawTriggerVisualShared")

function Shared:IsSupportedContractBrokerJob(job_tweak)
    return job_tweak
        and job_tweak.contact ~= "skirmish"
        and not job_tweak.competitive
end

function Shared:GetPremiumContractDifficultyId(difficulty)
    if tweak_data and type(tweak_data.difficulty_to_index) == "function" then
        return tweak_data:difficulty_to_index(difficulty)
    end

    return nil
end

function Shared:ShowPremiumContractNotEnoughOffshore(job_id, difficulty_id, text_id)
    local money = managers and managers.money
    local experience = managers and managers.experience
    local localization = managers and managers.localization
    local system_menu = managers and managers.system_menu

    if not money or not experience or not localization or not system_menu then
        return
    end

    system_menu:show({
        title = localization:text("dialog_error_title"),
        text = localization:text(text_id or "hvt_auto_buy_ds_not_enough_offshore", {
            COST = experience:cash_string(money:get_cost_of_premium_contract(job_id, difficulty_id)),
            OFFSHORE = experience:cash_string(money:offshore())
        }),
        button_list = {
            {
                text = localization:text("dialog_ok")
            }
        }
    })
end

function Shared:BuyPremiumContract(job_id, difficulty, one_down, not_enough_text_id, start_job)
    local narrative = tweak_data and tweak_data.narrative
    local job_tweak = narrative and type(narrative.job_data) == "function" and narrative:job_data(job_id)
        or narrative and narrative.jobs and narrative.jobs[job_id]
    local difficulty_id = self:GetPremiumContractDifficultyId(difficulty)
    local money = managers and managers.money
    local job_manager = managers and managers.job

    if not self:IsSupportedContractBrokerJob(job_tweak) or not difficulty_id or not money or not job_manager then
        return false
    end

    if not money:can_afford_buy_premium_contract(job_id, difficulty_id) then
        self:ShowPremiumContractNotEnoughOffshore(job_id, difficulty_id, not_enough_text_id)
        return true
    end

    local broker_gui_getter = managers and managers.menu_component and managers.menu_component.contract_broker_gui
    local broker_gui = type(broker_gui_getter) == "function" and managers.menu_component:contract_broker_gui() or nil

    if broker_gui and type(broker_gui.save_temporary_data) == "function" then
        broker_gui:save_temporary_data(job_id)
    end

    money:on_buy_premium_contract(job_id, difficulty_id)
    job_manager:on_buy_job(job_id, difficulty_id)

    if start_job == false then
        return true
    end

    local start_job_data = {
        job_id = job_id,
        difficulty = difficulty,
        one_down = one_down == true,
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

function Shared:BuyAndStartPremiumContract(job_id, difficulty, one_down, not_enough_text_id)
    return self:BuyPremiumContract(job_id, difficulty, one_down, not_enough_text_id, true)
end

