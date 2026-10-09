local REQUIRED_SCRIPT = RequiredScript
local COUNTER_KEY = "HVTElectionDayVoteMachineCounter"
local MACHINE_INTERACTION_ID = "votingmachine2"

local counter = rawget(_G, COUNTER_KEY)

if not counter then
    counter = {
        active_peers = {},
        completed_count = 0,
        objective_count = 0,
        objective_baseline_count = nil,
        successful_end_count = 0,
        vote_objective_id = nil,
        last_announced_count = nil,
        enabled = false
    }

    rawset(_G, COUNTER_KEY, counter)
end

counter.active_peers = counter.active_peers or {}
counter.completed_count = tonumber(counter.completed_count) or 0
counter.objective_count = tonumber(counter.objective_count) or 0
counter.successful_end_count = tonumber(counter.successful_end_count) or 0

local function is_swing_vote_day()
    local job_manager = managers and managers.job

    if not job_manager
        or type(job_manager.current_job_id) ~= "function"
        or type(job_manager.current_stage) ~= "function" then
        return false
    end

    return job_manager:current_job_id() == "election_day"
        and (tonumber(job_manager:current_stage()) or 0) == 2
end

local function is_vote_machine_objective(objective_data)
    local amount = type(objective_data) == "table" and tonumber(objective_data.amount)

    -- Swing Vote requires hacking 4, 5, or 6 machines, depending on difficulty.
    -- Other Election Day objectives can also mention machines, but use different amounts.
    if not amount or amount < 4 or amount > 6 then
        return false
    end

    local description = (tostring(objective_data.id or "") .. " " .. tostring(objective_data.text or "")):lower()

    if not description:find("machine", 1, true)
        and not description:find("vote", 1, true)
        and not description:find("ballot", 1, true) then
        local objectives = managers and managers.hud and managers.hud._hud_objectives
        local hud_panel = objectives and objectives._hud_panel
        local panel = hud_panel and hud_panel:child("objectives_panel")
        local objective_text = panel and panel:child("objective_text")

        if objective_text and type(objective_text.text) == "function" then
            description = description .. " " .. tostring(objective_text:text() or ""):lower()
        end
    end

    local mentions_machines = description:find("machine", 1, true)
        or description:find("vote", 1, true)
        or description:find("ballot", 1, true)

    return mentions_machines
end

local function get_objective_completed_count(objective_data)
    local objectives = managers and managers.hud and managers.hud._hud_objectives

    if is_vote_machine_objective(objective_data) then
        counter.vote_objective_id = objective_data.id
    end

    if type(objective_data) == "table"
        and objective_data.id ~= nil
        and objective_data.id == counter.vote_objective_id
        and objectives
        and objectives._active_objective_id == objective_data.id then
        local current_amount = tonumber(objective_data.current_amount)

        if current_amount then
            return current_amount
        end
    end

    if not counter.vote_objective_id or not objectives or objectives._active_objective_id ~= counter.vote_objective_id then
        return nil
    end

    local hud_panel = objectives and objectives._hud_panel
    local panel = hud_panel and hud_panel:child("objectives_panel")
    local amount_text = panel and panel:child("amount_text")

    if not amount_text or type(amount_text.text) ~= "function" then
        return nil
    end

    local current = tostring(amount_text:text() or ""):match("^%s*(%d+)%s*/")

    return tonumber(current)
end

local function recompute_completed_count()
    local count_from_interactions = (counter.objective_baseline_count or 0) + counter.successful_end_count

    counter.completed_count = math.max(counter.objective_count, count_from_interactions)
end

local function update_objective_count(completed_count, establish_baseline)
    completed_count = tonumber(completed_count)

    if not completed_count then
        return false
    end

    counter.objective_count = math.max(counter.objective_count, completed_count)

    if establish_baseline then
        local baseline_count = math.max(0, completed_count - counter.successful_end_count)

        counter.objective_baseline_count = math.max(counter.objective_baseline_count or 0, baseline_count)
    end

    recompute_completed_count()

    return true
end

local function refresh_counter(allow_baseline_update)
    if not is_swing_vote_day() then
        counter.enabled = false
        counter.active_peers = {}
        counter.completed_count = 0
        counter.objective_count = 0
        counter.objective_baseline_count = nil
        counter.successful_end_count = 0
        counter.vote_objective_id = nil
        counter.last_announced_count = nil

        return false
    end

    if not counter.enabled then
        counter.enabled = true
        counter.active_peers = {}
        counter.completed_count = 0
        counter.objective_count = 0
        counter.objective_baseline_count = nil
        counter.successful_end_count = 0
        counter.vote_objective_id = nil
        counter.last_announced_count = nil
    end

    local completed_count = get_objective_completed_count()

    if completed_count then
        local can_update_baseline = allow_baseline_update ~= false and counter.successful_end_count == 0

        update_objective_count(completed_count, can_update_baseline)
    end

    return true
end

