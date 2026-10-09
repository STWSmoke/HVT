if RequiredScript == "lib/managers/menu/stageendscreengui" then
    if rawget(_G, "HVTAutoSkipEndScreenLoaded") then
        return
    end

    _G.HVTAutoSkipEndScreenLoaded = true

    if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
        pcall(dofile, ModPath .. "lua/visual_shared.lua")
    end

    local Shared = rawget(_G, "DrawTriggerVisualShared")

    if Shared and not Shared._loaded and type(Shared.Load) == "function" then
        Shared:Load()
    end

    local function is_auto_skip_end_screen_enabled()
        if not Shared or type(Shared.EnsureSettings) ~= "function" then
            return false
        end

        Shared:EnsureSettings()

        return Shared.settings and Shared.settings.auto_skip_end_screen == true
    end

    local function is_last_stage_victory_screen()
        local job_manager = managers and managers.job

        if not job_manager
            or type(job_manager.current_stage) ~= "function"
            or type(job_manager.current_job_chain_data) ~= "function" then
            return false
        end

        local current_state_name = game_state_machine and game_state_machine.current_state_name and game_state_machine:current_state_name()
        local current_stage = tonumber(job_manager:current_stage()) or 0
        local current_job_chain = job_manager:current_job_chain_data()

        return current_state_name == "victoryscreen"
            and type(current_job_chain) == "table"
            and current_stage == #current_job_chain
    end

    local function expect_yes(self, params)
        params.yes_func()
    end

    local stage_end_screen_update_actual = StageEndScreenGui.update

    function StageEndScreenGui:update(...)
        local result = stage_end_screen_update_actual(self, ...)

        if not is_auto_skip_end_screen_enabled() then
            return result
        end

        if game_state_machine:current_state_name() ~= "victoryscreen"
            or managers.job:current_stage() ~= #managers.job:current_job_chain_data() then
            return result
        end

        MenuManager.show_abort_mission_dialog = expect_yes
        MenuCallbackHandler:abort_mission()

        return result
    end

    return
end
