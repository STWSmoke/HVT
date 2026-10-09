if ModPath and not rawget(_G, "DrawTriggerVisualShared") then
    pcall(dofile, ModPath .. "lua/visual_shared.lua")
end

local Shared = rawget(_G, "DrawTriggerVisualShared")

if rawget(_G, "HVTFPSCapShared") then
    return
end

local FPSCap = {}
_G.HVTFPSCapShared = FPSCap

local function is_in_active_heist()
    local state_filter = BaseNetworkHandler
        and BaseNetworkHandler._gamestate_filter
        and BaseNetworkHandler._gamestate_filter.any_ingame_playing
    local queued_state = game_state_machine
        and game_state_machine.last_queued_state_name
        and game_state_machine:last_queued_state_name()

    if not (state_filter and queued_state and state_filter[queued_state]) then
        return false
    end

    local player_unit = managers and managers.player and managers.player:player_unit()

    if type(alive) == "function" then
        return alive(player_unit)
    end

    return player_unit ~= nil
end

local function get_current_cap()
    local user = managers and managers.user

    if not user or type(user.get_setting) ~= "function" then
        return nil
    end

    local ok, value = pcall(user.get_setting, user, "fps_cap")
    if not ok then
        return nil
    end

    return tonumber(value)
end

local function set_current_cap(value)
    local user = managers and managers.user

    if not user or type(user.set_setting) ~= "function" then
        return false
    end

    return pcall(user.set_setting, user, "fps_cap", value)
end

local function send_feedback(message_id, macros)
    local chat = managers and managers.chat
    local chat_color = tweak_data and tweak_data.system_chat_color

    if chat and chat_color then
        local message = Shared and type(Shared.Text) == "function"
            and Shared:Text(message_id, macros)
            or tostring(message_id)
        chat:_receive_message(1, "SYSTEM", message, chat_color)
    end
end

function FPSCap:ApplyLimit(limit)
    limit = tonumber(limit)

    if not limit then
        return
    end

    local current_cap = get_current_cap()

    if is_in_active_heist() then
        if current_cap == limit then
            if set_current_cap(0) then
                send_feedback("hvt_fps_limit_removed")
            end
        else
            if set_current_cap(limit) then
                send_feedback("hvt_fps_limit_set", { VALUE = tostring(limit) })
            end
        end

        return
    end

    if current_cap ~= 0 then
        if set_current_cap(0) then
            send_feedback("hvt_fps_limit_removed")
        end
    end
end

function FPSCap:SetUnlimited()
    if set_current_cap(0) then
        send_feedback("hvt_fps_limit_set_unlimited")
    end
end

function FPSCap:IsInActiveHeist()
    return is_in_active_heist()
end