local function is_vote_machine_interaction(interaction_id)
    return tostring(interaction_id or ""):lower() == MACHINE_INTERACTION_ID
end

local function show_count()
    local chat = managers and managers.chat
    local chat_color = tweak_data and tweak_data.system_chat_color

    if not chat or not chat_color or type(chat._receive_message) ~= "function" then
        return
    end

    local count = counter.completed_count

    if count == counter.last_announced_count then
        return
    end

    local localization = managers and managers.localization
    local message = "Ballot machines hacked: " .. tostring(count)

    if localization and type(localization.text) == "function" then
        local ok, localized_message = pcall(localization.text, localization, "hvt_election_day_vote_machine_count", {
            COUNT = count
        })

        if ok and type(localized_message) == "string" then
            message = localized_message
        end
    end

    chat:_receive_message(1, "SYSTEM", message, chat_color)
    counter.last_announced_count = count
end

local function get_local_peer_id()
    local session = managers and managers.network and managers.network:session()
    local local_peer = session and session:local_peer()

    return local_peer and local_peer:id() or "local"
end

local function set_peer_progress(peer_id, enabled, success)
    if not refresh_counter(enabled == true) then
        return
    end

    peer_id = peer_id or "unknown"

    if enabled then
        if not counter.active_peers[peer_id] then
            counter.active_peers[peer_id] = true
        end

        return
    end

    if counter.active_peers[peer_id] then
        counter.active_peers[peer_id] = nil
    end

    if success then
        counter.successful_end_count = counter.successful_end_count + 1

        local completed_count = get_objective_completed_count()

        if completed_count then
            update_objective_count(completed_count, counter.objective_baseline_count == nil)
        end

        recompute_completed_count()
        show_count()
    end
end

if REQUIRED_SCRIPT == "lib/units/beings/player/states/playerstandard" then
    if not rawget(_G, "HVTElectionDayVoteCounterPlayerHookLoaded") and Hooks and PlayerStandard then
        _G.HVTElectionDayVoteCounterPlayerHookLoaded = true

        Hooks:PostHook(PlayerStandard, "_start_action_interact", "HVT_ElectionDayVoteCounter_LocalStart", function(player_standard)
            if not refresh_counter() then
                return
            end

            local interaction_params = player_standard and player_standard._interact_params
            local interaction_id = interaction_params and interaction_params.tweak_data

            if is_vote_machine_interaction(interaction_id) then
                set_peer_progress(get_local_peer_id(), true, false)
            end
        end)

        Hooks:PostHook(PlayerStandard, "_interupt_action_interact", "HVT_ElectionDayVoteCounter_LocalStop", function(player_standard, t, input, success)
            if not is_swing_vote_day() or not counter.active_peers[get_local_peer_id()] then
                return
            end

            set_peer_progress(get_local_peer_id(), false, success == true)
        end)
    end
elseif REQUIRED_SCRIPT == "lib/network/handlers/unitnetworkhandler" then
    if not rawget(_G, "HVTElectionDayVoteCounterNetworkHookLoaded") and Hooks and UnitNetworkHandler then
        _G.HVTElectionDayVoteCounterNetworkHookLoaded = true

        Hooks:PostHook(UnitNetworkHandler, "sync_teammate_progress", "HVT_ElectionDayVoteCounter_RemoteProgress", function(network_handler, type_index, enabled, interaction_id, timer, success, sender)
            if tonumber(type_index) ~= 1 or not is_vote_machine_interaction(interaction_id) then
                return
            end

            local verify_sender = network_handler and network_handler._verify_sender
            local sender_peer = type(verify_sender) == "function" and verify_sender(sender) or nil
            local peer_id = sender_peer and sender_peer:id()

            if peer_id then
                set_peer_progress(peer_id, enabled == true, success == true)
            end
        end)
    end
elseif REQUIRED_SCRIPT == "lib/managers/hudmanagerpd2" then
    if not rawget(_G, "HVTElectionDayVoteCounterObjectiveHookLoaded") and Hooks and HUDManager then
        _G.HVTElectionDayVoteCounterObjectiveHookLoaded = true

        Hooks:PostHook(HUDManager, "activate_objective", "HVT_ElectionDayVoteCounter_ObjectiveStart", function(hud_manager, objective_data)
            if refresh_counter(false) then
                local completed_count = get_objective_completed_count(objective_data)

                if completed_count then
                    update_objective_count(completed_count, true)
                end

                if is_vote_machine_objective(objective_data) and completed_count and completed_count > 0 then
                    show_count()
                end
            end
        end)

        Hooks:PostHook(HUDManager, "update_amount_objective", "HVT_ElectionDayVoteCounter_ObjectiveUpdate", function(hud_manager, objective_data)
            local previous_count = counter.completed_count

            if refresh_counter(false) then
                local completed_count = get_objective_completed_count(objective_data)

                if completed_count then
                    update_objective_count(completed_count, false)
                end

                if counter.completed_count > previous_count then
                    show_count()
                end
            end
        end)
    end
end
