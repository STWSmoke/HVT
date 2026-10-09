-- election_day_abort_lock.lua
-- This file only patches the abort dialog to prevent cancelling Election Day on day 1.

if RequiredScript ~= "lib/managers/menumanager" then
    return
end

if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if rawget(_G, "HVTElectionDayAbortLockMenuLoaded") then
    return
end

_G.HVTElectionDayAbortLockMenuLoaded = true

local function should_block_election_day_abort()
    local job_manager = managers and managers.job
    if not job_manager
        or type(job_manager.current_job_id) ~= "function"
        or type(job_manager.current_stage) ~= "function"
        or type(job_manager.stage_success) ~= "function" then
        return false
    end

    return job_manager:current_job_id() == "election_day"
        and (tonumber(job_manager:current_stage()) or 0) == 1
        and job_manager:stage_success()
        and rawget(_G, "HVTElectionDayStageEndScreenActive") == true
end

local function send_to_lobby_as_player(message)
    local session = managers and managers.network and managers.network:session()
    local local_peer = session and session.local_peer and session:local_peer()
    local chat = managers and managers.chat

    if chat and local_peer and type(chat.send_message) == "function" then
        chat:send_message(ChatManager.GAME, local_peer, message)
    end
end

local show_abort_mission_dialog_actual = MenuManager.show_abort_mission_dialog

function MenuManager:show_abort_mission_dialog(params)
    if type(params) == "table" then
        local yes_func = params.yes_func

        if type(yes_func) == "function" then
            params.yes_func = function(...)
                if should_block_election_day_abort() then
                    send_to_lobby_as_player(Shared and Shared:Text("hvt_election_day_abort_blocked") or "")
                    return
                end

                return yes_func(...)
            end
        end
    end

    return show_abort_mission_dialog_actual(self, params)
end
